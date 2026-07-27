// public/plugins/telemetryPlugin.js

export default function TelemetryPlugin() {
  return function install(openmct) {
    const socketUrl = (window.location.protocol === 'https:' ? 'wss://' : 'ws://') + window.location.host;
    let socket = null;
    const listeners = {};
    const messageQueue = [];

    function connect() {
      console.log(`🔌 Conectando al WebSocket de telemetría: ${socketUrl}`);
      socket = new WebSocket(socketUrl);

      socket.onopen = function () {
        console.log('✅ Conexión WebSocket establecida con el Rover');
        // Vaciar la cola de mensajes si el socket estuvo caído
        while (messageQueue.length > 0 && socket.readyState === WebSocket.OPEN) {
          socket.send(messageQueue.shift());
        }
      };

      socket.onmessage = function (event) {
        try {
          const point = JSON.parse(event.data);
          // point: { id: 'battery.voltage', utc: 1690000000000, value: 12.34 }
          if (listeners[point.id]) {
            listeners[point.id].forEach(function (callback) {
              callback(point);
            });
          }
        } catch (e) {
          console.error('Error al procesar mensaje WebSocket:', e);
        }
      };

      socket.onclose = function () {
        console.warn('❌ Conexión WebSocket cerrada. Intentando reconectar en 3 segundos...');
        socket = null;
        setTimeout(connect, 3000);
      };

      socket.onerror = function (error) {
        console.error('Error en WebSocket:', error);
      };
    }

    // Iniciar la conexión
    connect();

    const provider = {
      supportsSubscribe: function (domainObject) {
        return domainObject.type === 'rover.telemetry';
      },
      subscribe: function (domainObject, callback) {
        const key = domainObject.identifier.key;
        
        if (!listeners[key]) {
          listeners[key] = [];
        }
        
        listeners[key].push(callback);

        // Envía el comando de suscripción por si el servidor lo requiere
        const msg = JSON.stringify({ action: 'subscribe', key: key });
        if (socket && socket.readyState === WebSocket.OPEN) {
          socket.send(msg);
        } else {
          messageQueue.push(msg);
        }

        // Retornar la función para cancelar la suscripción
        return function unsubscribe() {
          listeners[key] = listeners[key].filter(function (cb) {
            return cb !== callback;
          });
          
          const unsubMsg = JSON.stringify({ action: 'unsubscribe', key: key });
          if (socket && socket.readyState === WebSocket.OPEN) {
            socket.send(unsubMsg);
          }
        };
      },
      supportsRequest: function (domainObject) {
        return domainObject.type === 'rover.telemetry';
      },
      request: function (domainObject, options) {
        const key = domainObject.identifier.key;
        const start = options.start;
        const end = options.end;
        const step = 1000; // 1 punto por segundo
        const data = [];
        
        const maxPoints = 300; // Limitar puntos históricos para rendimiento
        const calculatedPoints = Math.ceil((end - start) / step);
        const count = Math.min(maxPoints, calculatedPoints);
        
        let current = start;
        if (calculatedPoints > maxPoints) {
          current = end - (maxPoints * step);
        }

        for (let i = 0; i < count; i++) {
          const elapsed = (current - start) / 1000;
          let value = 0;

          // Ecuaciones idénticas a las del simulador en server.js
          if (key === 'battery.voltage') {
            value = 12.6 - (elapsed * 0.005) % 1.6;
          } else if (key === 'battery.percentage') {
            const v = 12.6 - (elapsed * 0.005) % 1.6;
            value = Math.max(0, Math.min(100, Math.round(((v - 11.0) / 1.6) * 100)));
          } else if (key === 'battery.current') {
            value = 1.2 + Math.sin(elapsed) * 0.4 + (Math.sin(elapsed * 2) * 0.05);
          } else if (key === 'speed.linear') {
            value = Math.max(0, 0.8 + Math.sin(elapsed / 5) * 0.6);
          } else if (key === 'speed.angular') {
            value = Math.cos(elapsed / 3) * 0.4;
          } else if (key === 'temperature.cpu') {
            value = 42.0 + Math.sin(elapsed / 10) * 3.0;
          } else if (key === 'wifi.rssi') {
            value = -55 - Math.round(Math.sin(elapsed / 8) * 10);
          }

          data.push({
            id: key,
            utc: current,
            value: parseFloat(value.toFixed(2))
          });

          current += step;
        }

        return Promise.resolve(data);
      }
    };

    openmct.telemetry.addProvider(provider);
  };
}
