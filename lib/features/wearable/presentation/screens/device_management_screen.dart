import 'package:flutter/material.dart';

class DeviceManagementScreen extends StatelessWidget {
  const DeviceManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9F1EC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: const BackButton(color: Color(0xFF3E6F58)),
        title: const Text('Gestión de Dispositivo',
          style: TextStyle(color: Color(0xFF3E6F58), fontWeight: FontWeight.bold, fontSize: 18)),
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: CircleAvatar(radius: 16, backgroundImage: NetworkImage('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=150')),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('DISPOSITIVO CONECTADO',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 16),

            // Connected Device Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFF0F7F4), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.watch_rounded, color: Color(0xFF3E6F58), size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('LifeBalance Watch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            const Text('Executive Edition', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 4),
                            Row(
                              children: const [
                                Icon(Icons.bluetooth_connected, color: Color(0xFF3E6F58), size: 12),
                                SizedBox(width: 4),
                                Text('Conectado via Bluetooth 5.2', style: TextStyle(color: Color(0xFF3E6F58), fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: const [
                          Text('Batería', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                          Text('88%', style: TextStyle(color: Color(0xFF3E6F58), fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Última sinc.', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          Text('Hace 2 minutos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFEF3EB),
                          foregroundColor: const Color(0xFFD68C5E),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Desconectar', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            const Text('SINCRONIZACIÓN',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 16),

            // Sync Settings Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  _buildSyncOption(Icons.notifications_active_outlined, 'Alertas en tiempo real', 'Notificaciones inmediatas de salud', true),
                  const Divider(indent: 50),
                  _buildSyncOption(Icons.sync, 'Sincronización de datos', 'Cloud backup automático', true),
                  const Divider(indent: 50),
                  _buildSyncOption(Icons.battery_saver_outlined, 'Modo de bajo consumo', 'Extiende la vida útil al 40%', false),
                ],
              ),
            ),

            const SizedBox(height: 24),
            // Info Row
            Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF3E6F58), size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(color: Colors.grey, fontSize: 11, height: 1.4),
                      children: [
                        TextSpan(text: 'Las configuraciones avanzadas de telemetría se encuentran disponibles en el portal web de '),
                        TextSpan(text: 'Executive Wellness.', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3E6F58))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncOption(IconData icon, String title, String subtitle, bool value) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFFF0F7F4), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: const Color(0xFF3E6F58), size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      trailing: Switch(
        value: value,
        onChanged: (v) {},
        activeColor: const Color(0xFF3E6F58),
      ),
    );
  }
}
