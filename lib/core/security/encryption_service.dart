import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionService {
  static const _storage = FlutterSecureStorage();
  static const _keyAlias = 'db_encryption_key';

  /// Recupera la clave de encriptación AES. Si no existe, genera una nueva y la guarda de forma segura.
  static Future<String> getEncryptionKey() async {
    String? key = await _storage.read(key: _keyAlias);
    if (key == null) {
      key = _generateRandomKey();
      await _storage.write(key: _keyAlias, value: key);
    }
    return key;
  }

  static String _generateRandomKey() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64UrlEncode(values);
  }
}
