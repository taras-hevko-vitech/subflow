import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/subflow_api.dart';
import '../../core/auth/auth_controller.dart';
import '../../widgets/widgets.dart';
import '../subscriptions/subscriptions_view.dart';

/// Dispatcher: no active connection → connect CTA (→ onboarding); connected → the aha screen.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final connections = ref.watch(connectionsProvider);
    final auth = ref.watch(authControllerProvider);
    final email = auth is SignedIn ? auth.email : '';
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // mockup header: mark + title left, avatar right (no Material app bar)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                children: [
                  const SubflowMark(),
                  const SizedBox(width: 10),
                  Text('Підписки', style: GoogleFonts.rubik(fontSize: 20, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
                  const Spacer(),
                  InkWell(
                    onTap: () => context.go('/profile'),
                    borderRadius: BorderRadius.circular(20),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        email.isEmpty ? '?' : email.characters.first.toUpperCase(),
                        style: GoogleFonts.rubik(fontSize: 15, fontWeight: FontWeight.w600, color: theme.colorScheme.onPrimaryContainer),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: connections.when(
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(message: 'Не вдалось завантажити', onRetry: () => ref.invalidate(connectionsProvider)),
                data: (list) {
                  final active = list.where((c) => c.isActive).toList();
                  if (active.isEmpty) return _ConnectCta(revoked: list.any((c) => !c.isActive));
                  return SubscriptionsView(backfillDone: active.first.backfill.done);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectCta extends StatelessWidget {
  const _ConnectCta({required this.revoked});
  final bool revoked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.account_balance_wallet, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(revoked ? 'Доступ до monobank втрачено' : 'Підключи monobank',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(revoked ? 'Перепідключи, щоб знову бачити підписки.' : 'Займе хвилину. Далі Subflow усе зробить сам.',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          PrimaryButton(label: revoked ? 'Перепідключити' : 'Підключити monobank', onPressed: () => context.go('/onboarding')),
        ],
      ),
    );
  }
}
