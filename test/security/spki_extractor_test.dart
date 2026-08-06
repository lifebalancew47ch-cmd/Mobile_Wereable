import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifebalance/core/security/spki_extractor.dart';

/// Certificados X.509 sintéticos mínimos (no criptográficamente válidos,
/// solo con la forma ASN.1 DER correcta) usados para probar
/// [SpkiExtractor] sin depender de un certificado real ni de paquetes
/// externos de generación de certificados.
///
/// Estructura de cada uno:
///   Certificate ::= SEQUENCE {
///     tbsCertificate SEQUENCE {
///       version        [0] { INTEGER 2 }   -- opcional
///       serialNumber       INTEGER
///       signature           SEQUENCE (AlgorithmIdentifier dummy)
///       issuer              SEQUENCE (Name vacío)
///       validity            SEQUENCE (vacío)
///       subject             SEQUENCE (Name vacío)
///       subjectPublicKeyInfo SEQUENCE { (marcador de bytes) }
///     }
///     signatureAlgorithm SEQUENCE (dummy)
///     signatureValue      BIT STRING (dummy)
///   }
void main() {
  group('SpkiExtractor', () {
    test('extrae el SPKI de un certificado con version [0] explícita', () {
      final der = Uint8List.fromList([
        0x30, 0x22, // Certificate SEQUENCE, len 34
        0x30, 0x18, //   tbsCertificate SEQUENCE, len 24
        0xA0, 0x03, 0x02, 0x01, 0x02, //     version [0] { INTEGER 2 }
        0x02, 0x01, 0x01, //     serialNumber INTEGER 1
        0x30, 0x02, 0x05, 0x00, //     signature SEQUENCE { NULL }
        0x30, 0x00, //     issuer SEQUENCE {}
        0x30, 0x00, //     validity SEQUENCE {}
        0x30, 0x00, //     subject SEQUENCE {}
        0x30, 0x04, 0xDE, 0xAD, 0xBE, 0xEF, //     subjectPublicKeyInfo SEQUENCE { DE AD BE EF }
        0x30, 0x02, 0x05, 0x00, //   signatureAlgorithm SEQUENCE { NULL }
        0x03, 0x02, 0x00, 0x01, //   signatureValue BIT STRING
      ]);

      final spki = SpkiExtractor.extractSubjectPublicKeyInfo(der);

      expect(spki, isNotNull);
      expect(spki, equals([0x30, 0x04, 0xDE, 0xAD, 0xBE, 0xEF]));
    });

    test('extrae el SPKI de un certificado sin version (default v1)', () {
      final der = Uint8List.fromList([
        0x30, 0x1D, // Certificate SEQUENCE, len 29
        0x30, 0x13, //   tbsCertificate SEQUENCE, len 19
        0x02, 0x01, 0x01, //     serialNumber INTEGER 1 (sin version)
        0x30, 0x02, 0x05, 0x00, //     signature SEQUENCE { NULL }
        0x30, 0x00, //     issuer SEQUENCE {}
        0x30, 0x00, //     validity SEQUENCE {}
        0x30, 0x00, //     subject SEQUENCE {}
        0x30, 0x04, 0xCA, 0xFE, 0xBA, 0xBE, //     subjectPublicKeyInfo SEQUENCE { CA FE BA BE }
        0x30, 0x02, 0x05, 0x00, //   signatureAlgorithm SEQUENCE { NULL }
        0x03, 0x02, 0x00, 0x01, //   signatureValue BIT STRING
      ]);

      final spki = SpkiExtractor.extractSubjectPublicKeyInfo(der);

      expect(spki, isNotNull);
      expect(spki, equals([0x30, 0x04, 0xCA, 0xFE, 0xBA, 0xBE]));
    });

    test('devuelve null ante bytes vacíos', () {
      expect(SpkiExtractor.extractSubjectPublicKeyInfo(Uint8List(0)), isNull);
    });

    test('devuelve null ante un DER truncado a mitad de un TLV', () {
      final truncated = Uint8List.fromList([0x30, 0x22, 0x30, 0x18, 0xA0]);
      expect(SpkiExtractor.extractSubjectPublicKeyInfo(truncated), isNull);
    });

    test('devuelve null si el primer byte no es una SEQUENCE', () {
      final notASequence = Uint8List.fromList([0x02, 0x01, 0x01]);
      expect(SpkiExtractor.extractSubjectPublicKeyInfo(notASequence), isNull);
    });

    test('devuelve null si la longitud declarada excede los bytes disponibles',
        () {
      // SEQUENCE que dice tener 100 bytes de contenido pero no los tiene.
      final overrun = Uint8List.fromList([0x30, 0x64, 0x30, 0x00]);
      expect(SpkiExtractor.extractSubjectPublicKeyInfo(overrun), isNull);
    });
  });
}
