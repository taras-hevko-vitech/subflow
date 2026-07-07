import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/subflow_api.dart';

/// confirm/reject with optimistic refresh: the verdict is sticky server-side, so we just
/// re-fetch the list + detail after the call. reject removes it (status → rejected).
class SubscriptionActions {
  SubscriptionActions(this._ref);
  final Ref _ref;

  Future<void> confirm(String id) => _verdict(id, confirm: true);
  Future<void> reject(String id, {String? comment}) => _verdict(id, confirm: false, comment: comment);

  Future<void> _verdict(String id, {required bool confirm, String? comment}) async {
    await _ref.read(subflowApiProvider).setVerdict(id, confirm: confirm, comment: comment);
    _ref.invalidate(subscriptionsProvider);
    _ref.invalidate(subscriptionDetailProvider(id));
  }
}

final subscriptionActionsProvider = Provider<SubscriptionActions>(SubscriptionActions.new);
