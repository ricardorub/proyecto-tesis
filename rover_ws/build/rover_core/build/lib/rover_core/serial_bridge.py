import rclpy
from rclpy.node import Node
from geometry_msgs.msg import Twist, TransformStamped
from nav_msgs.msg import Odometry
from tf2_ros import TransformBroadcaster
import serial
import math

class RoverSerialBridge(Node):
    def __init__(self):
        super().__init__('rover_serial_bridge')
        
        # --- CONFIGURACIÓN DEL PUERTO USB ---
        # Ajusta esto si tu ESP32 se conecta como /dev/ttyACM0
        self.serial_port = '/dev/ttyUSB0'
        self.baud_rate = 115200
        
        try:
            self.esp32 = serial.Serial(self.serial_port, self.baud_rate, timeout=0.1)
            self.get_logger().info(f"Conectado al ESP32 en {self.serial_port}")
        except serial.SerialException:
            self.get_logger().error(f"Fallo al abrir {self.serial_port}. Verifica el cable y los permisos.")
            return

        # --- SUSCRIPTORES Y PUBLICADORES ---
        self.cmd_sub = self.create_subscription(Twist, '/cmd_vel', self.cmd_callback, 10)
        self.odom_pub = self.create_publisher(Odometry, '/odom', 10)
        self.tf_broadcaster = TransformBroadcaster(self)

        # --- VARIABLES DE ODOMETRÍA ---
        self.x = 0.0
        self.y = 0.0
        self.th = 0.0
        self.last_time = self.get_clock().now()

        # Timer para leer el USB a ~50Hz (cada 0.02 segundos)
        self.timer = self.create_timer(0.02, self.read_serial)

    def cmd_callback(self, msg):
        """Atrapa las órdenes de Nav2 y las manda al ESP32"""
        linear_x = msg.linear.x
        angular_z = msg.angular.z
        
        # Enviamos la meta. El ESP32 se encargará de la matemática Ackermann.
        command = f"CMD,{linear_x:.3f},{angular_z:.3f}\n"
        self.esp32.write(command.encode('utf-8'))

    def read_serial(self):
        """Lee lo que el ESP32 nos responde"""
        if self.esp32.in_waiting > 0:
            try:
                line = self.esp32.readline().decode('utf-8').strip()
                # El ESP32 debe responder: ODOM,velocidad_lineal_real,velocidad_angular_real
                if line.startswith("ODOM"):
                    parts = line.split(',')
                    if len(parts) == 3:
                        vx = float(parts[1])
                        vth = float(parts[2])
                        self.publish_odometry(vx, vth)
            except Exception as e:
                pass # Ignoramos errores de lectura por ruido en el cable

    def publish_odometry(self, vx, vth):
        """Calcula la posición matemática del rover y la publica a Nav2"""
        current_time = self.get_clock().now()
        dt = (current_time.nanoseconds - self.last_time.nanoseconds) / 1e9
        
        # Integración cinemática básica
        delta_x = (vx * math.cos(self.th)) * dt
        delta_y = (vx * math.sin(self.th)) * dt
        delta_th = vth * dt

        self.x += delta_x
        self.y += delta_y
        self.th += delta_th
        self.last_time = current_time

        # Transformación a Quaternions (requerido por ROS 2 para 3D)
        q_z = math.sin(self.th / 2.0)
        q_w = math.cos(self.th / 2.0)

        # Publicar mensaje Odometry
        odom = Odometry()
        odom.header.stamp = current_time.to_msg()
        odom.header.frame_id = "odom"
        odom.child_frame_id = "base_link"
        odom.pose.pose.position.x = self.x
        odom.pose.pose.position.y = self.y
        odom.pose.pose.orientation.z = q_z
        odom.pose.pose.orientation.w = q_w
        odom.twist.twist.linear.x = vx
        odom.twist.twist.angular.z = vth
        self.odom_pub.publish(odom)

        # Publicar la Transformada TF (Crucial para que RViz/Foxglove funcione)
        t = TransformStamped()
        t.header.stamp = current_time.to_msg()
        t.header.frame_id = "odom"
        t.child_frame_id = "base_link"
        t.transform.translation.x = self.x
        t.transform.translation.y = self.y
        t.transform.rotation.z = q_z
        t.transform.rotation.w = q_w
        self.tf_broadcaster.sendTransform(t)

def main(args=None):
    rclpy.init(args=args)
    bridge_node = RoverSerialBridge()
    try:
        rclpy.spin(bridge_node)
    except KeyboardInterrupt:
        pass
    finally:
        bridge_node.destroy_node()
        rclpy.shutdown()

if __name__ == '__main__':
    main()