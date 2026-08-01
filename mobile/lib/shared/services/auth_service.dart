import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

final authStateProvider = AsyncNotifierProvider<AuthNotifier, String?>(() => AuthNotifier());

class AuthNotifier extends AsyncNotifier<String?> {
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> build() async {
    return await _storage.read(key: 'auth_token');
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final api = ref.read(apiServiceProvider);
      await api.login(email, password);
      final token = await _storage.read(key: 'auth_token');
      state = AsyncValue.data(token);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> register(String email, String password, String nickname) async {
    state = const AsyncValue.loading();
    try {
      final api = ref.read(apiServiceProvider);
      await api.register(email, password, nickname);
      final token = await _storage.read(key: 'auth_token');
      state = AsyncValue.data(token);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> logout() async {
    final api = ref.read(apiServiceProvider);
    await api.logout();
    state = const AsyncValue.data(null);
  }
}
