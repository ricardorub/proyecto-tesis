import 'package:shared_preferences/shared_preferences.dart';

class ConfigService {
  static const String keyRobotIp = 'robot_ip';
  static const String keyHttpPort = 'http_port';
  static const String keyRosPort = 'ros_port';

  // IP por defecto para la conexión directa a la ThinkPad T490 (Hotspot / SoftAP)
  static const String defaultIp = '192.168.4.1';
  static const int defaultHttpPort = 8000;
  static const int defaultRosPort = 9090;

  static Future<String> getRobotIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyRobotIp) ?? defaultIp;
  }

  static Future<int> getHttpPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(keyHttpPort) ?? defaultHttpPort;
  }

  static Future<int> getRosPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(keyRosPort) ?? defaultRosPort;
  }

  static Future<void> saveSettings({
    required String ip,
    required int httpPort,
    required int rosPort,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyRobotIp, ip.trim());
    await prefs.setInt(keyHttpPort, httpPort);
    await prefs.setInt(keyRosPort, rosPort);
  }
}
