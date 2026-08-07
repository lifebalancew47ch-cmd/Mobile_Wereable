import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/profile_provider.dart';
import '../../../medical/presentation/providers/medical_provider.dart';
import '../../../medical/data/medical_api_service.dart';
import '../../../../core/security/secure_storage.dart';
import '../../../../core/utils/app_log.dart';

class BiometricProfileScreen extends ConsumerStatefulWidget {
  const BiometricProfileScreen({super.key});

  @override
  ConsumerState<BiometricProfileScreen> createState() => _BiometricProfileScreenState();
}

class _BiometricProfileScreenState extends ConsumerState<BiometricProfileScreen> {
  static const _kGender = 'biometric_gender';
  static const _kHeightCm = 'biometric_height_cm';
  static const _kWeightKg = 'biometric_weight_kg';
  static const _kAge = 'biometric_age';
  static const _storage = secureStorage;

  String? _selectedGender;
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    try {
      final gender = await _storage.read(key: _kGender);
      final height = await _storage.read(key: _kHeightCm);
      final weight = await _storage.read(key: _kWeightKg);
      final age = await _storage.read(key: _kAge);

      AppLog.d('[BiometricProfile] _loadSaved → gender=$gender '
          'height=$height weight=$weight age=$age');

      if (!mounted) return;
      setState(() {
        _selectedGender = (gender?.isNotEmpty == true) ? gender : null;
        _heightController.text = height ?? '';
        _weightController.text = weight ?? '';
        _ageController.text = age ?? '';
      });
    } catch (e) {
      debugPrint('[BiometricProfile] Error al cargar desde SecureStorage: $e');
    }
  }

  int _completedCount() {
    var count = 0;
    if (_selectedGender != null) count++;
    if (_heightController.text.trim().isNotEmpty) count++;
    if (_weightController.text.trim().isNotEmpty) count++;
    if (_ageController.text.trim().isNotEmpty) count++;
    return count;
  }

  Future<void> _save() async {
    if (_syncing) return;
    setState(() => _syncing = true);

    try {
      await _storage.write(key: _kGender, value: _selectedGender ?? '');
      await _storage.write(key: _kHeightCm, value: _heightController.text.trim());
      await _storage.write(key: _kWeightKg, value: _weightController.text.trim());
      await _storage.write(key: _kAge, value: _ageController.text.trim());
      AppLog.d('[BiometricProfile] Guardado → gender=$_selectedGender '
          'height=${_heightController.text.trim()} '
          'weight=${_weightController.text.trim()} '
          'age=${_ageController.text.trim()}');
    } catch (e) {
      debugPrint('[BiometricProfile] Error al guardar en SecureStorage: $e');
      if (!mounted) return;
      setState(() => _syncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
      );
      return;
    }

    // Sincroniza peso y altura con el Medical Data Service (POST /medical/readings)
    final height = double.tryParse(_heightController.text.trim().replaceAll(',', '.'));
    final weight = double.tryParse(_weightController.text.trim().replaceAll(',', '.'));

    var cloudMessage = '';
    final hasHeight = height != null && height > 0;
    final hasWeight = weight != null && weight > 0;
    if (hasHeight || hasWeight) {
      try {
        final api = ref.read(medicalApiServiceProvider);
        await api.addReading(MedicalReading(
          steps: 0,
          weight: hasWeight ? weight : 0,
          height: hasHeight ? height : 0,
          heartRate: 60, // Dummy requerido por validación del backend (30-250)
          spo2: 95,      // Dummy requerido por validación del backend (50-100)
          recordedAtUtc: DateTime.now(),
        ));
        cloudMessage = ' y sincronizados con la nube';
      } catch (_) {
        cloudMessage = ' (sin conexión: se guardó localmente)';
      }
    }

    if (!mounted) return;
    setState(() => _syncing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Datos biométricos guardados$cloudMessage'),
        backgroundColor: const Color(0xFF3E6F58),
      ),
    );
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final completed = _completedCount();
    final percent = completed / 4.0;

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
            onPressed: () => Navigator.of(context).pop(),
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
            color: Color(0xFFE9F1EC),
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
                profileAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (user) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      'Hola, ${user.firstName.isNotEmpty ? user.firstName : user.username}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF3E6F58),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
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
                const SizedBox(height: 32),

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
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 24),

                      const _SectionLabel(label: 'PESO (KG)'),
                      _BiometricTextField(
                        controller: _weightController,
                        hintText: '70',
                        suffixText: 'kg',
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 24),

                      const _SectionLabel(label: 'EDAD'),
                      _BiometricTextField(
                        controller: _ageController,
                        hintText: '28',
                        suffixIcon: Icons.calendar_today_outlined,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 40),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Completado', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                          Text('${(percent * 100).round()}%', style: const TextStyle(fontSize: 10, color: Color(0xFF3E6F58), fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percent,
                          backgroundColor: const Color(0xFFE0EAE4),
                          color: const Color(0xFF3E6F58),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _syncing ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF3E6F58),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _syncing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Guardar cambios', style: TextStyle(fontWeight: FontWeight.bold)),
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
  final ValueChanged<String>? onChanged;

  const _BiometricTextField({
    required this.controller,
    required this.hintText,
    this.suffixText,
    this.suffixIcon,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
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
