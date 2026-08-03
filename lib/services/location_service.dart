import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Coordenadas GPS capturadas (solo en cambios drásticos de estado).
class GpsCoordinate {
  final double latitude;
  final double longitude;
  final DateTime capturedAt;

  GpsCoordinate(this.latitude, this.longitude, this.capturedAt);
}

/// Captura GPS de baja frecuencia (se especifica "solo activo ante cambios
/// drásticos de estado"): la activación se hace bajo demanda (p. ej. al
/// disparar una alerta de sedentarismo), nunca en streaming continuo para no
/// drenar batería.
class LocationService {
  /// Solicita permiso y devuelve las coordenadas actuales, o `null` si no hay
  /// permiso / GPS apagado / fallo transitorio. Nunca lanza.
  Future<GpsCoordinate?> capture() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var granted = await Permission.location.request().isGranted;
      if (!granted) {
        granted = await Permission.locationWhenInUse.request().isGranted;
      }
      if (!granted) return null;

      final position = await Geolocator.getCurrentPosition();
      return GpsCoordinate(
        position.latitude,
        position.longitude,
        DateTime.now(),
      );
    } catch (e) {
      debugPrint('[GPS] Captura fallida: $e');
      return null;
    }
  }
}