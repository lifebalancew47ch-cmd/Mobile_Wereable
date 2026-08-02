import 'package:flutter/material.dart';

class WatchConnectivityScreen extends StatelessWidget {
  const WatchConnectivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFE9F1EC),
      body: Center(
        child: Container(
          width: screenSize.width * 0.95,
          height: screenSize.height * 0.95,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Conectividad',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3E6F58))),
                    const SizedBox(height: 20),
                    // Phone to Watch visual
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.smartphone_rounded, color: Color(0xFF3E6F58), size: 28),
                        const SizedBox(width: 8),
                        Container(width: 40, height: 2, color: Colors.grey.shade300),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.circle, size: 4, color: Colors.grey),
                        ),
                        Container(width: 40, height: 2, color: Colors.grey.shade300),
                        const SizedBox(width: 8),
                        const Icon(Icons.watch_rounded, color: Color(0xFF3E6F58), size: 28),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Comunicación con Teléfono',
                      style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    // Switch
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: true,
                        onChanged: (v) {},
                        activeColor: const Color(0xFF3E6F58),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3E6F58).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('CONECTADO',
                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF3E6F58))),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
