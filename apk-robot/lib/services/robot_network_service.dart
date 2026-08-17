import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'config_service.dart';

enum SlamMode { scan, manual, autonomous }

class RobotNetworkService {
  static final RobotNetworkService _instance = RobotNetworkService._internal();
  factory RobotNetworkService() => _instance;
  RobotNetworkService._internal();

  String _ip = ConfigService.defaultIp;
  int _httpPort = ConfigService.defaultHttpPort;
  int _rosPort = ConfigService.defaultRosPort;

  bool _isConnected = false;
  SlamMode _currentMode = SlamMode.autonomous;
  bool _isMapping = true;
  String _lastCommand = 'stop';
  
  WebSocketChannel? _rosSocket;
  Timer? _statusTimer;

  final StreamController<bool> _connectionStreamController = StreamController<bool>.broadcast();
  final StreamController<SlamMode> _modeStreamController = StreamController<SlamMode>.broadcast();
  final StreamController<String> _logStreamController = StreamController<String>.broadcast();

  Stream<bool> get connectionStream => _connectionStreamController.stream;
  Stream<SlamMode> get modeStream => _modeStreamController.stream;
  Stream<String> get logStream => _logStreamController.stream;

  bool get isConnected => _isConnected;
  SlamMode get currentMode => _currentMode;
  bool get isMapping => _isMapping;
  String get lastCommand => _lastCommand;
  String get ip => _ip;
  int get httpPort => _httpPort;

  Future<void> init() async {
    _ip = await ConfigService.getRobotIp();
    _httpPort = await ConfigService.getHttpPort();
    _rosPort = await ConfigService.getRosPort();

    _addLog('Inicializando conexión con ThinkPad T490 ($_ip)...');
    _startStatusPolling();
    _connectRosbridgeWebSocket();
  }

  Future<void> updateConfig(String newIp, int newHttpPort, int newRosPort) async {
    _ip = newIp;
    _httpPort = newHttpPort;
    _rosPort = newRosPort;

    await ConfigService.saveSettings(
      ip: newIp,
      httpPort: newHttpPort,
      rosPort: newRosPort,
    );

    _addLog('Configuración actualizada: IP=$_ip, Port=$_httpPort');
    _connectRosbridgeWebSocket();
    checkConnection();
  }

  void _startStatusPolling() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      checkConnection();
    });
    checkConnection();
  }

  Future<void> checkConnection() async {
    final url = Uri.parse('http://$_ip:$_httpPort/api/slam/status');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          if (!_isConnected) {
            _isConnected = true;
            _connectionStreamController.add(true);
            _addLog('¡Conectado al servidor ThinkPad T490 en http://$_ip:$_httpPort!');
          }
          final state = data['slam_state'];
          if (state != null) {
            final modeStr = state['mode'] ?? 'scan';
            SlamMode newMode;
            if (modeStr == 'manual') {
              newMode = SlamMode.manual;
            } else if (modeStr == 'autonomous') {
              newMode = SlamMode.autonomous;
            } else {
              newMode = SlamMode.scan;
            }
            if (newMode != _currentMode) {
              _currentMode = newMode;
              _modeStreamController.add(_currentMode);
              _addLog('Función activa: ${newMode.name.toUpperCase()}');
            }
            _isMapping = state['is_mapping'] ?? true;
          }
          return;
        }
      }
    } catch (_) {}

    if (_isConnected) {
      _isConnected = false;
      _connectionStreamController.add(false);
      _addLog('Conexión con la laptop perdida. Reintentando enlace...');
    }
  }

  Future<bool> setMode(SlamMode mode) async {
    _currentMode = mode;
    _modeStreamController.add(_currentMode);

    String modeStr;
    switch (mode) {
      case SlamMode.scan:
        modeStr = 'scan';
        break;
      case SlamMode.manual:
        modeStr = 'manual';
        break;
      case SlamMode.autonomous:
        modeStr = 'autonomous';
        break;
    }

    _addLog('Función activa: ${modeStr.toUpperCase()}');

    final url = Uri.parse('http://$_ip:$_httpPort/api/slam/mode');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'mode': modeStr}),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      _addLog('Modo local actualizado. (Servidor no disponible: $e)');
    }
    return false;
  }

  Future<bool> sendDirectionCommand(String command) async {
    // REGLA ESTRICTA DE SEGURIDAD: En modo AUTÓNOMO se bloquean 100% las flechas
    if (_currentMode == SlamMode.autonomous) {
      _addLog('🔒 DIRECCIÓN BLOQUEADA: Función AUTÓNOMA Activa. Desactívala para mover manualmente.');
      return false;
    }

    _lastCommand = command;

    // 1. Enviar vía WebSocket de ROSBridge si está activo
    _sendRosbridgeCmd(command);

    // 2. Enviar vía HTTP API a la ThinkPad T490
    final url = Uri.parse('http://$_ip:$_httpPort/api/slam/cmd');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'command': command}),
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      _addLog('Error en comando: $e');
    }
    return false;
  }

  Future<bool> finishAndSaveMap() async {
    _addLog('✅ Guardando mapa y cargándolo en el programa del robot...');
    final url = Uri.parse('http://$_ip:$_httpPort/api/slam/finish');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          _isMapping = false;
          _addLog('🎉 ¡MAPA ESCANEADO Y CARGADO EN EL PROGRAMA CON ÉXITO!');
          return true;
        }
      }
    } catch (e) {
      _addLog('Error al finalizar mapeo: $e');
    }
    return false;
  }

  void _connectRosbridgeWebSocket() {
    try {
      _rosSocket?.sink.close();
      final wsUrl = Uri.parse('ws://$_ip:$_rosPort');
      _rosSocket = WebSocketChannel.connect(wsUrl);

      final advertiseMsg = jsonEncode({
        'op': 'advertise',
        'topic': '/camera/control',
        'type': 'std_msgs/msg/String',
      });
      _rosSocket?.sink.add(advertiseMsg);
    } catch (_) {}
  }

  void _sendRosbridgeCmd(String cmd) {
    try {
      final publishMsg = jsonEncode({
        'op': 'publish',
        'topic': '/camera/control',
        'msg': {'data': cmd},
      });
      _rosSocket?.sink.add(publishMsg);
    } catch (_) {}
  }

  void _addLog(String msg) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    _logStreamController.add('[$timestamp] $msg');
  }

  void dispose() {
    _statusTimer?.cancel();
    _rosSocket?.sink.close();
    _connectionStreamController.close();
    _modeStreamController.close();
    _logStreamController.close();
  }
}
