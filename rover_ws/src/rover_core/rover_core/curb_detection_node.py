import rclpy
from rclpy.node import Node
from sensor_msgs.msg import Image, CompressedImage
from std_msgs.msg import String
import cv2
import numpy as np
import json

class CurbDetectionNode(Node):
    def __init__(self):
        super().__init__('curb_detection_node')

        # --- PARÁMETROS CONFIGURABLES ---
        # Mostrar ventana visual por defecto
        self.declare_parameter('show_window', True)

        # Rangos HSV para la detección de césped/pasto
        self.declare_parameter('hsv_hue_min', 30)
        self.declare_parameter('hsv_hue_max', 85)
        self.declare_parameter('hsv_sat_min', 40)
        self.declare_parameter('hsv_sat_max', 255)
        self.declare_parameter('hsv_val_min', 40)
        self.declare_parameter('hsv_val_max', 255)

        # Umbral de tolerancia de pasto en zonas (%)
        self.declare_parameter('grass_warning_threshold', 0.35)

        # Suscriptor a la cámara USB
        self.image_sub = self.create_subscription(
            Image,
            '/usb_camera/image_raw',
            self.image_callback,
            10
        )

        # Publicadores
        self.image_compressed_pub = self.create_publisher(
            CompressedImage,
            '/camera/curb_detection/image_processed/compressed',
            10
        )
        self.status_pub = self.create_publisher(
            String,
            '/camera/curb_detection/status',
            10
        )

        self.get_logger().info("Nodo CurbDetectionNode (Detección de Berma y Césped) iniciado correctamente.")

    def image_callback(self, msg):
        try:
            height = msg.height
            width = msg.width
            frame = np.frombuffer(msg.data, dtype=np.uint8).reshape((height, width, 3))
        except Exception as e:
            self.get_logger().error(f"Error al deserializar frame: {str(e)}")
            return

        h, w, _ = frame.shape

        # 1. Definir Región de Interés (ROI): Mitad inferior del campo de visión (suelo al frente)
        roi_start_y = int(h * 0.4)
        roi = frame[roi_start_y:h, 0:w]

        # 2. Conversión a Espacio de Color HSV
        hsv = cv2.cvtColor(roi, cv2.COLOR_BGR2HSV)

        h_min = self.get_parameter('hsv_hue_min').get_parameter_value().integer_value
        h_max = self.get_parameter('hsv_hue_max').get_parameter_value().integer_value
        s_min = self.get_parameter('hsv_sat_min').get_parameter_value().integer_value
        s_max = self.get_parameter('hsv_sat_max').get_parameter_value().integer_value
        v_min = self.get_parameter('hsv_val_min').get_parameter_value().integer_value
        v_max = self.get_parameter('hsv_val_max').get_parameter_value().integer_value

        lower_green = np.array([h_min, s_min, v_min])
        upper_green = np.array([h_max, s_max, v_max])

        # Máscara de Césped/Pasto
        grass_mask = cv2.inRange(hsv, lower_green, upper_green)

        # Filtrado morfológico
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 5))
        grass_mask = cv2.morphologyEx(grass_mask, cv2.MORPH_OPEN, kernel)
        grass_mask = cv2.morphologyEx(grass_mask, cv2.MORPH_CLOSE, kernel)

        # 3. Análisis de Zonas de Seguridad
        roi_h, roi_w = grass_mask.shape
        w_left = int(roi_w * 0.35)
        w_right = int(roi_w * 0.65)

        mask_left = grass_mask[:, 0:w_left]
        mask_center = grass_mask[:, w_left:w_right]
        mask_right = grass_mask[:, w_right:roi_w]

        ratio_left = float(np.sum(mask_left > 0)) / (mask_left.size + 1e-5)
        ratio_center = float(np.sum(mask_center > 0)) / (mask_center.size + 1e-5)
        ratio_right = float(np.sum(mask_right > 0)) / (mask_right.size + 1e-5)

        warning_thresh = self.get_parameter('grass_warning_threshold').get_parameter_value().double_value

        status = "ON_PATH"
        steering_recommendation = 0.0

        if ratio_center > 0.45:
            status = "OFF_PATH_GRASS_AHEAD"
            steering_recommendation = -1.0 if ratio_left < ratio_right else 1.0
        elif ratio_left > warning_thresh and ratio_left > ratio_right:
            status = "WARNING_LEFT_GRASS"
            steering_recommendation = -0.5
        elif ratio_right > warning_thresh and ratio_right > ratio_left:
            status = "WARNING_RIGHT_GRASS"
            steering_recommendation = 0.5

        # 4. Superposición Visual y Anotación en la Imagen
        overlay = frame.copy()
        
        green_layer = np.zeros_like(roi)
        green_layer[grass_mask > 0] = (0, 255, 0)
        
        roi_overlay = cv2.addWeighted(roi, 0.7, green_layer, 0.3, 0)
        overlay[roi_start_y:h, 0:w] = roi_overlay

        cv2.line(overlay, (w_left, roi_start_y), (w_left, h), (255, 255, 0), 2)
        cv2.line(overlay, (w_right, roi_start_y), (w_right, h), (255, 255, 0), 2)

        edges = cv2.Canny(grass_mask, 50, 150)
        contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        for cnt in contours:
            if cv2.contourArea(cnt) > 200:
                cnt_shifted = cnt + np.array([0, roi_start_y])
                cv2.polylines(overlay, [cnt_shifted], isClosed=False, color=(0, 0, 255), thickness=2)

        color_status = (0, 255, 0)
        if "WARNING" in status:
            color_status = (0, 165, 255)
        elif "OFF_PATH" in status:
            color_status = (0, 0, 255)

        cv2.putText(overlay, f"Estado: {status}", (20, 35),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, color_status, 2)
        cv2.putText(overlay, f"Pasto Izq: {ratio_left*100:.1f}% | Der: {ratio_right*100:.1f}%", (20, 65),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 2)

        # Mostrar ventana emergente OpenCV en pantalla si show_window es True
        if self.get_parameter('show_window').get_parameter_value().bool_value:
            cv2.imshow('Deteccion de Berma (Camino vs Cesped)', overlay)
            cv2.waitKey(1)

        # Publicar estado estructurado en JSON
        status_data = {
            "status": status,
            "grass_ratio_left": round(ratio_left, 3),
            "grass_ratio_center": round(ratio_center, 3),
            "grass_ratio_right": round(ratio_right, 3),
            "steering_recommendation": steering_recommendation
        }
        json_msg = String()
        json_msg.data = json.dumps(status_data)
        self.status_pub.publish(json_msg)

        # Publicar imagen comprimida anotada
        ret_jpeg, jpeg_buf = cv2.imencode('.jpg', overlay, [int(cv2.IMWRITE_JPEG_QUALITY), 75])
        if ret_jpeg:
            comp_msg = CompressedImage()
            comp_msg.header.stamp = msg.header.stamp
            comp_msg.header.frame_id = "usb_camera_link"
            comp_msg.format = "jpeg"
            comp_msg.data = jpeg_buf.tobytes()
            self.image_compressed_pub.publish(comp_msg)

    def destroy_node(self):
        cv2.destroyAllWindows()
        super().destroy_node()

def main(args=None):
    rclpy.init(args=args)
    node = CurbDetectionNode()
    try:
        if rclpy.ok():
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
