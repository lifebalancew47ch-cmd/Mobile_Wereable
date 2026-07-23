import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/get_profile_use_case.dart';
import '../../domain/entities/user_model.dart';
import 'login_provider.dart';

final getProfileUseCaseProvider = Provider((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return GetProfileUseCase(repo);
});

final profileProvider = FutureProvider<UserModel>((ref) async {
  final getProfileUseCase = ref.watch(getProfileUseCaseProvider);
  return await getProfileUseCase.execute();
});
