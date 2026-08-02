import 'package:flutter/material.dart';

class WatchAlertScreen extends StatelessWidget {
  const WatchAlertScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black, // Cambiamos a negro de fondo para que el círculo blanco resalte más y ahorre batería
      body: Center(
        child: Container(
          width: screenSize.width * 0.95,
          height: screenSize.height * 0.95,
          decoration: const BoxDecoration(
            color: Color(0xFFE9F1EC),
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Contenido principal dentro del área segura
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),
                    const Text(
                      '¡Es hora de\nmoverse!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A34),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Llevas 90 min sentado',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Botón Táctil Amplio para Reloj
                    SizedBox(
                      width: screenSize.width * 0.6,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3E6F58),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: const StadiumBorder(),
                        ),
                        child: const Text(
                          'Hacer Pausa',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {},
                      child: const Text(
                        'Posponer 10 min',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Badge "Monitoring" adaptado a la parte superior de la esfera
              Positioned(
                top: 15,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD68C5E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'MONITORING',
                    style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
