import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics.dart';
import '../../core/api/models.dart';
import '../../core/api/subflow_api.dart';

/// State for the onboarding wizard. The PageView index is UI-local; this holds the data
/// that survives page changes (the connection + its accounts).
class OnboardingState {
  const OnboardingState({this.connecting = false, this.error, this.connectionId, this.accounts = const []});

  final bool connecting;
  final String? error;
  final String? connectionId;
  final List<BankAccountView> accounts;

  bool get connected => connectionId != null;

  OnboardingState copyWith({bool? connecting, String? error, bool clearError = false, String? connectionId, List<BankAccountView>? accounts}) {
    return OnboardingState(
      connecting: connecting ?? this.connecting,
      error: clearError ? null : (error ?? this.error),
      connectionId: connectionId ?? this.connectionId,
      accounts: accounts ?? this.accounts,
    );
  }
}

class OnboardingController extends Notifier<OnboardingState> {
  SubflowApi get _api => ref.read(subflowApiProvider);

  @override
  OnboardingState build() => const OnboardingState();

  /// Validates + stores the token and mirrors accounts. Returns true on success so the
  /// wizard advances to the account-selection page.
  Future<bool> connect(String token) async {
    state = state.copyWith(connecting: true, clearError: true);
    try {
      final result = await _api.connectMonoPersonal(token.trim());
      state = state.copyWith(connecting: false, connectionId: result.connectionId, accounts: result.accounts);
      await Analytics.connectSuccess();
      return true;
    } on DioException catch (e) {
      final msg = e.response?.statusCode == 400
          ? (e.response?.data is Map ? (e.response?.data['message'] as String?) : null) ??
              'Токен невалідний — перевір, чи скопіював його повністю'
          : 'monobank недоступний, спробуй за хвилину';
      state = state.copyWith(connecting: false, error: msg);
      await Analytics.connectFail(e.response?.statusCode?.toString() ?? 'network');
      return false;
    }
  }

  /// Optimistic toggle; the server call is fire-and-forget (revert on error).
  Future<void> toggleAccount(String accountId, bool tracked) async {
    state = state.copyWith(
      accounts: [
        for (final a in state.accounts)
          if (a.id == accountId) (a..isTracked = tracked) else a,
      ],
    );
    try {
      await _api.setAccountTracked(accountId, tracked);
    } catch (_) {
      state = state.copyWith(
        accounts: [
          for (final a in state.accounts)
            if (a.id == accountId) (a..isTracked = !tracked) else a,
        ],
      );
    }
  }
}

final onboardingControllerProvider = NotifierProvider<OnboardingController, OnboardingState>(OnboardingController.new);

/// Live backfill progress for the final onboarding page. Polls every 2s until done.
final backfillProgressProvider = StreamProvider.autoDispose.family<BackfillProgress, String>((ref, connectionId) async* {
  final api = ref.watch(subflowApiProvider);
  while (true) {
    final p = await api.backfillProgress(connectionId);
    yield p;
    if (p.done) break;
    await Future<void>.delayed(const Duration(seconds: 2));
  }
});
