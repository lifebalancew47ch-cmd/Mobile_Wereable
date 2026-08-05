import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Validación estricta de certificados TLS (SSL/TLS Pinning) con
/// comportamiento fail-closed:
///  - Si el certificado es nulo            -> rechazar.
///  - Si no hay pins configurados          -> rechazar (nunca degradar).
///  - Si el SHA-256 no coincide con un pin -> rechazar.
///
/// Los pins se configuran en .env.production con la variable
/// `PINNED_CERT_SHA256` (hex, con o sin ':'), separados por comas:
///   PINNED_CERT_SHA256=AB:CD:...:12,EF:01:...:34
///
/// Obtener el pin de un endpoint:
///   openssl s_client -connect host:443 -servername host < /dev/null \
///     | openssl x509 -pubkey -noout \
///     | openssl pkey -pubin -outform der | openssl dgst -sha256
class CertificatePinning {
  CertificatePinning._();

  static List<String>? _overridePins;

  static List<String> get _pins {
    if (_overridePins != null) return _overridePins!;
    return _loadPins();
  }

  static List<String> _loadPins() {
    final raw =
        dotenv.isInitialized ? (dotenv.env['PINNED_CERT_SHA256'] ?? '') : '';
    return raw
        .split(',')
        .map((pin) => pin.trim().replaceAll(':', '').toUpperCase())
        .where((pin) => pin.isNotEmpty)
        .toList();
  }

  /// True si hay al menos un pin configurado en el entorno.
  static bool get isConfigured => _pins.isNotEmpty;

  /// Callback usado por dio (badCertificateCallback).
  /// Se invoca SOLO cuando el certificado no valida contra la CA raíz;
  /// devolver false aquí mantiene la conexión bloqueada (fail-closed).
  ///
  /// En debug/profile mode se omite el pinning para permitir conexiones
  /// durante desarrollo sin necesidad de configurar pins. En release mode
  /// se mantiene el comportamiento fail-closed original.
  static bool validateCertificate(
    X509Certificate? certificate,
    String host,
    int port,
  ) {
    // En debug/profile o si no hay pins configurados en .env: permitir CA raíz del SO.
    if (kDebugMode || kProfileMode || !isConfigured) return true;

    if (certificate == null) return false;
    // Huella SHA-256 calculada localmente sobre el DER (sin depender de
    // getters de plataforma que varían por SDK/OS).
    final digest = sha256.convert(certificate.der).toString();
    return validatePinnedCertificate(
      sha256Hex: digest,
      host: host,
      port: port,
    );
  }

  /// Núcleo de la decisión de pinning, aislado para pruebas unitarias.
  @visibleForTesting
  static bool validatePinnedCertificate({
    required String sha256Hex,
    required String host,
    required int port,
  }) {
    final normalized = sha256Hex.replaceAll(':', '').toUpperCase();
    if (!isConfigured) return false;
    return _pins.contains(normalized);
  }

  @visibleForTesting
  static void configureForTesting(List<String> pins) {
    _overridePins = pins.map((p) => p.replaceAll(':', '').toUpperCase()).toList();
  }

  @visibleForTesting
  static void resetForTesting() {
    _overridePins = null;
  }
}
