import 'package:flutter/material.dart';

class BiometricProfileScreen extends StatefulWidget {
  const BiometricProfileScreen({super.key});

  @override
  State<BiometricProfileScreen> createState() => _BiometricProfileScreenState();
}

class _BiometricProfileScreenState extends State<BiometricProfileScreen> {
  String? _selectedGender;
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.only(left: 16.0),
          child: Center(
            child: Text(
              'LifeBalance',
              style: TextStyle(
                color: Color(0xFF3E6F58),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        leadingWidth: 100,
        actions: [
          IconButton(
            onPressed: () {},
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Icon(Icons.person_outline, color: Colors.grey, size: 20),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFFE9F1EC), // Fondo Menta Claro
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                const Text(
                  'Personaliza tu\nexperiencia',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3E6F58),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'Estos datos nos ayudan a calcular tu Sedentary Score con precisión profesional',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Card de Formulario
                Container(
                  padding: const EdgeInsets.all(28.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _SectionLabel(label: 'GÉNERO'),
                      Row(
                        children: [
                          Expanded(
                            child: _GenderCard(
                              icon: Icons.male,
                              label: 'Masculino',
                              isSelected: _selectedGender == 'Masculino',
                              onTap: () => setState(() => _selectedGender = 'Masculino'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _GenderCard(
                              icon: Icons.female,
                              label: 'Femenino',
                              isSelected: _selectedGender == 'Femenino',
                              onTap: () => setState(() => _selectedGender = 'Femenino'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      const _SectionLabel(label: 'ALTURA (CM)'),
                      _BiometricTextField(
                        controller: _heightController,
                        hintText: '175',
                        suffixText: 'cm',
                      ),
                      const SizedBox(height: 24),

                      const _SectionLabel(label: 'PESO (KG)'),
                      _BiometricTextField(
                        controller: _weightController,
                        hintText: '70',
                        suffixText: 'kg',
                      ),
                      const SizedBox(height: 24),

                      const _SectionLabel(label: 'EDAD'),
                      _BiometricTextField(
                        controller: _ageController,
                        hintText: '28',
                        suffixIcon: Icons.calendar_today_outlined,
                      ),
                      const SizedBox(height: 40),

                      // Barra de Progreso
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('Completado', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                          Text('25%', style: TextStyle(fontSize: 10, color: Color(0xFF3E6F58), fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: const LinearProgressIndicator(
                          value: 0.25,
                          backgroundColor: Color(0xFFE0EAE4),
                          color: Color(0xFF3E6F58),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.black54,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF3E6F58) : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF3E6F58) : Colors.grey.shade400,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? const Color(0xFF3E6F58) : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BiometricTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String? suffixText;
  final IconData? suffixIcon;

  const _BiometricTextField({
    required this.controller,
    required this.hintText,
    this.suffixText,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade300, fontWeight: FontWeight.normal),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        suffixIcon: suffixIcon != null
            ? Icon(suffixIcon, color: Colors.grey.shade400, size: 20)
            : suffixText != null
                ? Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      suffixText!,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
      ),
    );
  }
}
