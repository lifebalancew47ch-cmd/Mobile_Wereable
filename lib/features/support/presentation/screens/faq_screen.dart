import 'package:flutter/material.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220), // Midnight Deep Navy
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('LifeBalance Watch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: CircleAvatar(radius: 14, backgroundImage: NetworkImage('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=150')),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Header Texto
            const Center(
              child: Column(
                children: [
                  Text('CENTRO DE AYUDA', style: TextStyle(color: Color(0xFF00C2FF), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  SizedBox(height: 12),
                  Text(
                    'Resolviendo tus\ndudas técnicas',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, height: 1.1),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Todo lo que necesitas saber sobre nuestra plataforma de bienestar corporativo impulsada por IA.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // Cuerpo con Categorías y Preguntas
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sidebar Categorías (Desktop style adapted for mobile)
                  SizedBox(
                    width: 100,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CATEGORIES', style: TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _CategoryItem(icon: Icons.settings, label: 'General', isActive: true),
                        _CategoryItem(icon: Icons.layers_outlined, label: 'Integraciones'),
                        _CategoryItem(icon: Icons.security_outlined, label: 'Seguridad'),
                        _CategoryItem(icon: Icons.payments_outlined, label: 'Planes'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  // FAQ List
                  Expanded(
                    child: Column(
                      children: [
                        _FAQItem(title: '¿Cómo funciona el Sedentary Score?'),
                        _FAQItem(title: 'Integración con smartwatches', icon: Icons.watch),
                        _FAQItem(title: 'Privacidad de datos corporativos', icon: Icons.lock_outline),
                        _FAQItem(title: 'Diferencia entre planes', icon: Icons.grid_view),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 60),

            // Sección Contacto
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF161F30),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('¿Aún tienes dudas?', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'Nuestro equipo de soporte técnico está disponible para ayudarte con la implementación en tu empresa.',
                    style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C2FF),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Hablar con soporte', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Documentación API', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Footer
            const Padding(
              padding: EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('LifeBalance', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Text('Privacidad', style: TextStyle(color: Colors.white38, fontSize: 10)),
                      SizedBox(width: 12),
                      Text('Términos', style: TextStyle(color: Colors.white38, fontSize: 10)),
                      SizedBox(width: 12),
                      Text('Cookies', style: TextStyle(color: Colors.white38, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  const _CategoryItem({required this.icon, required this.label, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Icon(icon, color: isActive ? const Color(0xFF00C2FF) : Colors.white24, size: 16),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.white24, fontSize: 11, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

class _FAQItem extends StatelessWidget {
  final String title;
  final IconData? icon;
  const _FAQItem({required this.title, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161F30).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: icon != null ? Icon(icon, color: const Color(0xFF00C2FF).withOpacity(0.5), size: 18) : null,
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.keyboard_arrow_down, color: Colors.white24, size: 18),
      ),
    );
  }
}
