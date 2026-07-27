// public/plugins/main.js
import DictionaryPlugin from './dictionaryPlugin.js';
import TelemetryPlugin from './telemetryPlugin.js';

// Ruta para iconos y assets de Open MCT
openmct.setAssetPath('/openmct/');

// Plugins por defecto válidos
openmct.install(openmct.plugins.LocalStorage());
openmct.install(openmct.plugins.MyItems());
openmct.install(openmct.plugins.Timeline());
openmct.install(openmct.plugins.Notebook());

// Tema visual oscuro (Base)
openmct.install(openmct.plugins.Espresso());

// Instalar el sistema de tiempo UTC
openmct.install(openmct.plugins.UTCTimeSystem());

// Instalar el conductor de tiempo (Time Conductor UI) para controlar el rango temporal
openmct.install(openmct.plugins.Conductor({
  menuOptions: [
    {
      name: "Realtime",
      timeSystem: 'utc',
      clock: 'local',
      clockOffsets: { start: -15 * 60 * 1000, end: 0 }
    },
    {
      name: "Fixed",
      timeSystem: 'utc',
      bounds: {
        start: Date.now() - 15 * 60 * 1000,
        end: Date.now()
      }
    }
  ]
}));

// Instalar nuestro Diccionario y el escucha de telemetría por WebSocket
openmct.install(DictionaryPlugin());
openmct.install(TelemetryPlugin());

// Iniciar la plataforma
openmct.start();