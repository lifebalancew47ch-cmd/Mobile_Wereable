import 'package:flutter/material.dart';

class DeviceScanningScreen extends StatelessWidget {
  const DeviceScanningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9F1EC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('EXECUTIVE\nWELLNESS',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF3E6F58), letterSpacing: 1.5)
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none, color: Color(0xFF3E6F58))),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // Radar Animation Placeholder
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF3E6F58).withOpacity(0.1),
                        const Color(0xFFE9F1EC),
                      ],
                    ),
                  ),
                ),
                // Concéntricos del radar
                ...List.generate(3, (index) => Container(
                  width: 80.0 + (index * 60),
                  height: 80.0 + (index * 60),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF3E6F58).withOpacity(0.1)),
                  ),
                )),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.bluetooth, color: Color(0xFF3E6F58), size: 40),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          const Text('Buscando dispositivos...',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF3E6F58))),
          const SizedBox(height: 8),
          const Text('Asegúrate de que tu dispositivo esté en\nmodo emparejamiento.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13)),

          const SizedBox(height: 40),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DISPOSITIVOS CERCANOS',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                  const SizedBox(height: 16),
                  _buildDeviceItem('LifeBalance Watch Pro', 'Conectado recientemente', true),
                  _buildDeviceItem('Apple Watch Series 9', 'Señal fuerte', false),
                  _buildDeviceItem('Garmin Fenix 7', 'Detectado hace 1 min', false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(String name, String status, bool isPair) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFF0F7F4), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.watch_rounded, color: Color(0xFF3E6F58), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(status, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: isPair ? const Color(0xFF3E6F58) : const Color(0xFFE9F1EC),
              foregroundColor: isPair ? Colors.white : const Color(0xFF3E6F58),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Pair', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
