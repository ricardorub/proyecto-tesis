from launch import LaunchDescription
from launch_ros.actions import Node

def generate_launch_description():
    return LaunchDescription([
        # 1. Iniciar el puente Serial con el ESP32
        Node(
            package='rover_core',
            executable='serial_bridge',
            name='serial_bridge',
            output='screen'
        ),
        
        # 2. Iniciar el nodo de control de cámara IP
        Node(
            package='rover_core',
            executable='vision_node',
            name='camera_control_node',
            output='screen',
            parameters=[{
                'camera_ip': '192.168.1.3',
                'camera_port': 81
            }]
        ),
        
        # 3. Iniciar el nodo de detección IA (YOLO)
        Node(
            package='rover_core',
            executable='detection_node',
            name='detection_node',
            output='screen',
            parameters=[{
                'rtsp_url': 'rtsp://192.168.1.3:554/11',
                'model_name': 'yolov8n.pt',
                'conf_threshold': 0.25,
                'lying_down_ratio': 1.2,
                'processing_fps': 10.0,
                'imgsz': 320,
                'device': 'cpu'
            }]
        ),
        
        # 4. Servidor WebSocket para comunicar la laptop del robot con la MacBook (requiere ros-humble-rosbridge-suite)
        Node(
            package='rosbridge_server',
            executable='rosbridge_websocket',
            name='rosbridge_websocket',
            output='screen',
            parameters=[{'port': 9090}]
        ),
    ])