/*
 * ESP32-WROVER Control Firmware for Rover Tesis
 * Tracción: Diferencial (2 Ruedas de Hoverboard adelante, 2 ruedas locas atrás)
 * 
 * Comunicación:
 *  - USB Serial (Serial, 115200): Conexión con ROS 2 (serial_bridge.py)
 *      - Recibe: "CMD,linear_x,angular_z\n"
 *      - Envía:  "ODOM,vx,vth\n" cada 20ms
 *  - UART2 (Serial2, 115200, TX=GPIO17, RX=GPIO16): Conexión con Mainboard Hoverboard
 *      - Protocolo estándar USART (0xABCD, steer, speed, checksum)
 */

#include <Arduino.h>

// --- CONFIGURACIÓN DE PINES Y HARDWARE ---
#define HOVER_SERIAL Serial2
#define HOVER_TX_PIN 17
#define HOVER_RX_PIN 16
#define HOVER_BAUD   115200

// --- PARÁMETROS FÍSICOS DEL ROBOT ---
const float WHEEL_BASE = 0.40;     // Distancia entre ruedas delanteras en metros (ajustar a tu chasis)
const float MAX_LINEAR_SPEED = 1.2; // Velocidad lineal máxima en m/s
const float MAX_ANGULAR_SPEED = 2.5; // Velocidad angular máxima en rad/s

// --- ESTRUCTURA DE COMUNICACIÓN CON HOVERBOARD ---
typedef struct {
  uint16_t start;
  int16_t  steer;
  int16_t  speed;
  uint16_t checksum;
} HoverboardCommand;

HoverboardCommand hoverCmd;

// --- VARIABLES DE ESTADO Y SEGURIDAD ---
float target_vx = 0.0;
float target_vth = 0.0;

float current_vx = 0.0;
float current_vth = 0.0;

unsigned long last_cmd_time = 0;
const unsigned long CMD_TIMEOUT_MS = 500; // Watchdog de seguridad (500ms sin comando = STOP)

unsigned long last_odom_time = 0;
const unsigned long ODOM_INTERVAL_MS = 20; // 50 Hz

// Función para enviar paquete a la tarjeta del Hoverboard
void sendHoverboardCommand(int16_t uSteer, int16_t uSpeed) {
  hoverCmd.start = 0xABCD;
  hoverCmd.steer = uSteer;
  hoverCmd.speed = uSpeed;
  hoverCmd.checksum = (uint16_t)(hoverCmd.start ^ hoverCmd.steer ^ hoverCmd.speed);

  HOVER_SERIAL.write((uint8_t*)&hoverCmd, sizeof(hoverCmd));
}

// Función para procesar los comandos recibidos desde ROS 2 por Serial USB
void processROSCommand(String input) {
  input.trim();
  if (input.startsWith("CMD")) {
    int firstComma = input.indexOf(',');
    int secondComma = input.indexOf(',', firstComma + 1);

    if (firstComma != -1 && secondComma != -1) {
      String str_vx = input.substring(firstComma + 1, secondComma);
      String str_vth = input.substring(secondComma + 1);

      target_vx = str_vx.toFloat();
      target_vth = str_vth.toFloat();
      
      // Limitar velocidades
      target_vx = constrain(target_vx, -MAX_LINEAR_SPEED, MAX_LINEAR_SPEED);
      target_vth = constrain(target_vth, -MAX_ANGULAR_SPEED, MAX_ANGULAR_SPEED);

      last_cmd_time = millis();
    }
  }
}

void setup() {
  // Inicialización de consola Serial USB (ROS 2)
  Serial.begin(115200);
  
  // Inicialización de puerto Serial2 para Hoverboard (TX2=17, RX2=16)
  HOVER_SERIAL.begin(HOVER_BAUD, SERIAL_8N1, HOVER_RX_PIN, HOVER_TX_PIN);

  last_cmd_time = millis();
  last_odom_time = millis();
}

void loop() {
  // 1. Lectura de comandos entrantes por Serial USB (desde ROS 2)
  while (Serial.available() > 0) {
    String line = Serial.readStringUntil('\n');
    processROSCommand(line);
  }

  // 2. Watchdog de Seguridad: Si no hay comando reciente, detener los motores
  if (millis() - last_cmd_time > CMD_TIMEOUT_MS) {
    target_vx = 0.0;
    target_vth = 0.0;
  }

  // 3. Suavizado de aceleración (Rampa básica)
  current_vx = current_vx * 0.8 + target_vx * 0.2;
  current_vth = current_vth * 0.8 + target_vth * 0.2;

  // 4. Cinemática Diferencial (Convertir vx y vth a comandos para Hoverboard)
  // Mapeo: speed representa velocidad lineal (-1000 a 1000), steer representa giro (-1000 a 1000)
  int16_t hover_speed = (int16_t)map(current_vx * 100, -MAX_LINEAR_SPEED * 100, MAX_LINEAR_SPEED * 100, -1000, 1000);
  int16_t hover_steer = (int16_t)map(current_vth * 100, -MAX_ANGULAR_SPEED * 100, MAX_ANGULAR_SPEED * 100, -1000, 1000);

  // Enviar comando a la tarjeta Hoverboard a ~50Hz
  sendHoverboardCommand(hover_steer, hover_speed);

  // 5. Enviar actualización de Odometría a ROS 2 cada 20ms (50Hz)
  if (millis() - last_odom_time >= ODOM_INTERVAL_MS) {
    last_odom_time = millis();

    // Publicar estimación de odometría real hacia serial_bridge.py
    Serial.printf("ODOM,%.3f,%.3f\n", current_vx, current_vth);
  }

  delay(5); // Pequeño delay para permitir tareas de fondo del ESP32 FreeRTOS
}
