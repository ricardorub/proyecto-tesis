// Elementos del DOM
const backendStatus = document.querySelector('#backend-status');
const rosStatus = document.querySelector('#ros-status');
const cameraFeed = document.querySelector('#camera-feed');
const overlayRtspUrl = document.querySelector('#overlay-rtsp-url');
const consoleLogs = document.querySelector('#console-logs');
const clearConsoleBtn = document.querySelector('#clear-console');

// Formulario de Configuración
const configForm = document.querySelector('#config-form');
const inputRosIp = document.querySelector('#input-ros-ip');
const inputRosPort = document.querySelector('#input-ros-port');
const inputRtspUrl = document.querySelector('#input-rtsp-url');
const inputStreamMode = document.querySelector('#input-stream-mode');
const inputDirectUrl = document.querySelector('#input-direct-url');
const inputImageTopic = document.querySelector('#input-image-topic');
const groupDirectUrl = document.querySelector('#group-direct-url');
const groupImageTopic = document.querySelector('#group-image-topic');
const groupRtspUrl = document.querySelector('#group-rtsp-url');

// Elementos de visualización
const cameraCanvas = document.querySelector('#camera-canvas');
const canvasCtx = cameraCanvas ? cameraCanvas.getContext('2d') : null;

// Cambiar visibilidad de los inputs según el modo de transmisión
function updateFormVisibility() {
    const mode = inputStreamMode.value;
    groupDirectUrl.style.display = (mode === 'direct') ? 'flex' : 'none';
    groupImageTopic.style.display = (mode === 'ros') ? 'flex' : 'none';
    groupRtspUrl.style.display = (mode === 'backend') ? 'flex' : 'none';
}
inputStreamMode.addEventListener('change', updateFormVisibility);

// Cambiar visibilidad del input según modo de transmisión
inputStreamMode.addEventListener('change', () => {
    if (inputStreamMode.value === 'direct') {
        groupDirectUrl.style.display = 'flex';
    } else {
        groupDirectUrl.style.display = 'none';
    }
});

// Botones del D-Pad
const btnUp = document.querySelector('#btn-up');
const btnDown = document.querySelector('#btn-down');
const btnLeft = document.querySelector('#btn-left');
const btnRight = document.querySelector('#btn-right');
const btnStop = document.querySelector('#btn-stop');

const buttons = {
    'up': btnUp,
    'down': btnDown,
    'left': btnLeft,
    'right': btnRight,
    'stop': btnStop
};

// Configuración Activa
let config = {
    rosbridge_ip: '127.0.0.1',
    rosbridge_port: 9090,
    rtsp_url: '',
    stream_mode: 'ros',
    direct_url: '',
    image_topic: ''
};

// Estado de Conexión y Control
let rosSocket = null;
let isRosConnected = false;
let reconnectInterval = null;
let currentCommand = null; // Comando actualmente activo
let activeKey = null; // Tecla física que está presionada
let subscribedTopic = null; // Tópico de imagen al que estamos suscritos

// Función para escribir en la consola del sistema
function log(message, type = 'system') {
    const timestamp = new Date().toLocaleTimeString();
    const logLine = document.createElement('div');
    logLine.className = `log-line ${type}`;
    logLine.textContent = `[${timestamp}] ${message}`;
    consoleLogs.appendChild(logLine);
    consoleLogs.scrollTop = consoleLogs.scrollHeight;
}

// Limpiar la consola
clearConsoleBtn.addEventListener('click', () => {
    consoleLogs.innerHTML = '';
    log('Consola limpiada', 'system');
});

// Cargar Configuración desde el API del Backend
async function fetchConfig() {
    try {
        const response = await fetch('/api/config');
        if (!response.ok) throw new Error('No se pudo obtener la configuración');
        config = await response.json();
        
        // Actualizar formulario y superposición de video
        inputRosIp.value = config.rosbridge_ip;
        inputRosPort.value = config.rosbridge_port;
        inputRtspUrl.value = config.rtsp_url;
        inputStreamMode.value = config.stream_mode || 'ros';
        inputDirectUrl.value = config.direct_url || 'http://192.168.1.3:81/videostream.cgi';
        inputImageTopic.value = config.image_topic || '/camera/image_processed';
        
        updateFormVisibility();
        updateStreamDisplay();
        
        log('Configuración cargada correctamente del backend.', 'success');
        
        // Iniciar conexión con ROSBridge
        connectROSBridge();
    } catch (error) {
        log(`Error al cargar configuración: ${error.message}`, 'error');
        backendStatus.querySelector('.status-dot').className = 'status-dot red';
        backendStatus.querySelector('.status-text').textContent = 'Error';
    }
}

