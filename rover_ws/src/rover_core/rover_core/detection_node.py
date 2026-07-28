import rclpy
from rclpy.node import Node
from sensor_msgs.msg import Image, CompressedImage
from std_msgs.msg import String
import cv2
import threading
import time
import json

# Intentamos importar ultralytics, si no está instalado daremos un mensaje de error descriptivo
try:
    from ultralytics import YOLO
    ULTRALYTICS_AVAILABLE = True
except ImportError:
    ULTRALYTICS_AVAILABLE = False

class RTSPVideoCapture:
    """Clase auxiliar para leer el stream RTSP en un hilo separado y evitar retrasos (lag) de buffer."""
    def __init__(self, src, logger):
        self.src = src
        self.logger = logger
        self.cap = cv2.VideoCapture(src)
        self.ret = False
        self.frame = None
        self.running = True
        self.thread = threading.Thread(target=self._update)
        self.thread.daemon = True
        self.thread.start()
        self.logger.info(f"Hilo de captura RTSP iniciado para: {src}")

    def _update(self):
        while self.running:
            if self.cap.isOpened():
                ret, frame = self.cap.read()
                if ret:
                    self.ret = ret
                    self.frame = frame
                else:
                    self.logger.warn("No se pudo leer el frame del stream RTSP, reintentando...")
                    time.sleep(0.1)
            else:
                self.logger.error("Conexión RTSP cerrada. Intentando reconectar...")
                self.cap.release()
                time.sleep(2.0)
                self.cap = cv2.VideoCapture(self.src)

    def read(self):
        return self.ret, self.frame

    def release(self):
        self.running = False
        if self.cap.isOpened():
            self.cap.release()

