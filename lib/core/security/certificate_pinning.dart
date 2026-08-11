import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'spki_extractor.dart';
import '../utils/app_log.dart';

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
    // C-01 (fix 07/08/2026): pin inyectado en tiempo de compilación con
    //   --dart-define=PINNED_CERT_SHA256=AB:CD:...,EF:01:...
    // Al estar compilado en el binario no es extraíble como texto del APK.
    // En debug/profile no se necesita (validateCertificate devuelve true
    // en kDebugMode/kProfileMode). En release sin --dart-define, la lista
    // queda vacía → fail-closed (ninguna conexión pasa).
    //
    // M-06 (fix 07/08/2026): se recomienda configurar ≥ 2 pins (leaf + CA
    // intermediaria). Si solo se detecta 1, se emite un aviso en debug para
    // que el equipo lo corrija antes de release.
    const raw = String.fromEnvironment('PINNED_CERT_SHA256', defaultValue: '');
    final pins = raw
        .split(',')
        .map((pin) => pin.trim().replaceAll(':', '').toUpperCase())
        .where((pin) => pin.isNotEmpty)
        .toList();

    if ((kDebugMode || kProfileMode) && pins.length == 1) {
      AppLog.d('[CertificatePinning] ⚠️  Solo 1 pin configurado. '
          'Configura al menos 2 (leaf + CA intermediaria) en '
          'PINNED_CERT_SHA256 para evitar un punto único de fallo.');
    }

    return pins;
  }

  /// True si hay al menos un pin configurado en el entorno.
  static bool get isConfigured => _pins.isNotEmpty;

  /// M-06 (fix 07/08/2026): true si hay ≥ 2 pins configurados.
  ///
  /// Un único pin crea un punto único de fallo: si el proveedor rota la clave
  /// pública (no solo el certificado) todos los usuarios quedan sin servicio
  /// hasta que se publique una nueva versión. La práctica recomendada
  /// (OWASP MASVS-NETWORK-2) es siempre configurar al menos el certificado
  /// activo del servidor Y la CA intermediaria de respaldo.
  ///
  /// Para LifeBalance esto significa pasar dos hashes en PINNED_CERT_SHA256:
  ///   `--dart-define=PINNED_CERT_SHA256=<leaf_sha256>,<intermediate_ca_sha256>`
  ///
  /// Si se detecta un único pin en modo debug/profile se emite un warning.
  static bool get hasBackupPin => _pins.length >= 2;

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
