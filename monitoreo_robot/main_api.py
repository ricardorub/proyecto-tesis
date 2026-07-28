import os
import cv2
import time
import threading
from fastapi import FastAPI, Response
from fastapi.responses import HTMLResponse, StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from dotenv import load_dotenv

# Cargar variables de entorno
load_dotenv()
CAMERA_RTSP_URL = os.getenv("CAMERA_RTSP_URL", "rtsp://192.168.1.3:554/11")
FASTAPI_PORT = int(os.getenv("FASTAPI_PORT", "8000"))
ROBOT_IP = os.getenv("ROBOT_IP", "192.168.1.2")

app = FastAPI(title="Rover Remote Monitor")

# Permitir CORS para acceso remoto
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class VideoStreamer:
    """Lee frames de la cámara IP en un hilo separado para evitar retrasos y acumulación en el búfer."""
    def __init__(self, src):
        self.src = src
        self.cap = cv2.VideoCapture(src)
        self.frame = None
        self.ret = False
        self.is_running = True
        self.lock = threading.Lock()
        
        self.thread = threading.Thread(target=self._update, name="CameraReader")
        self.thread.daemon = True
        self.thread.start()

    def _update(self):
        while self.is_running:
            if not self.cap.isOpened():
                time.sleep(1.0)
                self.cap = cv2.VideoCapture(self.src)
                continue
                
            ret, frame = self.cap.read()
            if ret:
                with self.lock:
                    self.frame = frame.copy()
                    self.ret = True
            else:
                time.sleep(0.01)

    def get_frame(self):
        with self.lock:
            if not self.ret or self.frame is None:
                return None
            # Codificar a JPEG
            ret, jpeg = cv2.imencode('.jpg', self.frame)
            if not ret:
                return None
            return jpeg.tobytes()

    def stop(self):
        self.is_running = False
        if self.cap.isOpened():
            self.cap.release()

# Lector global de stream
streamer = None

@app.on_event("startup")
def startup_event():
    global streamer
    print(f"Iniciando VideoStreamer para la cámara: {CAMERA_RTSP_URL}")
    streamer = VideoStreamer(CAMERA_RTSP_URL)

@app.on_event("shutdown")
def shutdown_event():
    global streamer
    if streamer:
        streamer.stop()