// Configurar elementos de video/canvas visibles en la UI
function updateStreamDisplay() {
    if (config.stream_mode === 'ros') {
        cameraFeed.style.display = 'none';
        cameraCanvas.style.display = 'block';
        overlayRtspUrl.textContent = config.image_topic;
    } else if (config.stream_mode === 'direct') {
        cameraFeed.style.display = 'block';
        cameraCanvas.style.display = 'none';
        overlayRtspUrl.textContent = config.direct_url;
        cameraFeed.src = config.direct_url;
    } else {
        cameraFeed.style.display = 'block';
        cameraCanvas.style.display = 'none';
        overlayRtspUrl.textContent = config.rtsp_url;
        cameraFeed.src = "/api/stream";
    }
}

// Conexión WebSocket con ROSBridge
function connectROSBridge() {
    if (rosSocket) {
        rosSocket.close();
        subscribedTopic = null;
    }

    const url = `ws://${config.rosbridge_ip}:${config.rosbridge_port}`;
    log(`Conectando con ROS Bridge en ${url}...`, 'system');

    rosSocket = new WebSocket(url);

    rosSocket.onopen = () => {
        isRosConnected = true;
        updateStatusIndicator(rosStatus, true, 'Conectado');
        log('¡Conectado exitosamente a ROS Bridge!', 'success');
        
        // Anunciar/advertir el tópico en ROSBridge para poder publicar
        advertiseControlTopic();
        
        if (reconnectInterval) {
            clearInterval(reconnectInterval);
            reconnectInterval = null;
        }
    };

    rosSocket.onmessage = (event) => {
        try {
            const data = JSON.parse(event.data);
            if (data.op === 'publish') {
                const targetTopic = (config.image_topic || '/camera/image_processed').trim();
                const incomingTopic = (data.topic || '').trim();

                const isTopicMatch = (
                    incomingTopic === targetTopic ||
                    incomingTopic === '/' + targetTopic ||
                    '/' + incomingTopic === targetTopic ||
                    incomingTopic.includes('image_processed') ||
                    incomingTopic.includes('camera')
                );

                if (isTopicMatch) {
                    renderROSImage(data.msg);
                } else {
                    log(`Mensaje recibido en tópico: ${incomingTopic}`, 'system');
                }
            } else if (data.op === 'service_response' || data.op === 'status') {
                log(`ROSBridge status [${data.op}]: ${JSON.stringify(data)}`, 'system');
            }
        } catch (err) {
            console.error("Error al procesar websocket msg:", err);
        }
    };

    rosSocket.onclose = () => {
        isRosConnected = false;
        subscribedTopic = null;
        updateStatusIndicator(rosStatus, false, 'Desconectado');
        log('Conexión con ROS Bridge perdida. Reintentando en 3 segundos...', 'error');
        
        // Planificar reconexión automática si no hay una programada
        if (!reconnectInterval) {
            reconnectInterval = setInterval(connectROSBridge, 3000);
        }
    };

    rosSocket.onerror = (error) => {
        log(`Error en WebSocket de ROS Bridge`, 'error');
    };
}

// Actualizar luces de estado en la UI
function updateStatusIndicator(element, isConnected, text) {
    const dot = element.querySelector('.status-dot');
    const textSpan = element.querySelector('.status-text');
    
    if (isConnected) {
        dot.className = 'status-dot green';
        textSpan.textContent = text;
    } else {
        dot.className = 'status-dot red';
        textSpan.textContent = text;
    }
}

// Actualizar suscripción de imagen ROS
function updateImageSubscription() {
    if (!isRosConnected) return;

    if (subscribedTopic && subscribedTopic !== config.image_topic) {
        const unsubscribeMsg = {
            op: 'unsubscribe',
            topic: subscribedTopic
        };
        rosSocket.send(JSON.stringify(unsubscribeMsg));
        log(`Desuscrito de tópico de imagen anterior: ${subscribedTopic}`, 'system');
        subscribedTopic = null;
    }

    if (config.stream_mode === 'ros' && config.image_topic) {
        const subscribeMsg = {
            op: 'subscribe',
            topic: config.image_topic
        };
        rosSocket.send(JSON.stringify(subscribeMsg));
        subscribedTopic = config.image_topic;
        log(`Suscrito a tópico de imagen ROS: ${config.image_topic}`, 'system');
    }
}

