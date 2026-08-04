import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifebalance/core/network/api_client.dart';
import '../../data/medical_api_service.dart';

final medicalApiServiceProvider = Provider<MedicalApiService>((ref) {
  final dio = ref.watch(medicalApiClientProvider);
  return MedicalApiService(dio);
});

/// Última lectura médica en la nube (GET /medical/latest).
final medicalLatestProvider = FutureProvider<MedicalReadingResponse>((ref) async {
  final api = ref.watch(medicalApiServiceProvider);
  return await api.getLatest();
});

/// Historial de lecturas médicas (GET /medical/history).
final medicalHistoryProvider = FutureProvider<List<MedicalReadingResponse>>((ref) async {
  final api = ref.watch(medicalApiServiceProvider);
  return await api.getHistory(pageSize: 50);
});
