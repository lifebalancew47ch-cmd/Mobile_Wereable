class Validators {
  static final _email = RegExp(r"^[\w.+-]+@[\w-]+(\.[\w-]+)+$");

  static String? email(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Ingresa tu correo';
    if (s.length > 254) return 'Correo demasiado largo';
    if (!_email.hasMatch(s)) return 'Formato de correo no válido';
    return null;
  }

  static String? passwordRequired(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'La contraseña es obligatoria';
    return null;
  }

  static String? intInRange(String? v, {required int min, required int max, required String label}) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return '$label es obligatorio';
    final n = int.tryParse(s);
    if (n == null) return '$label debe ser un número entero';
    if (n < min || n > max) return '$label debe estar entre $min y $max';
    return null;
  }
  
  static String? doubleInRange(String? v, {required double min, required double max, required String label}) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return '$label es obligatorio';
    final n = double.tryParse(s);
    if (n == null) return '$label debe ser un número válido';
    if (n < min || n > max) return '$label debe estar entre $min y $max';
    return null;
  }
}
