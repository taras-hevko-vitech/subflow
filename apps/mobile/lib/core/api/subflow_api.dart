import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'models.dart';

/// Typed wrapper over the dio client for the product endpoints.
class SubflowApi {
  SubflowApi(this._dio);
  final Dio _dio;

  Future<List<Connection>> listConnections() async {
    final res = await _dio.get<List<dynamic>>('/connections');
    return (res.data ?? []).map((c) => Connection.fromJson(c as Map<String, dynamic>)).toList();
  }

  /// Throws [DioException]; the connect page maps 400 → human token error.
  Future<ConnectResult> connectMonoPersonal(String token) async {
    final res = await _dio.post<Map<String, dynamic>>('/connections/mono/personal', data: {'token': token});
    return ConnectResult.fromJson(res.data!);
  }

  Future<void> setAccountTracked(String accountId, bool isTracked) async {
    await _dio.patch<void>('/accounts/$accountId', data: {'isTracked': isTracked});
  }

  Future<BackfillProgress> backfillProgress(String connectionId) async {
    final res = await _dio.get<Map<String, dynamic>>('/connections/$connectionId/backfill');
    return BackfillProgress.fromJson(res.data!);
  }

  Future<SubscriptionsSummary> subscriptions() async {
    final res = await _dio.get<Map<String, dynamic>>('/subscriptions');
    return SubscriptionsSummary.fromJson(res.data!);
  }

  Future<void> setVerdict(String subscriptionId, {required bool confirm}) async {
    await _dio.post<void>('/subscriptions/$subscriptionId/${confirm ? 'confirm' : 'reject'}');
  }
}

final subflowApiProvider = Provider<SubflowApi>((ref) => SubflowApi(ref.watch(dioProvider)));

/// Drives the home dispatcher (onboarding vs subscriptions). autoDispose so it refetches
/// whenever the home screen is re-entered (e.g. after onboarding completes).
final connectionsProvider = FutureProvider.autoDispose<List<Connection>>((ref) {
  return ref.watch(subflowApiProvider).listConnections();
});

final subscriptionsProvider = FutureProvider.autoDispose<SubscriptionsSummary>((ref) {
  return ref.watch(subflowApiProvider).subscriptions();
});
