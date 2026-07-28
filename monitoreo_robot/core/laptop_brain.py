# core/laptop_brain.py

import cv2
import time
import threading
import rclpy
from rclpy.node import Node
from rclpy.action import ActionClient
from geometry_msgs.msg import PoseStamped
from nav2_msgs.action import NavigateToPose
from ultralytics import YOLO

class LaptopBrainNode(Node):
    def __init__(self):
        super().__init__('laptop_brain_node')
        self.get_logger().info("Iniciando Nodo Brain (Modo CPU en ThinkPad)...")

        # 1. Cliente de Acción para Nav2
        self._nav_to_pose_client = ActionClient(self, NavigateToPose, 'navigate_to_pose')

        # 2. Cargar YOLOv8 nano (El más ligero, ideal para CPU)
        self.model = YOLO('models/yolov8n.pt') 

        # 3. Hilo para la cámara
        self.rtsp_url = "rtsp://admin:admin123@192.168.1.100:554/stream1"
        self.is_running = True
        self.vision_thread = threading.Thread(target=self._process_camera_stream)
        self.vision_thread.daemon = True
        self.vision_thread.start()

    def send_nav_goal(self, x: float, y: float, theta_z: float = 0.0, theta_w: float = 1.0):
        if not self._nav_to_pose_client.wait_for_server(timeout_sec=2.0):
            self.get_logger().error("El servidor Nav2 no está disponible.")
            return False

        goal_msg = NavigateToPose.Goal()
        goal_msg.pose.header.frame_id = 'map'
        goal_msg.pose.header.stamp = self.get_clock().now().to_msg()
        
        goal_msg.pose.pose.position.x = x
        goal_msg.pose.pose.position.y = y
        goal_msg.pose.pose.orientation.z = theta_z
        goal_msg.pose.pose.orientation.w = theta_w

        self.get_logger().info(f"Enviando meta a Nav2 -> X: {x}, Y: {y}")
        self._nav_to_pose_client.send_goal_async(goal_msg)
        return True

    def _process_camera_stream(self):
        cap = cv2.VideoCapture(self.rtsp_url)
        
        # Control de FPS para no saturar la CPU
        target_fps = 10 
        prev_time = 0

        while self.is_running:
            time_elapsed = time.time() - prev_time
            ret, frame = cap.read()
            if not ret:
                continue

            # Procesar solo a 10 FPS
            if time_elapsed > 1.0 / target_fps:
                prev_time = time.time()

                # Forzar el uso explícito de CPU en PyTorch/YOLO + Reducción de resolución
                results = self.model(frame, device='cpu', imgsz=320, stream=True, verbose=False)

                for r in results:
                    for box in r.boxes:
                        conf = float(box.conf[0])
                        if conf > 0.6:
                            # Procesamiento de detecciones
                            pass

        cap.release()

    def stop(self):
        self.is_running = False