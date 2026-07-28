import rclpy
from rclpy.node import Node
from std_msgs.msg import String
from std_srvs.srv import Trigger
import urllib.request
import urllib.error
import threading
import base64

class CameraControlNode(Node):
    def __init__(self):
        super().__init__('camera_control_node')
        
        # Parámetros para la IP, puerto y credenciales de la cámara
        self.declare_parameter('camera_ip', '192.168.1.3')
        self.declare_parameter('camera_port', 81)
        self.declare_parameter('camera_user', 'admin')
        self.declare_parameter('camera_password', '123456')
        
        # Suscriptor al tema /camera/control
        self.control_sub = self.create_subscription(
            String,
            '/camera/control',
            self.control_callback,
            10
        )
        
        # Servicios para cada movimiento
        self.srv_up = self.create_service(Trigger, '/camera/move_up', self.move_up_callback)
        self.srv_down = self.create_service(Trigger, '/camera/move_down', self.move_down_callback)
        self.srv_left = self.create_service(Trigger, '/camera/move_left', self.move_left_callback)
        self.srv_right = self.create_service(Trigger, '/camera/move_right', self.move_right_callback)
        self.srv_stop = self.create_service(Trigger, '/camera/stop', self.stop_callback)
        
        self.get_logger().info("Nodo de Control de Cámara IP iniciado con soporte de credenciales.")
        self.get_logger().info(f"Configuración actual -> IP: {self.get_camera_ip()}, Puerto: {self.get_camera_port()}")

    def get_camera_ip(self):
        return self.get_parameter('camera_ip').get_parameter_value().string_value

    def get_camera_port(self):
        return self.get_parameter('camera_port').get_parameter_value().integer_value

    def send_camera_command(self, command_id):
        """Envía el comando HTTP de control a la cámara de forma síncrona."""
        ip = self.get_camera_ip()
        port = self.get_camera_port()
        user = self.get_parameter('camera_user').get_parameter_value().string_value
        pwd = self.get_parameter('camera_password').get_parameter_value().string_value
        
        # Mapeo de comando a acción para protocolo Hipcam (HiSilicon)
        action_map = {
            0: 'up',
            1: 'down',
            2: 'left',
            3: 'right',
            4: 'stop'
        }
        act = action_map.get(command_id, 'stop')
        
        # Construir la URL con el protocolo Hipcam
        url = f"http://{ip}:{port}/web/cgi-bin/hi3510/ptzctrl.cgi?-step=0&-act={act}&-speed=45"
        
        self.get_logger().info(f"Enviando comando {command_id} ({act}) a la cámara: {url}")
        try:
            req = urllib.request.Request(url)
            
            # Agregar cabecera Basic Auth por si acaso el firmware lo requiere en headers
            auth_str = f"{user}:{pwd}"
            auth_b64 = base64.b64encode(auth_str.encode('utf-8')).decode('utf-8')
            req.add_header("Authorization", f"Basic {auth_b64}")
            
            with urllib.request.urlopen(req, timeout=1.5) as response:
                status = response.status
                body = response.read().decode('utf-8', errors='ignore').strip()
                self.get_logger().info(f"Respuesta de la cámara: Status {status}, Body: {body}")
                return True, f"Comando {command_id} ejecutado. Respuesta: {body}"
        except urllib.error.URLError as e:
            err_msg = f"Error de conexión con la cámara en {ip}:{port}: {e.reason}"
            self.get_logger().error(err_msg)
            return False, err_msg
        except Exception as e:
            err_msg = f"Error inesperado al enviar comando: {str(e)}"
            self.get_logger().error(err_msg)
            return False, err_msg

    def control_callback(self, msg):
        """Manejador para el tópico /camera/control."""
        data = msg.data.strip().lower()
        
        # Mapeamos los comandos aceptados (tanto en español, inglés, como números)
        command_map = {
            '0': 0, 'up': 0, 'arriba': 0,
            '1': 1, 'down': 1, 'abajo': 1,
            '2': 2, 'left': 2, 'izquierda': 2,
            '3': 3, 'right': 3, 'derecha': 3,
            '4': 4, 'stop': 4, 'detener': 4
        }
        
        if data in command_map:
            cmd_id = command_map[data]
            # Enviamos el comando en un hilo separado para no bloquear la cola de callbacks del nodo
            threading.Thread(target=self.send_camera_command, args=(cmd_id,)).start()
        else:
            self.get_logger().warn(
                f"Comando no reconocido: '{msg.data}'. "
                "Comandos válidos: arriba/up/0, abajo/down/1, izquierda/left/2, derecha/right/3, detener/stop/4"
            )

    # Callbacks de servicios
    def move_up_callback(self, request, response):
        success, message = self.send_camera_command(0)
        response.success = success
        response.message = message
        return response

    def move_down_callback(self, request, response):
        success, message = self.send_camera_command(1)
        response.success = success
        response.message = message
        return response

    def move_left_callback(self, request, response):
        success, message = self.send_camera_command(2)
        response.success = success
        response.message = message
        return response

    def move_right_callback(self, request, response):
        success, message = self.send_camera_command(3)
        response.success = success
        response.message = message
        return response

    def stop_callback(self, request, response):
        success, message = self.send_camera_command(4)
        response.success = success
        response.message = message
        return response

def main(args=None):
    rclpy.init(args=args)
    node = CameraControlNode()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()

if __name__ == '__main__':
    main()