// Enviar anuncio del tópico a ROSBridge
function advertiseControlTopic() {
    if (!isRosConnected) return;
    
    const advertiseMsg = {
        op: 'advertise',
        topic: '/camera/control',
        type: 'std_msgs/msg/String'
    };
    
    rosSocket.send(JSON.stringify(advertiseMsg));
    log('Tópico /camera/control anunciado en ROS.', 'system');
    
    // Configurar suscripción a imagen
    updateImageSubscription();
}

let hasLoggedFirstFrame = false;

// Renderizar imagen de ROS en el Canvas
function renderROSImage(msg) {
    if (!canvasCtx || !msg || !msg.data) return;

    // Caso 1: Imagen Comprimida (sensor_msgs/CompressedImage) o header Base64 JPEG/PNG
    const isCompressedFormat = msg.format && (msg.format.includes('jpeg') || msg.format.includes('png') || msg.format.includes('jpg') || msg.format.includes('compressed'));
    const isBase64ImageHeader = typeof msg.data === 'string' && (msg.data.startsWith('/9j/') || msg.data.startsWith('iVBORw0KGgo'));

    if (isCompressedFormat || isBase64ImageHeader) {
        const img = new Image();
        img.onload = () => {
            if (cameraCanvas.width !== img.width || cameraCanvas.height !== img.height) {
                cameraCanvas.width = img.width;
                cameraCanvas.height = img.height;
            }
            canvasCtx.drawImage(img, 0, 0);
            if (!hasLoggedFirstFrame) {
                hasLoggedFirstFrame = true;
                log('¡Fotograma comprimido/JPEG recibido y renderizado!', 'success');
            }
        };
        img.src = `data:image/jpeg;base64,${msg.data}`;
        return;
    }

    // Caso 2: Imagen Raw (sensor_msgs/Image)
    const width = msg.width;
    const height = msg.height;

    if (!width || !height) return;

    if (cameraCanvas.width !== width || cameraCanvas.height !== height) {
        cameraCanvas.width = width;
        cameraCanvas.height = height;
    }

    let bytes;
    if (typeof msg.data === 'string') {
        try {
            const binaryString = atob(msg.data);
            const len = binaryString.length;
            bytes = new Uint8Array(len);
            for (let i = 0; i < len; i++) {
                bytes[i] = binaryString.charCodeAt(i);
            }
        } catch (e) {
            console.error("Error al decodificar base64 de ROS image:", e);
            return;
        }
    } else if (Array.isArray(msg.data)) {
        bytes = new Uint8Array(msg.data);
    } else if (typeof msg.data === 'object') {
        bytes = new Uint8Array(Object.values(msg.data));
    } else {
        return;
    }

    const imgData = canvasCtx.createImageData(width, height);
    const data = imgData.data;

    const encoding = (msg.encoding || 'bgr8').toLowerCase();

    if (encoding === 'bgr8' || encoding === '8uc3') {
        for (let i = 0, j = 0; i < bytes.length; i += 3, j += 4) {
            data[j]     = bytes[i+2]; // R
            data[j+1]   = bytes[i+1]; // G
            data[j+2]   = bytes[i];   // B
            data[j+3]   = 255;        // A
        }
    } else if (encoding === 'rgb8') {
        for (let i = 0, j = 0; i < bytes.length; i += 3, j += 4) {
            data[j]     = bytes[i];   // R
            data[j+1]   = bytes[i+1]; // G
            data[j+2]   = bytes[i+2]; // B
            data[j+3]   = 255;        // A
        }
    } else if (encoding === 'mono8' || encoding === '8uc1') {
        for (let i = 0, j = 0; i < bytes.length; i++, j += 4) {
            const val = bytes[i];
            data[j]     = val;
            data[j+1]   = val;
            data[j+2]   = val;
            data[j+3]   = 255;
        }
    }

    canvasCtx.putImageData(imgData, 0, 0);

    if (!hasLoggedFirstFrame) {
        hasLoggedFirstFrame = true;
        log(`¡Primer fotograma ROS (${width}x${height} ${encoding}) renderizado en Canvas!`, 'success');
    }
}

