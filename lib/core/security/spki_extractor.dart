import 'dart:typed_data';

/// Extractor mínimo de ASN.1 DER para X.509 — aísla el campo
/// `SubjectPublicKeyInfo` (SPKI) de un certificado sin depender de paquetes
/// externos de criptografía/ASN.1.
///
/// Auditoria 6/08/2026 (C-01): `certificate_pinning.dart` calculaba el pin
/// como `sha256(certificate.der)` — el hash del certificado **completo**,
/// mientras que las instrucciones del propio archivo (y la práctica estándar
/// de pinning) generan el pin sobre el SPKI (la clave pública). Un pin
/// generado siguiendo las instrucciones documentadas nunca coincidía. Además,
/// el pinning de certificado completo se rompe en cada renovación (Let's
/// Encrypt cada 90 días en Render), mientras que el SPKI sobrevive mientras
/// se conserve la misma clave.
///
/// Estructura relevante (RFC 5280 §4.1):
/// ```
/// Certificate ::= SEQUENCE {
///   tbsCertificate       TBSCertificate,
///   signatureAlgorithm   AlgorithmIdentifier,
///   signatureValue       BIT STRING }
///
/// TBSCertificate ::= SEQUENCE {
///   version               [0] EXPLICIT INTEGER DEFAULT v1,  -- opcional
///   serialNumber              INTEGER,
///   signature                 AlgorithmIdentifier,
///   issuer                    Name,
///   validity                  Validity,
///   subject                   Name,
///   subjectPublicKeyInfo      SubjectPublicKeyInfo,          -- objetivo
///   ... (extensiones opcionales, no nos interesan) }
/// ```
class _Asn1Element {
  _Asn1Element(this.tag, this.contentStart, this.contentLength, this.headerLength);

  final int tag;
  final int contentStart;
  final int contentLength;
  final int headerLength;

  int get totalLength => headerLength + contentLength;
  int get contentEnd => contentStart + contentLength;
}

class SpkiExtractor {
  SpkiExtractor._();

  static const int _tagSequence = 0x30;
  static const int _tagContextVersion = 0xA0;

  /// Lee un TLV DER (tag-length-value) en [data] a partir de [offset].
  /// Devuelve `null` si los bytes disponibles no alcanzan para un TLV
  /// válido (certificado truncado o malformado) — nunca lanza excepciones,
  /// para que el llamador pueda tratarlo como fail-closed.
  static _Asn1Element? _readTlv(Uint8List data, int offset) {
    if (offset < 0 || offset >= data.length) return null;

    final tag = data[offset];
    var pos = offset + 1;
    if (pos >= data.length) return null;

    int length = data[pos];
    pos++;

    if (length & 0x80 != 0) {
      final numLengthBytes = length & 0x7F;
      // Forma indefinida (0x80) no es válida en DER, y 0 bytes no tiene sentido.
      if (numLengthBytes == 0 || pos + numLengthBytes > data.length) return null;
      length = 0;
      for (var i = 0; i < numLengthBytes; i++) {
        length = (length << 8) | data[pos + i];
      }
      pos += numLengthBytes;
    }

    final headerLength = pos - offset;
    if (length < 0 || pos + length > data.length) return null;

    return _Asn1Element(tag, pos, length, headerLength);
  }

  /// Devuelve los bytes DER completos (tag + length + content) del campo
  /// `subjectPublicKeyInfo` del certificado en formato DER, o `null` si el
  /// certificado no tiene la forma esperada de un X.509 estándar. El
  /// llamador debe tratar `null` como fallo de validación (fail-closed),
  /// nunca como "aceptar por defecto".
  static Uint8List? extractSubjectPublicKeyInfo(Uint8List certificateDer) {
    // Certificate ::= SEQUENCE { tbsCertificate, signatureAlgorithm, signatureValue }
    final certSeq = _readTlv(certificateDer, 0);
    if (certSeq == null || certSeq.tag != _tagSequence) return null;

    // tbsCertificate ::= SEQUENCE { ... }
    final tbs = _readTlv(certificateDer, certSeq.contentStart);
    if (tbs == null || tbs.tag != _tagSequence) return null;

    var offset = tbs.contentStart;

    // version [0] EXPLICIT — opcional, marcado con tag de contexto 0xA0.
    var el = _readTlv(certificateDer, offset);
    if (el == null) return null;
    if (el.tag == _tagContextVersion) {
      offset += el.totalLength;
      el = _readTlv(certificateDer, offset); // ahora sí: serialNumber
      if (el == null) return null;
    }

    // serialNumber (INTEGER)
    offset += el.totalLength;

    // signature (AlgorithmIdentifier SEQUENCE)
    el = _readTlv(certificateDer, offset);
    if (el == null) return null;
    offset += el.totalLength;

    // issuer (Name SEQUENCE)
    el = _readTlv(certificateDer, offset);
    if (el == null) return null;
    offset += el.totalLength;

    // validity (SEQUENCE)
    el = _readTlv(certificateDer, offset);
    if (el == null) return null;
    offset += el.totalLength;

    // subject (Name SEQUENCE)
    el = _readTlv(certificateDer, offset);
    if (el == null) return null;
    offset += el.totalLength;

    // subjectPublicKeyInfo (SEQUENCE) — el campo buscado.
    final spki = _readTlv(certificateDer, offset);
    if (spki == null || spki.tag != _tagSequence) return null;
    if (spki.contentEnd > tbs.contentEnd) return null; // fuera de tbsCertificate: corrupto

    return certificateDer.sublist(offset, spki.contentEnd);
  }
}
