from setuptools import setup
import os
from glob import glob

package_name = 'rover_core'

setup(
    name=package_name,
    version='0.0.0',
    packages=[package_name],
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        # Aquí le decimos a ROS 2 que incluya la carpeta de lanzadores (launch)
        (os.path.join('share', package_name, 'launch'), glob('launch/*.launch.py')),
        # Y la carpeta de configuraciones (config)
        (os.path.join('share', package_name, 'config'), glob('config/*.yaml')),
    ],
    install_requires=['setuptools', 'pyserial'],
    zip_safe=True,
    maintainer='Ricardo',
    maintainer_email='ricardo@todo.com',
    description='Paquete central para el control del Rover con Ackermann y SLAM',
    license='Apache License 2.0',
    tests_require=['pytest'],
    entry_points={
        'console_scripts': [
            # Aquí registramos nuestro nodo de Python para poder ejecutarlo
            'serial_bridge = rover_core.serial_bridge:main',
            'vision_node = rover_core.vision_node:main',
            'detection_node = rover_core.detection_node:main',
        ],
    },
)
