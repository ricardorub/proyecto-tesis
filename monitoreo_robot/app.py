import os
from dotenv import load_dotenv
load_dotenv()
os.environ["OPENCV_FFMPEG_CAPTURE_OPTIONS"] = "rtsp_transport;tcp"
import cv2
import threading
import time
import json
import numpy as np
from fastapi import FastAPI, Response
from fastapi.responses import StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

app = FastAPI()

CONFIG_FILE = os.path.join(os.path.dirname(__file__), "config.json")

def load_config():
    config_data = {
        "rosbridge_ip": "192.168.18.36",
        "rosbridge_port": 9090,
        "rtsp_url": "rtsp://192.168.1.3:554/11",
        "stream_mode": "ros",
        "direct_url": "http://192.168.1.3:81/videostream.cgi",
        "image_topic": "/camera/image_processed/compressed"
    }
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "r") as f:
                file_config = json.load(f)
                config_data.update(file_config)
        except Exception:
            pass

    # Garantizar que los valores de .env tengan máxima prioridad
    if os.getenv("ROBOT_IP"):
        config_data["rosbridge_ip"] = os.getenv("ROBOT_IP")
    if os.getenv("CAMERA_RTSP_URL") or os.getenv("CAMERA_RSTP_URL"):
        config_data["rtsp_url"] = os.getenv("CAMERA_RTSP_URL") or os.getenv("CAMERA_RSTP_URL")
    if os.getenv("ROS_IMAGE_TOPIC"):
        config_data["image_topic"] = os.getenv("ROS_IMAGE_TOPIC")
    return config_data

def save_config(config_data):
    try:
        with open(CONFIG_FILE, "w") as f:
            json.dump(config_data, f, indent=2)
    except Exception as e:
        print(f"Error al guardar configuración: {e}")

class ConfigModel(BaseModel):
    rosbridge_ip: str
    rosbridge_port: int
    rtsp_url: str
    stream_mode: str
    direct_url: str
    image_topic: str

class VideoStreamer:
    def __init__(self):
        self.rtsp_url = ""
        self.frame = None
        self.started = False
        self.lock = threading.Lock()
        self.thread = None
        self.cap = None

    def start(self, rtsp_url):
        self.stop()
        self.rtsp_url = rtsp_url
        self.started = True
        self.frame = None
        self.thread = threading.Thread(target=self._update, daemon=True)
        self.thread.start()

    def _update(self):
        print(f"Iniciando captura de RTSP: {self.rtsp_url}")
        self.cap = cv2.VideoCapture(self.rtsp_url)
        # Ajuste de buffer para menor latencia (dependiendo de la build de OpenCV)
        self.cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        
        while self.started:
            if not self.cap or not self.cap.isOpened():
                print(f"Reconectando a la cámara en {self.rtsp_url}...")
                if self.cap:
                    self.cap.release()
                time.sleep(2.0)
                self.cap = cv2.VideoCapture(self.rtsp_url)
                self.cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
                continue

            ret, frame = self.cap.read()
            if ret:
                with self.lock:
                    self.frame = frame.copy()
            else:
                time.sleep(0.01)
                
        if self.cap:
            self.cap.release()

    def get_frame(self):
        with self.lock:
            if self.frame is None:
                return None
            # Codificar a JPEG
            ret, jpeg = cv2.imencode('.jpg', self.frame)
            if ret:
                return jpeg.tobytes()
        return None

    def stop(self):
        self.started = False
        if self.thread:
            self.thread.join(timeout=1.0)
            self.thread = None
        if self.cap:
            self.cap.release()
            self.cap = None

streamer = VideoStreamer()

@app.on_event("startup")
def startup_event():
    config = load_config()
    if config.get("stream_mode") == "backend":
        streamer.start(config.get("rtsp_url", ""))

@app.on_event("shutdown")
def shutdown_event():
    streamer.stop()

