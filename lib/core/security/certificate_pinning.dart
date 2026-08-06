import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'spki_extractor.dart';

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
  /// durante desarrollo sin necesidad de configurar pins (proxies locales,
  /// certificados autofirmados).
  ///
  /// Auditoria 6/08/2026 (C-01): en release mode, si no había pines
  /// configurados (p. ej. `.env.production` vacío o no cargado), la función
  /// devolvía `true` — es decir, aceptaba CUALQUIER certificado que ya había
  /// fallado la validación estándar de la CA (fail-open, vulnerable a MITM).
  /// Ahora, fuera de debug/profile, la ausencia de pines rechaza la conexión
  /// (fail-closed) en vez de degradar silenciosamente la seguridad.
  static bool validateCertificate(
    X509Certificate? certificate,
    String host,
    int port,
  ) {
    // Solo en debug/profile se permite la CA raíz del SO sin pines.
    if (kDebugMode || kProfileMode) return true;

    if (certificate == null) return false;

    if (!isConfigured) {
      // Producción sin pines configurados: nunca degradar a aceptar un
      // certificado que ya falló la validación estándar. Fail-closed.
      return false;
    }

    // Huella SHA-256 sobre el SPKI (SubjectPublicKeyInfo, la clave pública),
    // no sobre el certificado completo.
    //
    // Auditoria 6/08/2026 (C-01): antes se calculaba
    // `sha256.convert(certificate.der)` — el hash del certificado entero.
    // Las instrucciones del propio archivo (líneas 17-20, con openssl)
    // generan el pin sobre el SPKI, así que ese pin nunca coincidía con el
    // hash aquí calculado. Además, pinear el certificado completo rompe la
    // app en cada renovación (Let's Encrypt/Render cada 90 días); pinear el
    // SPKI sobrevive mientras se conserve la misma clave.
    final spkiDer = SpkiExtractor.extractSubjectPublicKeyInfo(certificate.der);
    if (spkiDer == null) {
      // Certificado con forma inesperada / no se pudo aislar el SPKI:
      // fail-closed, nunca se cae a aceptar por defecto.
      return false;
    }
    final digest = sha256.convert(spkiDer).toString();
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
