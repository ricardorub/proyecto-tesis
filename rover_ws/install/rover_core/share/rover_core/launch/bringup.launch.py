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
        
        # 2. (Futuro) Iniciar el servidor web para Foxglove
        # Descomenta esto cuando instales rosbridge_suite
        # Node(
        #     package='rosbridge_server',
        #     executable='rosbridge_websocket',
        #     name='rosbridge_websocket',
        #     output='screen',
        #     parameters=[{'port': 9090}]
        # ),
    ])