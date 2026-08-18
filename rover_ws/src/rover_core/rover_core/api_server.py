import rclpy
from rclpy.node import Node
from geometry_msgs.msg import Twist
from std_msgs.msg import String
import threading
import json
import time
import subprocess
from http.server import HTTPServer, BaseHTTPRequestHandler

# Estado global del sistema SLAM
slam_state = {
    "mode": "scan", # "scan", "manual", "autonomous"
    "is_mapping": True,
    "last_command": "stop",
    "last_updated": time.time(),
    "map_saved": False
}

ros_node_instance = None

class APIRequestHandler(BaseHTTPRequestHandler):
    def _set_headers(self, status=200):
        self.send_response(status)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_OPTIONS(self):
        self._set_headers(200)

    def do_GET(self):
        if self.path == '/api/slam/status':
            self._set_headers(200)
            response = {
                "status": "success",
                "slam_state": slam_state,
                "timestamp": time.time()
            }
            self.wfile.write(json.dumps(response).encode('utf-8'))
        else:
            self._set_headers(404)
            self.wfile.write(json.dumps({"status": "error", "message": "Ruta no encontrada"}).encode('utf-8'))

    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length).decode('utf-8') if content_length > 0 else "{}"
        try:
            data = json.loads(body)
        except Exception:
            data = {}

        if self.path == '/api/slam/mode':
            new_mode = data.get('mode', 'scan')
            if new_mode in ["scan", "manual", "autonomous"]:
                slam_state["mode"] = new_mode
                slam_state["last_updated"] = time.time()
                self._set_headers(200)
                self.wfile.write(json.dumps({"status": "success", "mode": new_mode}).encode('utf-8'))
            else:
                self._set_headers(400)
                self.wfile.write(json.dumps({"status": "error", "message": "Modo inválido"}).encode('utf-8'))

        elif self.path == '/api/slam/cmd':
            cmd = data.get('command', 'stop')
            if slam_state["mode"] == "autonomous":
                self._set_headers(200)
                self.wfile.write(json.dumps({
                    "status": "blocked",
                    "message": "🔒 COMANDOS DE DIRECCIÓN BLOQUEADOS: Modo Autónomo"
                }).encode('utf-8'))
                return

            slam_state["last_command"] = cmd
            slam_state["last_updated"] = time.time()

            # Enviar comando de velocidad a ROS 2 (/cmd_vel)
            if ros_node_instance is not None:
                ros_node_instance.publish_move_command(cmd)

            self._set_headers(200)
            self.wfile.write(json.dumps({"status": "success", "command": cmd}).encode('utf-8'))

        elif self.path == '/api/slam/finish':
            slam_state["is_mapping"] = False
            slam_state["map_saved"] = True
            slam_state["last_updated"] = time.time()
            self._set_headers(200)
            self.wfile.write(json.dumps({
                "status": "success",
                "message": "Mapa escaneado guardado y cargado en el sistema de navegación."
            }).encode('utf-8'))

        elif self.path == '/api/system/activate_hotspot':
            self._set_headers(200)
            self.wfile.write(json.dumps({
                "status": "success",
                "message": "Activando Hotspot RoverNet..."
            }).encode('utf-8'))
            threading.Thread(target=self.enable_hotspot).start()

        elif self.path == '/api/system/disconnect_hotspot':
            self._set_headers(200)
            self.wfile.write(json.dumps({
                "status": "success",
                "message": "Desactivando Hotspot RoverNet y reconectando a red principal..."
            }).encode('utf-8'))
            
            # Ejecutar la desactivación del Hotspot y reconexión a la red principal WiFi
            threading.Thread(target=self.switch_wifi_networks).start()

        else:
            self._set_headers(404)
            self.wfile.write(json.dumps({"status": "error", "message": "Ruta POST no encontrada"}).encode('utf-8'))

    def enable_hotspot(self):
        time.sleep(0.5)
        print("[API SERVER] Activando Hotspot RoverNet desde petición de APK...")
        try:
            subprocess.run(["nmcli", "connection", "up", "Hotspot"], check=False)
        except Exception as e:
            print(f"[API SERVER] Error activando Hotspot: {e}")

    def switch_wifi_networks(self):
        time.sleep(0.5)
        print("[API SERVER] Desactivando Hotspot RoverNet y reconectando a red principal (JORGE 2.4G)...")
        try:
            subprocess.run(["nmcli", "connection", "down", "Hotspot"], check=False)
            subprocess.run(["nmcli", "connection", "up", "JORGE 2.4G"], check=False)
        except Exception as e:
            print(f"[API SERVER] Error en reconexión de red: {e}")

class APIServerNode(Node):
    def __init__(self):
        super().__init__('api_server_node')
        global ros_node_instance
        ros_node_instance = self

        self.cmd_pub = self.create_publisher(Twist, '/cmd_vel', 10)
        self.get_logger().info("Nodo APIServerNode de ROS 2 iniciado.")

        # Iniciar servidor HTTP en puerto 5000 en un hilo separado
        self.server = HTTPServer(('0.0.0.0', 5000), APIRequestHandler)
        self.server_thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.server_thread.start()
        self.get_logger().info("Servidor HTTP API para APK iniciado en http://0.0.0.0:5000")

    def publish_move_command(self, command):
        cmd_speeds = {
            "up": (0.3, 0.0),
            "down": (-0.3, 0.0),
            "left": (0.0, 0.5),
            "right": (0.0, -0.5),
            "stop": (0.0, 0.0)
        }
        vx, vth = cmd_speeds.get(command, (0.0, 0.0))
        
        twist = Twist()
        twist.linear.x = float(vx)
        twist.angular.z = float(vth)
        self.cmd_pub.publish(twist)
        self.get_logger().info(f"Publicado a /cmd_vel -> linear_x: {vx}, angular_z: {vth}")

    def destroy_node(self):
        if hasattr(self, 'server') and self.server:
            self.server.shutdown()
        super().destroy_node()

def main(args=None):
    rclpy.init(args=args)
    node = APIServerNode()
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
