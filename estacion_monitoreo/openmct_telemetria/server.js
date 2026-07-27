// server.js
const express = require('express');
const path = require('path');
const http = require('http');
const WebSocket = require('ws');

const app = express();
const PORT = process.env.PORT || 8080;

// Servir la librería compilada de Open MCT directamente desde su paquete
app.use('/openmct', express.static(path.join(__dirname, 'node_modules', 'openmct', 'dist')));

// Servir los archivos públicos
app.use(express.static(path.join(__dirname, 'public')));

// Crear servidor HTTP
const server = http.createServer(app);

// Crear servidor WebSocket
const wss = new WebSocket.Server({ server });

// Simulación de telemetría del rover
wss.on('connection', (ws) => {
  console.log('🔌 Cliente de telemetría conectado (WebSocket)');

  let startTime = Date.now();
  
  const intervalId = setInterval(() => {
    if (ws.readyState !== WebSocket.OPEN) return;

    const now = Date.now();
    const elapsed = (now - startTime) / 1000;

    // Generar valores realistas y suaves usando funciones matemáticas
    const voltage = 12.6 - (elapsed * 0.005) % 1.6; // Batería descargando suavemente (12.6V a 11.0V)
    const percentage = Math.max(0, Math.min(100, Math.round(((voltage - 11.0) / 1.6) * 100)));
    const current = 1.2 + Math.sin(elapsed) * 0.4 + (Math.random() * 0.1); // Corriente del motor (A)
    const linearSpeed = Math.max(0, 0.8 + Math.sin(elapsed / 5) * 0.6 + (Math.random() * 0.05)); // Velocidad lineal (m/s)
    const angularSpeed = Math.cos(elapsed / 3) * 0.4 + (Math.random() * 0.02); // Velocidad angular (rad/s)
    const cpuTemp = 42.0 + Math.sin(elapsed / 10) * 3.0 + (Math.random() * 0.3); // Temperatura CPU (°C)
    const rssi = -55 - Math.round((Math.sin(elapsed / 8) * 10) + (Math.random() * 3)); // RSSI de WiFi (dBm)

    const telemetryData = [
      { id: 'battery.voltage', value: parseFloat(voltage.toFixed(2)) },
      { id: 'battery.percentage', value: percentage },
      { id: 'battery.current', value: parseFloat(current.toFixed(2)) },
      { id: 'speed.linear', value: parseFloat(linearSpeed.toFixed(2)) },
      { id: 'speed.angular', value: parseFloat(angularSpeed.toFixed(2)) },
      { id: 'temperature.cpu', value: parseFloat(cpuTemp.toFixed(1)) },
      { id: 'wifi.rssi', value: rssi }
    ];

    telemetryData.forEach(data => {
      ws.send(JSON.stringify({
        id: data.id,
        utc: now,
        value: data.value
      }));
    });
  }, 100);

  ws.on('close', () => {
    console.log('🔌 Cliente de telemetría desconectado');
    clearInterval(intervalId);
  });
});

server.listen(PORT, () => {
  console.log(`Servidor de Telemetría corriendo en http://localhost:${PORT}`);
});