def gen_frames():
    global streamer
    while True:
        if streamer:
            frame = streamer.get_frame()
            if frame:
                yield (b'--frame\r\n'
                       b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')
        time.sleep(0.05)  # Límite a 20 FPS para ahorrar ancho de banda

@app.get("/video_feed")
def video_feed():
    return StreamingResponse(gen_frames(), media_type="multipart/x-mixed-replace; boundary=frame")

@app.get("/", response_class=HTMLResponse)
def index():
    html_content = """
    <!DOCTYPE html>
    <html lang="es">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Rover Dashboard - Control & Monitoreo</title>
        <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;600;800&display=swap" rel="stylesheet">
        <script src="https://cdn.jsdelivr.net/npm/roslib@1/build/roslib.min.js"></script>
        <style>
            :root {
                --bg-primary: #0a0b10;
                --bg-secondary: rgba(20, 22, 37, 0.6);
                --bg-tertiary: #141625;
                --accent-color: #7000ff;
                --accent-hover: #8a33ff;
                --accent-success: #00ff66;
                --accent-danger: #ff0055;
                --text-main: #f3f4f6;
                --text-muted: #9ca3af;
                --card-border: rgba(255, 255, 255, 0.08);
            }

            * {
                box-sizing: border-box;
                margin: 0;
                padding: 0;
            }

            body {
                font-family: 'Outfit', sans-serif;
                background-color: var(--bg-primary);
                color: var(--text-main);
                overflow-x: hidden;
                min-height: 100vh;
                display: flex;
                flex-direction: column;
            }

            header {
                display: flex;
                justify-content: space-between;
                align-items: center;
                padding: 1.5rem 2rem;
                background: linear-gradient(180deg, rgba(16, 12, 36, 0.4) 0%, rgba(10, 11, 16, 0) 100%);
                border-bottom: 1px solid var(--card-border);
                backdrop-filter: blur(10px);
                z-index: 10;
            }

            .logo-container {
                display: flex;
                align-items: center;
                gap: 0.75rem;
            }

            .logo-container h1 {
                font-size: 1.5rem;
                font-weight: 800;
                background: linear-gradient(90deg, #b080ff 0%, #7000ff 100%);
                -webkit-background-clip: text;
                -webkit-text-fill-color: transparent;
                letter-spacing: 1px;
            }

            .status-badge {
                display: flex;
                align-items: center;
                gap: 0.5rem;
                padding: 0.5rem 1rem;
                background-color: var(--bg-secondary);
                border: 1px solid var(--card-border);
                border-radius: 50px;
                font-size: 0.85rem;
                font-weight: 600;
            }

            .status-dot {
                width: 10px;
                height: 10px;
                background-color: var(--accent-danger);
                border-radius: 50%;
                box-shadow: 0 0 8px var(--accent-danger);
                transition: all 0.3s ease;
            }

            .status-dot.connected {
                background-color: var(--accent-success);
                box-shadow: 0 0 10px var(--accent-success);
            }

            main {
                display: grid;
                grid-template-columns: 1.5fr 1fr;
                gap: 1.5rem;
                padding: 1.5rem 2rem;
                flex-grow: 1;
                max-width: 1600px;
                margin: 0 auto;
                width: 100%;
            }

            @media (max-width: 1024px) {
                main {
                    grid-template-columns: 1fr;
                }
            }

            .card {
                background: var(--bg-secondary);
                border: 1px solid var(--card-border);
                border-radius: 18px;
                backdrop-filter: blur(16px);
                padding: 1.5rem;
                display: flex;
                flex-direction: column;
                gap: 1.25rem;
                box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5);
            }

            .card-title {
                font-size: 1.15rem;
                font-weight: 600;
                letter-spacing: 0.5px;
                border-left: 3px solid var(--accent-color);
                padding-left: 0.75rem;
                color: var(--text-main);
            }

            .video-container {
                position: relative;
                width: 100%;
                border-radius: 12px;
                overflow: hidden;
                background-color: #000;
                aspect-ratio: 16 / 9;
                border: 1px solid rgba(255, 255, 255, 0.05);
            }

            .video-stream {
                width: 100%;
                height: 100%;
                object-fit: contain;
                display: block;
            }

            .video-placeholder {
                position: absolute;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                display: flex;
                flex-direction: column;
                justify-content: center;
                align-items: center;
                color: var(--text-muted);
                gap: 1rem;
                background: linear-gradient(135deg, #100b20 0%, #050508 100%);
            }

            .grid-metrics {
                display: grid;
                grid-template-columns: repeat(2, 1fr);
                gap: 1rem;
            }

            .metric-box {
                background-color: rgba(255, 255, 255, 0.03);
                border: 1px solid var(--card-border);
                border-radius: 12px;
                padding: 1rem;
                text-align: center;
            }

            .metric-label {
                font-size: 0.8rem;
                color: var(--text-muted);
                text-transform: uppercase;
                margin-bottom: 0.25rem;
            }

            .metric-value {
                font-size: 1.75rem;
                font-weight: 800;
                color: var(--text-main);
            }

            .metric-value.highlight {
                color: var(--accent-color);
            }

            .controls-panel {
                display: grid;
                grid-template-columns: 1fr 1fr;
                gap: 1.5rem;
            }

            @media (max-width: 600px) {
                .controls-panel {
                    grid-template-columns: 1fr;
                }
            }

            .arrow-grid {
                display: grid;
                grid-template-columns: repeat(3, 1fr);
                grid-template-rows: repeat(3, 1fr);
                gap: 0.5rem;
                width: 180px;
                height: 180px;
                margin: 0 auto;
            }

            .btn-control {
                background: rgba(255, 255, 255, 0.05);
                border: 1px solid var(--card-border);
                color: var(--text-main);
                border-radius: 12px;
                cursor: pointer;
                display: flex;
                justify-content: center;
                align-items: center;
                font-size: 1.25rem;
                font-weight: bold;
                transition: all 0.2s ease;
                user-select: none;
            }

            .btn-control:hover {
                background: var(--accent-color);
                border-color: var(--accent-hover);
                transform: translateY(-2px);
                box-shadow: 0 4px 12px rgba(112, 0, 255, 0.3);
            }

            .btn-control:active {
                transform: translateY(0);
            }

            .btn-control.danger {
                background: rgba(255, 0, 85, 0.1);
                border-color: rgba(255, 0, 85, 0.3);
                color: var(--accent-danger);
            }

            .btn-control.danger:hover {
                background: var(--accent-danger);
                color: white;
                box-shadow: 0 4px 12px rgba(255, 0, 85, 0.3);
            }

            .keyboard-guide {
                font-size: 0.8rem;
                color: var(--text-muted);
                text-align: center;
                background-color: rgba(255, 255, 255, 0.02);
                padding: 0.75rem;
                border-radius: 8px;
                border: 1px dashed var(--card-border);
            }

            .keyboard-guide kbd {
                background-color: var(--bg-tertiary);
                border: 1px solid var(--card-border);
                padding: 0.1rem 0.4rem;
                border-radius: 4px;
                color: white;
                font-weight: 600;
            }
        </style>
    </head>
    <body>
        <header>
            <div class="logo-container">
                <svg width="28" height="28" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <path d="M21 16V8C21 6.89543 20.1046 6 19 6H5C3.89543 6 3 6.89543 3 8V16C3 17.1046 3.89543 18 5 18H19C20.1046 18 21 17.1046 21 16Z" stroke="#8a33ff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                    <path d="M7 21C8.65685 21 10 19.6569 10 18C10 16.3431 8.65685 15 7 15C5.34315 15 4 16.3431 4 18C4 19.6569 5.34315 21 7 21Z" stroke="#8a33ff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                    <path d="M17 21C18.6569 21 20 19.6569 20 18C20 16.3431 18.6569 15 17 15C15.3431 15 14 16.3431 14 18C14 19.6569 15.3431 21 17 21Z" stroke="#8a33ff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
                <h1>ROVER REMOTE DASHBOARD</h1>
            </div>
            <div class="status-badge">
                <div id="connection-dot" class="status-dot"></div>
                <span id="connection-text">Desconectado</span>
            </div>
        </header>

        <main>
            <!-- Panel Izquierdo: Video e Info -->
            <div style="display: flex; flex-direction: column; gap: 1.5rem;">
                <div class="card">
                    <div class="card-title">Cámara en Tiempo Real</div>
                    <div class="video-container">
                        <!-- Stream servido por FastAPI -->
                        <img id="video-feed" class="video-stream" src="/video_feed" alt="Video Stream" onerror="handleStreamError()">
                        <div id="video-placeholder" class="video-placeholder" style="display: none;">
                            <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                <path d="m22 8-6 4 6 4V8Z"/>
                                <rect width="14" height="12" x="2" y="6" rx="2" ry="2"/>
                            </svg>
                            <p>Esperando conexión del stream de cámara...</p>
                        </div>
                    </div>
                </div>

                <div class="card">
                    <div class="card-title">Detección de Inteligencia Artificial (YOLO)</div>
                    <div class="grid-metrics">
                        <div class="metric-box">
                            <div class="metric-label">Personas de Pie</div>
                            <div id="metric-standing" class="metric-value">0</div>
                        </div>
                        <div class="metric-box" style="border-color: rgba(255, 0, 85, 0.2)">
                            <div class="metric-label" style="color: var(--accent-danger)">Personas Recostadas</div>
                            <div id="metric-lying" class="metric-value highlight" style="color: var(--accent-danger)">0</div>
                        </div>
                        <div class="metric-box">
                            <div class="metric-label">Vehículos Detectados</div>
                            <div id="metric-vehicles" class="metric-value">0</div>
                        </div>
                        <div class="metric-box">
                            <div class="metric-label">Animales</div>
                            <div id="metric-animals" class="metric-value">0</div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Panel Derecho: Controles -->
            <div style="display: flex; flex-direction: column; gap: 1.5rem;">
                <div class="card">
                    <div class="card-title">Controles Remotos</div>
                    <div class="controls-panel">
                        <!-- Control del Rover -->
                        <div style="display: flex; flex-direction: column; gap: 1rem; align-items: center;">
                            <span style="font-size: 0.9rem; font-weight: 600; color: var(--text-muted)">ROVER</span>
                            <div class="arrow-grid">
                                <div></div>
                                <button class="btn-control" onmousedown="sendMove(0.3, 0.0)" onmouseup="sendStop()" title="Avanzar">▲</button>
                                <div></div>
                                <button class="btn-control" onmousedown="sendMove(0.0, 0.4)" onmouseup="sendStop()" title="Girar Izquierda">◀</button>
                                <button class="btn-control danger" onclick="sendStop()" title="Parada de Emergencia">■</button>
                                <button class="btn-control" onmousedown="sendMove(0.0, -0.4)" onmouseup="sendStop()" title="Girar Derecha">▶</button>
                                <div></div>
                                <button class="btn-control" onmousedown="sendMove(-0.3, 0.0)" onmouseup="sendStop()" title="Retroceder">▼</button>
                                <div></div>
                            </div>
                        </div>

                        <!-- Control de la Cámara -->
                        <div style="display: flex; flex-direction: column; gap: 1rem; align-items: center;">
                            <span style="font-size: 0.9rem; font-weight: 600; color: var(--text-muted)">CÁMARA</span>
                            <div class="arrow-grid">
                                <div></div>
                                <button class="btn-control" onclick="sendCamControl('up')" title="Cámara Arriba">▲</button>
                                <div></div>
                                <button class="btn-control" onclick="sendCamControl('left')" title="Cámara Izquierda">◀</button>
                                <button class="btn-control danger" onclick="sendCamControl('stop')" title="Detener Giro">■</button>
                                <button class="btn-control" onclick="sendCamControl('right')" title="Cámara Derecha">▶</button>
                                <div></div>
                                <button class="btn-control" onclick="sendCamControl('down')" title="Cámara Abajo">▼</button>
                                <div></div>
                            </div>
                        </div>
                    </div>

                    <div class="keyboard-guide">
                        <strong>Teclado:</strong> Usa <kbd>W</kbd> <kbd>A</kbd> <kbd>S</kbd> <kbd>D</kbd> o las flechas para mover el Rover. <kbd>Espacio</kbd> detiene el movimiento.
                    </div>
                </div>
            </div>
        </main>

        <script>
            // Usar la IP del robot configurada desde el backend
            var rover_ip = "{ROBOT_IP}";
            var ros_port = "9090";

            var ros = new ROSLIB.Ros({
                url: 'ws://' + rover_ip + ':' + ros_port
            });

            var connectionDot = document.getElementById('connection-dot');
            var connectionText = document.getElementById('connection-text');

            ros.on('connection', function() {
                connectionDot.className = 'status-dot connected';
                connectionText.innerText = 'Conectado a ROS';
                console.log('Conectado exitosamente con Rosbridge WebSocket.');
            });

            ros.on('error', function(error) {
                connectionDot.className = 'status-dot';
                connectionText.innerText = 'Error de Conexión';
                console.log('Error de conexión con Rosbridge WebSocket: ', error);
            });

            ros.on('close', function() {
                connectionDot.className = 'status-dot';
                connectionText.innerText = 'Desconectado';
                console.log('Conexión con Rosbridge WebSocket cerrada.');
                // Reintentar conexión automáticamente cada 5 segundos
                setTimeout(function() {
                    ros.connect('ws://' + rover_ip + ':' + ros_port);
                }, 5000);
            });

            // Tópicos de ROS 2
            var cmdVelTopic = new ROSLIB.Topic({
                ros: ros,
                name: '/cmd_vel',
                messageType: 'geometry_msgs/Twist'
            });

            var camControlTopic = new ROSLIB.Topic({
                ros: ros,
                name: '/camera/control',
                messageType: 'std_msgs/String'
            });

            var detectionsTopic = new ROSLIB.Topic({
                ros: ros,
                name: '/camera/detections',
                messageType: 'std_msgs/String'
            });

            // Suscribirse a las detecciones de YOLO
            detectionsTopic.subscribe(function(message) {
                try {
                    var data = JSON.parse(message.data);
                    document.getElementById('metric-standing').innerText = data.people_standing || 0;
                    document.getElementById('metric-lying').innerText = data.people_lying || 0;
                    document.getElementById('metric-vehicles').innerText = data.vehicles || 0;
                    document.getElementById('metric-animals').innerText = data.animals || 0;
                } catch(e) {
                    console.error("Error procesando mensaje de detecciones: ", e);
                }
            });

            // Enviar velocidades al Rover (/cmd_vel)
            function sendMove(linear_x, angular_z) {
                var twist = new ROSLIB.Message({
                    linear: { x: linear_x, y: 0.0, z: 0.0 },
                    angular: { x: 0.0, y: 0.0, z: angular_z }
                });
                cmdVelTopic.publish(twist);
            }

            function sendStop() {
                sendMove(0.0, 0.0);
            }

            // Enviar comandos a la Cámara IP (/camera/control)
            function sendCamControl(cmd) {
                var msg = new ROSLIB.Message({
                    data: cmd
                });
                camControlTopic.publish(msg);
            }

            // Control por Teclado
            var keysPressed = {};
            document.addEventListener('keydown', function(event) {
                if (event.repeat) return; // Evitar disparos repetidos automáticos del sistema
                
                var key = event.key.toLowerCase();
                keysPressed[key] = true;

                if (key === 'w' || event.key === 'ArrowUp') {
                    sendMove(0.3, 0.0);
                } else if (key === 's' || event.key === 'ArrowDown') {
                    sendMove(-0.3, 0.0);
                } else if (key === 'a' || event.key === 'ArrowLeft') {
                    sendMove(0.0, 0.4);
                } else if (key === 'd' || event.key === 'ArrowRight') {
                    sendMove(0.0, -0.4);
                } else if (event.key === ' ') {
                    sendStop();
                    event.preventDefault();
                }
            });

            document.addEventListener('keyup', function(event) {
                var key = event.key.toLowerCase();
                delete keysPressed[key];
                
                // Detener el Rover si se sueltan las teclas de dirección
                if (!keysPressed['w'] && !keysPressed['s'] && !keysPressed['a'] && !keysPressed['d'] &&
                    event.key !== ' ' && !event.key.startsWith('Arrow')) {
                    return;
                }
                
                // Si ya no se está presionando ninguna tecla de dirección, detener
                if (!keysPressed['w'] && !keysPressed['s'] && !keysPressed['a'] && !keysPressed['d']) {
                    sendStop();
                }
            });

            // Manejo de errores de la imagen de video
            function handleStreamError() {
                document.getElementById('video-feed').style.display = 'none';
                document.getElementById('video-placeholder').style.display = 'flex';
                // Intentar recargar la imagen de video cada 3 segundos
                setTimeout(function() {
                    var img = document.getElementById('video-feed');
                    img.src = "/video_feed?t=" + new Date().getTime();
                    img.style.display = 'block';
                    document.getElementById('video-placeholder').style.display = 'none';
                }, 3000);
            }
        </script>
    </body>
    </html>
    """
    return html_content.replace("{ROBOT_IP}", ROBOT_IP)

if __name__ == "__main__":
    uvicorn.run("main_api:app", host="0.0.0.0", port=FASTAPI_PORT, reload=True)