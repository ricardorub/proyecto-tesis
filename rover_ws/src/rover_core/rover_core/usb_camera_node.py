import rclpy
from rclpy.node import Node
from sensor_msgs.msg import Image, CompressedImage
import cv2
import threading
import time

class USBCameraVideoCapture:
    """Clase auxiliar para leer el flujo de la cámara USB en un hilo separado evitando latencia de buffer."""
    def __init__(self, device_id, width, height, logger):
        self.device_id = device_id
        self.width = width
        self.height = height
        self.logger = logger
        self.cap = cv2.VideoCapture(device_id)
        
        if self.cap.isOpened():
            self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, width)
            self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
            self.logger.info(f"Cámara USB en /dev/video{device_id} abierta correctamente a {width}x{height}.")
        else:
            self.logger.error(f"Fallo al abrir la cámara USB en /dev/video{device_id}.")

        self.ret = False
        self.frame = None
        self.running = True
        self.thread = threading.Thread(target=self._update)
        self.thread.daemon = True
        self.thread.start()

    def _update(self):
        while self.running:
            if self.cap.isOpened():
                ret, frame = self.cap.read()
                if ret and frame is not None:
                    self.ret = ret
                    self.frame = frame
                else:
                    self.logger.warn("Frame vacío recibido de la cámara USB, reintentando...")
                    time.sleep(0.05)
            else:
                self.logger.error("Cámara USB no abierta. Reintentando en 2 segundos...")
                time.sleep(2.0)
                self.cap = cv2.VideoCapture(self.device_id)
                if self.cap.isOpened():
                    self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, self.width)
                    self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, self.height)

    def read(self):
        return self.ret, self.frame

    def release(self):
        self.running = False
        if self.cap.isOpened():
            self.cap.release()

class USBCameraNode(Node):
    def __init__(self):
        super().__init__('usb_camera_node')

        # --- PARÁMETROS CONFIGURABLES ---
        self.declare_parameter('device_id', 0)
        self.declare_parameter('frame_width', 640)
        self.declare_parameter('frame_height', 480)
        self.declare_parameter('fps', 15.0)

        device_id = self.get_parameter('device_id').get_parameter_value().integer_value
        width = self.get_parameter('frame_width').get_parameter_value().integer_value
        height = self.get_parameter('frame_height').get_parameter_value().integer_value
        fps = self.get_parameter('fps').get_parameter_value().double_value

        # Publicadores de ROS 2
        self.image_pub = self.create_publisher(Image, '/usb_camera/image_raw', 10)
        self.image_compressed_pub = self.create_publisher(CompressedImage, '/usb_camera/image_raw/compressed', 10)

        # Iniciar captura de video en hilo
        self.camera = USBCameraVideoCapture(device_id, width, height, self.get_logger())

        # Timer de publicación
        timer_period = 1.0 / fps if fps > 0 else 0.066
        self.timer = self.create_timer(timer_period, self.publish_frame)
        self.get_logger().info(f"Nodo USBCameraNode iniciado. Transmitiendo a {fps} FPS.")

    def publish_frame(self):
        ret, frame = self.camera.read()
        if not ret or frame is None:
            return

        now = self.get_clock().now().to_msg()

        # Publicar sensor_msgs/Image
        msg = Image()
        msg.header.stamp = now
        msg.header.frame_id = "usb_camera_link"
        msg.height = frame.shape[0]
        msg.width = frame.shape[1]
        msg.encoding = "bgr8"
        msg.is_bigendian = 0
        msg.step = frame.shape[1] * 3
        msg.data = frame.tobytes()
        self.image_pub.publish(msg)

        # Publicar sensor_msgs/CompressedImage (para transmisión eficiente a la MacBook)
        ret_jpeg, jpeg_buf = cv2.imencode('.jpg', frame, [int(cv2.IMWRITE_JPEG_QUALITY), 75])
        if ret_jpeg:
            comp_msg = CompressedImage()
            comp_msg.header.stamp = now
            comp_msg.header.frame_id = "usb_camera_link"
            comp_msg.format = "jpeg"
            comp_msg.data = jpeg_buf.tobytes()
            self.image_compressed_pub.publish(comp_msg)

    def destroy_node(self):
        if hasattr(self, 'camera') and self.camera is not None:
            self.camera.release()
        super().destroy_node()

def main(args=None):
    rclpy.init(args=args)
    node = USBCameraNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()

if __name__ == '__main__':
    main()
