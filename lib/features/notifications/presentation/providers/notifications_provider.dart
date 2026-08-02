import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifebalance/core/network/api_client.dart';
import '../../data/datasources/notifications_api_service.dart';
import '../../domain/entities/notification_item.dart';

final notificationsApiServiceProvider = Provider((ref) {
  final dio = ref.watch(notificationsApiClientProvider);
  return NotificationsApiService(dio);
});

final notificationsProvider = FutureProvider<List<NotificationItem>>((ref) async {
  final api = ref.watch(notificationsApiServiceProvider);
  return await api.getUserNotifications(limit: 20);
});
