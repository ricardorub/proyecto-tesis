// public/plugins/dictionaryPlugin.js

const dictionary = {
  name: "Rover Telemetry Dashboard",
  key: "rover",
  measurements: [
    {
      key: "battery.voltage",
      name: "Batería - Voltaje",
      units: "V",
      type: "float"
    },
    {
      key: "battery.current",
      name: "Batería - Corriente",
      units: "A",
      type: "float"
    },
    {
      key: "battery.percentage",
      name: "Batería - Porcentaje",
      units: "%",
      type: "integer"
    },
    {
      key: "speed.linear",
      name: "Velocidad Lineal",
      units: "m/s",
      type: "float"
    },
    {
      key: "speed.angular",
      name: "Velocidad Angular",
      units: "rad/s",
      type: "float"
    },
    {
      key: "temperature.cpu",
      name: "Temperatura CPU",
      units: "°C",
      type: "float"
    },
    {
      key: "wifi.rssi",
      name: "Señal WiFi",
      units: "dBm",
      type: "integer"
    }
  ]
};

function getDictionary() {
  return Promise.resolve(dictionary);
}

export default function DictionaryPlugin() {
  return function install(openmct) {
    // 1. Registrar la carpeta raíz de taxonomía del Rover
    openmct.objects.addRoot({
      namespace: 'rover.taxonomy',
      key: 'rover'
    });

    // 2. Definir el ObjectProvider para la taxonomía 'rover.taxonomy'
    openmct.objects.addProvider('rover.taxonomy', {
      get: function (identifier) {
        return getDictionary().then(function (dict) {
          if (identifier.key === 'rover') {
            return {
              identifier: identifier,
              name: dict.name,
              type: 'folder',
              location: 'ROOT'
            };
          } else {
            const measurement = dict.measurements.find(m => m.key === identifier.key);
            if (measurement) {
              return {
                identifier: identifier,
                name: measurement.name,
                type: 'rover.telemetry',
                telemetry: {
                  values: [
                    {
                      key: 'utc',
                      name: 'Timestamp',
                      format: 'utc',
                      hints: {
                        domain: 1
                      }
                    },
                    {
                      key: 'value',
                      name: 'Valor',
                      units: measurement.units,
                      format: measurement.type,
                      hints: {
                        range: 1
                      }
                    }
                  ]
                },
                location: 'rover.taxonomy:rover'
              };
            }
          }
        });
      }
    });

    // 3. Registrar el CompositionProvider para definir la jerarquía (hijos del folder raíz)
    openmct.composition.addProvider({
      appliesTo: function (domainObject) {
        return domainObject.identifier.namespace === 'rover.taxonomy' &&
               domainObject.identifier.key === 'rover';
      },
      load: function (domainObject) {
        return getDictionary().then(function (dict) {
          return dict.measurements.map(function (m) {
            return {
              namespace: 'rover.taxonomy',
              key: m.key
            };
          });
        });
      }
    });

    // 4. Registrar el tipo de objeto para telemetría personalizada
    openmct.types.addType('rover.telemetry', {
      name: 'Rover Telemetry Point',
      description: 'Punto de telemetría de sensores del Rover',
      cssClass: 'icon-telemetry'
    });
  };
}