// Enviar Comando a través de ROSBridge
function sendCommand(command) {
    if (!isRosConnected) {
        log(`No se puede enviar '${command.toUpperCase()}': ROS Bridge desconectado.`, 'error');
        return;
    }
    
    currentCommand = command;
    
    const publishMsg = {
        op: 'publish',
        topic: '/camera/control',
        msg: {
            data: command
        }
    };
    
    rosSocket.send(JSON.stringify(publishMsg));
    log(`Comando enviado -> Tópico /camera/control: "${command}"`, 'sent');
    
    // Iluminar botón visualmente
    highlightButton(command);
}

// Resaltar el botón activo en la pantalla
function highlightButton(command) {
    // Quitar active de todos
    Object.values(buttons).forEach(btn => btn.classList.remove('active'));
    
    // Agregar active al correspondiente
    if (buttons[command]) {
        buttons[command].classList.add('active');
    }
}

// Manejar cambios en el formulario de configuración
configForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const newConfig = {
        rosbridge_ip: inputRosIp.value.trim(),
        rosbridge_port: parseInt(inputRosPort.value.trim(), 10),
        rtsp_url: inputRtspUrl.value.trim(),
        stream_mode: inputStreamMode.value,
        direct_url: inputDirectUrl.value.trim(),
        image_topic: inputImageTopic.value.trim()
    };
    
    log('Guardando nueva configuración en el backend...', 'system');
    
    try {
        const response = await fetch('/api/config', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(newConfig)
        });
        
        if (!response.ok) throw new Error('Fallo al guardar en backend');
        
        const result = await response.json();
        config = result.config;
        
        // Actualizar visualización del video/tópicos
        updateStreamDisplay();
        
        log('Configuración guardada exitosamente.', 'success');
        
        // Reconectar o actualizar suscripción
        if (rosSocket && rosSocket.readyState === WebSocket.OPEN) {
            updateImageSubscription();
        } else {
            connectROSBridge();
        }
    } catch (error) {
        log(`Error al guardar configuración: ${error.message}`, 'error');
    }
});

/* --- LÓGICA DE CONTROL TÁCTIL / RATÓN --- */

// Configurar eventos de click y touch para botones direccionales
function setupButtonControl(direction) {
    const btn = buttons[direction];
    if (!btn) return;
    
    btn.addEventListener('click', (e) => {
        e.preventDefault();
        sendCommand(direction);
    });
    
    btn.addEventListener('touchstart', (e) => {
        e.preventDefault();
        sendCommand(direction);
    });
}

// Configurar todos los botones
['up', 'down', 'left', 'right', 'stop'].forEach(dir => setupButtonControl(dir));

/* --- LÓGICA DE CONTROL POR TECLADO --- */

// Mapa de teclas a comandos
const keyMap = {
    // Flechas del teclado
    'ArrowUp': 'up',
    'ArrowDown': 'down',
    'ArrowLeft': 'left',
    'ArrowRight': 'right',
    
    // Teclas WASD
    'w': 'up', 'W': 'up',
    's': 'down', 'S': 'down',
    'a': 'left', 'A': 'left',
    'd': 'right', 'D': 'right',
    
    // Teclas de Parada
    ' ': 'stop', // Barra espaciadora
    'Escape': 'stop'
};

window.addEventListener('keydown', (e) => {
    // Si el usuario está escribiendo en el formulario, no capturar las teclas de conducción
    if (document.activeElement.tagName === 'INPUT') {
        return;
    }
    
    const command = keyMap[e.key];
    if (command) {
        e.preventDefault();
        
        // Evitar múltiples envíos si se mantiene presionada la tecla (auto-repeat del sistema)
        if (activeKey === e.key) return;
        
        activeKey = e.key;
        sendCommand(command);
    }
});

window.addEventListener('keyup', (e) => {
    if (document.activeElement.tagName === 'INPUT') {
        return;
    }
    
    if (keyMap[e.key]) {
        e.preventDefault();
        
        // Solo detener si soltamos la tecla que activó el movimiento
        if (activeKey === e.key) {
            activeKey = null;
            const command = keyMap[e.key];
            if (command !== 'stop') {
                sendCommand('stop');
            } else {
                // Si soltamos la barra espaciadora, limpiamos el estilo del botón stop
                highlightButton(null);
            }
        }
    }
});

// Inicializar Aplicación al cargar
window.addEventListener('DOMContentLoaded', fetchConfig);
