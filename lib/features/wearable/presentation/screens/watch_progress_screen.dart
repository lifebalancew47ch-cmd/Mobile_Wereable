import 'package:flutter/material.dart';

class WatchProgressScreen extends StatelessWidget {
  const WatchProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtenemos el tamaño de la pantalla para calcular el centro seguro
    final screenSize = MediaQuery.of(context).size;
    final double padding = screenSize.width * 0.1; // 10% de margen de seguridad

    return Scaffold(
      backgroundColor: const Color(0xFFE9F1EC),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          // Borde sutil que sigue la forma del reloj
          border: Border.all(color: const Color(0xFFD1DCD6), width: 2),
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'META DIARIA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF3E6F58),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: screenSize.width * 0.6,
                      height: screenSize.width * 0.6,
                      child: const CircularProgressIndicator(
                        value: 0.45,
                        strokeWidth: 10,
                        backgroundColor: Color(0xFFE9F1EC),
                        color: Color(0xFF3E6F58),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          '45',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A34),
                            height: 1,
                          ),
                        ),
                        Text(
                          'PUNTAJE',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '3/5 Pausas',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A34),
                ),
              ),
              const SizedBox(height: 4),
              _buildDots(),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: 4,
        height: 4,
        decoration: BoxDecoration(
          color: index == 1 ? const Color(0xFF3E6F58) : Colors.grey.shade300,
          shape: BoxShape.circle,
        ),
      )),
    );
  }
}