class DetectionNode(Node):
    def __init__(self):
        super().__init__('detection_node')
        
        # --- PARÁMETROS CONFIGURABLES ---
        self.declare_parameter('rtsp_url', 'rtsp://admin:123456@192.168.1.3:554/11')
        self.declare_parameter('enable_yolo', False)
        self.declare_parameter('model_name', 'yolov8n.pt')
        self.declare_parameter('conf_threshold', 0.25)
        # Relación ancho/alto para considerar que una persona está recostada (típicamente > 1.2)
        self.declare_parameter('lying_down_ratio', 1.2)
        # Frecuencia de procesamiento de frames (FPS a procesar para no sobrecargar el CPU)
        self.declare_parameter('processing_fps', 10.0)
        # Tamaño de imagen para la inferencia YOLO (320 es ideal para CPU de laptop)
        self.declare_parameter('imgsz', 320)
        # Dispositivo de ejecución (cpu, cuda, etc.)
        self.declare_parameter('device', 'cpu')

        self.enable_yolo = self.get_parameter('enable_yolo').get_parameter_value().bool_value

        self.model = None
        if self.enable_yolo:
            # Verificar si ultralytics está instalado
            if not ULTRALYTICS_AVAILABLE:
                self.get_logger().error(
                    "\n\n======================================================\n"
                    "ERROR: La librería 'ultralytics' no está instalada.\n"
                    "Por favor, instálala en la laptop del robot con:\n"
                    "    pip3 install ultralytics\n"
                    "======================================================\n"
                )
                # Salimos para evitar fallos de ejecución
                self.destroy_node()
                rclpy.shutdown()
                return

            # Cargar el modelo YOLOv8
            model_file = self.get_parameter('model_name').get_parameter_value().string_value
            self.get_logger().info(f"Cargando modelo YOLO: {model_file}...")
            try:
                self.model = YOLO(model_file)
                self.get_logger().info("Modelo YOLO cargado exitosamente.")
            except Exception as e:
                self.get_logger().error(f"Fallo al cargar el modelo YOLO: {str(e)}")
                return
        else:
            self.get_logger().info("Detección YOLO desactivada. Transmitiendo video directo de baja latencia.")

        # Publicadores
        self.image_pub = self.create_publisher(Image, '/camera/image_processed', 10)
        self.image_compressed_pub = self.create_publisher(CompressedImage, '/camera/image_processed/compressed', 10)
        self.detection_pub = self.create_publisher(String, '/camera/detections', 10)

        # Mapeo de Clases COCO traducidas
        self.class_mapping = {
            0: 'Persona',
            2: 'Automovil', 3: 'Motocicleta', 5: 'Autobus', 7: 'Camion', # Vehículos
            14: 'Ave', 15: 'Gato', 16: 'Perro', 17: 'Caballo', 18: 'Oveja', 19: 'Vaca' # Animales
        }

        # Inicializar captura de video RTSP
        rtsp_url = self.get_parameter('rtsp_url').get_parameter_value().string_value
        self.camera = RTSPVideoCapture(rtsp_url, self.get_logger())

        # Timer de procesamiento
        fps = self.get_parameter('processing_fps').get_parameter_value().double_value
        timer_period = 1.0 / fps
        self.timer = self.create_timer(timer_period, self.process_frame)
        self.get_logger().info(f"Nodo de streaming/detección iniciado. Procesando a {fps} FPS.")

    def process_frame(self):
        ret, frame = self.camera.read()
        if not ret or frame is None:
            return

        # Contadores para las métricas de detección
        stats = {
            "vehicles": 0,
            "people_standing": 0,
            "people_lying": 0,
            "animals": 0
        }

        if self.enable_yolo and self.model is not None:
            # Parámetros dinámicos
            conf_thresh = self.get_parameter('conf_threshold').get_parameter_value().double_value
            lying_ratio = self.get_parameter('lying_down_ratio').get_parameter_value().double_value
            img_sz = self.get_parameter('imgsz').get_parameter_value().integer_value
            dev = self.get_parameter('device').get_parameter_value().string_value

            # Realizar la inferencia con YOLO
            results = self.model(frame, device=dev, imgsz=img_sz, verbose=False)[0]

            # Dibujar cuadritos y etiquetas en base a las detecciones
            for box in results.boxes:
                conf = float(box.conf[0])
                if conf < conf_thresh:
                    continue

                cls_id = int(box.cls[0])
                # Solo procesamos si está dentro de nuestras clases de interés
                if cls_id not in self.class_mapping:
                    continue

                # Obtener coordenadas de la caja de detección
                x1, y1, x2, y2 = map(int, box.xyxy[0])
                w = x2 - x1
                h = y2 - y1

                label = self.class_mapping[cls_id]
                color = (0, 255, 0) # Verde por defecto (Vehículos y animales)

                if cls_id == 0: # Persona
                    # Comprobamos si está recostada analizando la relación de aspecto de la caja
                    ratio = float(w) / float(h) if h > 0 else 0.0
                    if ratio > lying_ratio:
                        label = "Persona (Recostada)"
                        color = (0, 0, 255) # Rojo para advertencia de persona recostada
                        stats["people_lying"] += 1
                    else:
                        label = "Persona (De pie/Sentada)"
                        color = (0, 255, 0) # Verde
                        stats["people_standing"] += 1
                elif cls_id in [2, 3, 5, 7]: # Vehículos
                    stats["vehicles"] += 1
                    color = (255, 255, 0) # Celeste/Cyan para vehículos
                elif cls_id in [14, 15, 16, 17, 18, 19]: # Animales
                    stats["animals"] += 1
                    color = (255, 0, 255) # Magenta para animales

                # Dibujar el rectángulo ("cuadrito")
                cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
                
                # Poner texto informativo
                caption = f"{label} {conf:.2f}"
                cv2.putText(frame, caption, (x1, max(y1 - 10, 15)),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)

        # Publicar los datos estructurados en formato JSON (muy útil para el frontend de la MacBook)
        json_msg = String()
        json_msg.data = json.dumps(stats)
        self.detection_pub.publish(json_msg)

        # Publicar la imagen procesada
        self.publish_image(frame)

    def publish_image(self, frame):
        """Serializa la imagen de OpenCV a sensor_msgs/Image y sensor_msgs/CompressedImage."""
        msg = Image()
        msg.header.stamp = self.get_clock().now().to_msg()
        msg.header.frame_id = "camera_link"
        msg.height = frame.shape[0]
        msg.width = frame.shape[1]
        msg.encoding = "bgr8"
        msg.is_bigendian = 0
        msg.step = frame.shape[1] * 3
        msg.data = frame.tobytes()
        self.image_pub.publish(msg)

        # Publicar imagen comprimida (JPEG) para consumo web eficiente
        ret, jpeg_buf = cv2.imencode('.jpg', frame, [int(cv2.IMWRITE_JPEG_QUALITY), 75])
        if ret:
            comp_msg = CompressedImage()
            comp_msg.header.stamp = msg.header.stamp
            comp_msg.header.frame_id = "camera_link"
            comp_msg.format = "jpeg"
            comp_msg.data = jpeg_buf.tobytes()
            self.image_compressed_pub.publish(comp_msg)

    def destroy_node(self):
        if hasattr(self, 'camera') and self.camera is not None:
            self.camera.release()
        super().destroy_node()

def main(args=None):
    rclpy.init(args=args)
    node = DetectionNode()
    try:
        if rclpy.ok() and hasattr(node, 'timer'): # Comprobar que no haya sido destruido en init
            rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        if hasattr(node, 'destroy_node'):
            node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()

if __name__ == '__main__':
    main()
