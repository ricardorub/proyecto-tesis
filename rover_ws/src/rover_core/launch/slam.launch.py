import os
from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node

def generate_launch_description():
    pkg_rover_core = get_package_share_directory('rover_core')

    # Parámetro para la ubicación del archivo YAML de parámetros
    params_file_arg = DeclareLaunchArgument(
        'params_file',
        default_value=os.path.join(pkg_rover_core, 'config', 'mapper_params_online_async.yaml'),
        description='Ruta al archivo de parámetros YAML para slam_toolbox'
    )

    # Parámetro para simulación (false para robot real)
    use_sim_time_arg = DeclareLaunchArgument(
        'use_sim_time',
        default_value='false',
        description='Usar tiempo de simulación (true/false)'
    )

    # Nodo principal de SLAM Toolbox (modo asíncrono en línea)
    slam_node = Node(
        package='slam_toolbox',
        executable='async_slam_toolbox_node',
        name='slam_toolbox',
        output='screen',
        parameters=[
            LaunchConfiguration('params_file'),
            {'use_sim_time': LaunchConfiguration('use_sim_time')}
        ]
    )

    return LaunchDescription([
        params_file_arg,
        use_sim_time_arg,
        slam_node
    ])
