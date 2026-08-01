import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const _baseUrl = 'http://localhost:8080/api/v1';
  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));

    // 请求拦截器 - 自动加 Token
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          // Token 过期，跳转登录
          _storage.delete(key: 'auth_token');
        }
        handler.next(error);
      },
    ));
  }

  // ==================== 认证 ====================

  Future<Map<String, dynamic>> login(String email, String password) async {
    final resp = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    await _storage.write(key: 'auth_token', value: resp.data['token']);
    return resp.data;
  }

  Future<Map<String, dynamic>> register(String email, String password, String nickname) async {
    final resp = await _dio.post('/auth/register', data: {
      'email': email,
      'password': password,
      'nickname': nickname,
    });
    await _storage.write(key: 'auth_token', value: resp.data['token']);
    return resp.data;
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
  }

  // ==================== 行情 ====================

  Future<Map<String, dynamic>> getTicker(String symbol) async {
    final resp = await _dio.get('/exchange/ticker/$symbol');
    return resp.data;
  }

  Future<List<dynamic>> getKlines(String symbol, {String interval = '1h', int limit = 100}) async {
    final resp = await _dio.get('/exchange/klines/$symbol', queryParameters: {
      'interval': interval,
      'limit': limit,
    });
    return resp.data;
  }

  // ==================== 策略 ====================

  Future<List<dynamic>> getStrategies() async {
    final resp = await _dio.get('/strategy');
    return resp.data;
  }

  Future<Map<String, dynamic>> getStrategy(String id) async {
    final resp = await _dio.get('/strategy/$id');
    return resp.data;
  }

  Future<Map<String, dynamic>> createStrategy(Map<String, dynamic> data) async {
    final resp = await _dio.post('/strategy', data: data);
    return resp.data;
  }

  Future<void> startStrategy(String id) async {
    await _dio.post('/strategy/$id/start');
  }

  Future<void> stopStrategy(String id) async {
    await _dio.post('/strategy/$id/stop');
  }

  Future<Map<String, dynamic>> backtest(String id, Map<String, dynamic> params) async {
    final resp = await _dio.post('/strategy/$id/backtest', data: params);
    return resp.data;
  }

  // ==================== 交易 ====================

  Future<List<dynamic>> getTrades() async {
    final resp = await _dio.get('/trades');
    return resp.data;
  }

  Future<List<dynamic>> getPositions() async {
    final resp = await _dio.get('/trades/positions');
    return resp.data;
  }

  Future<Map<String, dynamic>> placeOrder(Map<String, dynamic> order) async {
    final resp = await _dio.post('/exchange/orders', data: order);
    return resp.data;
  }

  // ==================== AI ====================

  Future<Map<String, dynamic>> aiChat(String message) async {
    final resp = await _dio.post('/ai/chat', data: {'message': message});
    return resp.data;
  }

  Future<Map<String, dynamic>> aiGenerateStrategy(String description, {String? symbol, String? timeframe}) async {
    final resp = await _dio.post('/ai/generate-strategy', data: {
      'description': description,
      'symbol': symbol ?? 'BTCUSDT',
      'timeframe': timeframe ?? '1h',
    });
    return resp.data;
  }

  Future<Map<String, dynamic>> aiOptimizeStrategy(String id) async {
    final resp = await _dio.post('/ai/optimize/$id');
    return resp.data;
  }

  Future<List<dynamic>> getMarketInsights() async {
    final resp = await _dio.get('/ai/insights');
    return resp.data;
  }

  // ==================== 分析 ====================

  Future<Map<String, dynamic>> getAnalyticsOverview() async {
    final resp = await _dio.get('/analytics/overview');
    return resp.data;
  }

  Future<List<dynamic>> getEquityCurve() async {
    final resp = await _dio.get('/analytics/equity-curve');
    return resp.data;
  }
}