def generate_placeholder():
    # Generar un fotograma elegante en modo oscuro que indique la falta de señal
    img = np.zeros((480, 640, 3), dtype=np.uint8)
    
    # Dibujar líneas de cuadrícula tipo HUD militar/robótico
    cv2.drawMarker(img, (320, 240), (40, 40, 60), markerType=cv2.MARKER_CROSS, markerSize=40, thickness=1)
    cv2.rectangle(img, (15, 15), (625, 465), (30, 30, 40), 1)
    cv2.rectangle(img, (30, 30), (610, 450), (20, 20, 25), 1)
    
    # Círculos HUD concéntricos
    cv2.circle(img, (320, 240), 100, (25, 25, 35), 1)
    cv2.circle(img, (320, 240), 180, (20, 20, 30), 1)
    
    # Textos informativos con look tecnológico (Cian y Gris)
    cv2.putText(img, "[ SIN SENAL DE VIDEO ]", (170, 220),
                cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 242, 254), 2, cv2.LINE_AA)
    cv2.putText(img, "Intentando conectar con la camara...", (165, 260),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (148, 163, 184), 1, cv2.LINE_AA)
                
    ret, jpeg = cv2.imencode('.jpg', img)
    return jpeg.tobytes()

def gen_frames():
    placeholder = generate_placeholder()
    while True:
        frame_bytes = streamer.get_frame()
        if frame_bytes is None:
            frame_bytes = placeholder
            time.sleep(0.2)  # Menos FPS si está desconectada para ahorrar CPU
        else:
            time.sleep(0.033)  # Limitar stream a aprox. 30 FPS para no saturar ancho de banda
            
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')

@app.get("/api/stream")
def video_feed():
    return StreamingResponse(gen_frames(), media_type="multipart/x-mixed-replace; boundary=frame")

@app.get("/api/config")
def get_config():
    return load_config()

@app.post("/api/config")
def update_config(config: ConfigModel):
    new_config = config.dict()
    save_config(new_config)
    # Iniciar o detener la captura según el modo
    if new_config["stream_mode"] == "backend":
        streamer.start(new_config["rtsp_url"])
    else:
        streamer.stop()
    return {"status": "success", "config": new_config}

# --- ENDPOINTS PARA SESIÓN DE MAPEO Y NAVEGACIÓN (CONTROL DESDE APP APK) ---
slam_state = {
    "mode": "scan",  # "scan", "manual", "autonomous"
    "is_mapping": True,
    "last_command": "stop",
    "last_updated": time.time(),
    "map_saved": False
}

class SlamModeModel(BaseModel):
    mode: str  # "scan" | "manual" | "autonomous"

class SlamCmdModel(BaseModel):
    command: str  # "up" | "down" | "left" | "right" | "stop"

@app.get("/api/slam/status")
def get_slam_status():
    return {
        "status": "success",
        "slam_state": slam_state,
        "timestamp": time.time()
    }

@app.post("/api/slam/mode")
def set_slam_mode(payload: SlamModeModel):
    if payload.mode in ["scan", "manual", "autonomous"]:
        slam_state["mode"] = payload.mode
        slam_state["last_updated"] = time.time()
        print(f"[SLAM SERVER] Función cambiada a: {payload.mode.upper()}")
        return {"status": "success", "mode": payload.mode}
    return {"status": "error", "message": "Modo inválido. Usa 'scan', 'manual' o 'autonomous'"}

@app.post("/api/slam/cmd")
def send_slam_cmd(payload: SlamCmdModel):
    if slam_state["mode"] == "autonomous":
        return {
            "status": "blocked",
            "message": "🔒 COMANDOS DE DIRECCIÓN BLOQUEADOS: El robot está en Modo Autónomo"
        }
    slam_state["last_command"] = payload.command
    slam_state["last_updated"] = time.time()
    print(f"[SLAM SERVER] Comando de movimiento en modo {slam_state['mode'].upper()}: {payload.command}")
    return {"status": "success", "command": payload.command}

@app.post("/api/slam/finish")
def finish_slam():
    slam_state["is_mapping"] = False
    slam_state["map_saved"] = True
    slam_state["last_updated"] = time.time()
    print("[SLAM SERVER] Escaneo completado. Mapa guardado y cargado en el sistema de navegación.")
    return {"status": "success", "message": "Mapa escaneado guardado y cargado en el sistema de navegación."}


# Asegurar que exista la carpeta static
static_dir = os.path.join(os.path.dirname(__file__), "static")
if not os.path.exists(static_dir):
    os.makedirs(static_dir)

# Montar los archivos estáticos para la UI web
app.mount("/", StaticFiles(directory=static_dir, html=True), name="static")
