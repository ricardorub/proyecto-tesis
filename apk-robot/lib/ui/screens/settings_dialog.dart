import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../services/robot_network_service.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController _ipController;
  late TextEditingController _httpPortController;
  late TextEditingController _rosPortController;

  final _netService = RobotNetworkService();

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: _netService.ip);
    _httpPortController = TextEditingController(text: _netService.httpPort.toString());
    _rosPortController = TextEditingController(text: '9090');
  }

  @override
  void dispose() {
    _ipController.dispose();
    _httpPortController.dispose();
    _rosPortController.dispose();
    super.dispose();
  }

  void _save() {
    final ip = _ipController.text.trim();
    final httpPort = int.tryParse(_httpPortController.text.trim()) ?? 8000;
    final rosPort = int.tryParse(_rosPortController.text.trim()) ?? 9090;

    _netService.updateConfig(ip, httpPort, rosPort);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.borderDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.wifi_tethering_rounded, color: AppTheme.neonCyan),
                SizedBox(width: 10),
                Text(
                  'Red ThinkPad T490',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Campo de IP
            const Text(
              'IP del Robot / SoftAP (ej. 192.168.4.1 o 10.42.0.1)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _ipController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.bgDark,
                prefixIcon: const Icon(Icons.computer_rounded, color: AppTheme.neonCyan),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.borderDark),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Campos de Puerto HTTP y Rosbridge
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Puerto HTTP API', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _httpPortController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppTheme.bgDark,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Puerto ROSBridge', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _rosPortController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppTheme.bgDark,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Botón Guardar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.neonBlue,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'GUARDAR Y CONECTAR',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
