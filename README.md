# proyecto-tesis

Resumen de la Configuración Lista para Campo/Parque:
Red WiFi: La laptop emite su propio Hotspot abierto RoverNet (IP 10.42.0.1).
Conexión APK: La app se conecta directamente a http://10.42.0.1:5000 y ws://10.42.0.1:9090 para control manual, escaneo SLAM en vivo con el LiDAR y guardado del mapa.
Sensores y Visión: Mantenemos la detección de berma/césped por cámara USB (use_usb_cam:=true) y el driver del LiDAR RPLidar C1 (use_lidar:=true).