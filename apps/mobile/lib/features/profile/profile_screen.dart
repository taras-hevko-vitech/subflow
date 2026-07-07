import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/models.dart';
import '../../core/api/subflow_api.dart';
import '../../core/auth/auth_controller.dart';
import '../../widgets/widgets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final connections = ref.watch(connectionsProvider);
    final email = auth is SignedIn ? auth.email : '';

    return Scaffold(
      appBar: AppBar(title: const Text('Профіль')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email'),
              subtitle: Text(email),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(height: 24),
            Text('monobank', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            connections.when(
              loading: () => const Padding(padding: EdgeInsets.all(16), child: LoadingView()),
              error: (e, _) => const Text('Не вдалось завантажити статус'),
              data: (list) => _ConnectionStatus(connection: list.isEmpty ? null : list.first),
            ),
            const Divider(height: 24),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Безпека і приватність'),
              trailing: const Icon(Icons.chevron_right),
              contentPadding: EdgeInsets.zero,
              onTap: () => context.push('/security'),
            ),
            ListTile(
              leading: const Icon(Icons.feedback_outlined),
              title: const Text('Детекція помилилась?'),
              trailing: const Icon(Icons.chevron_right),
              contentPadding: EdgeInsets.zero,
              onTap: () => context.push('/feedback'),
            ),
            const Divider(height: 24),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Вийти'),
              contentPadding: EdgeInsets.zero,
              onTap: () => ref.read(authControllerProvider.notifier).signOut(),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _confirmDelete(context, ref),
              icon: const Icon(Icons.delete_forever),
              label: const Text('Видалити акаунт'),
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    // double confirmation — honest, irreversible copy
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Видалити акаунт?'),
        content: const Text('Ми зітремо ВСЕ: підключення, транзакції, знайдені підписки — назавжди й без відновлення.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Скасувати')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Далі')),
        ],
      ),
    );
    if (first != true || !context.mounted) return;

    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Точно видалити?'),
        content: const Text('Це остаточно. Після видалення доведеться підключати monobank з нуля.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ні, лишити')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Видалити назавжди'),
          ),
        ],
      ),
    );
    if (second != true || !context.mounted) return;

    await ref.read(subflowApiProvider).deleteAccount();
    await ref.read(authControllerProvider.notifier).signOut(); // local logout → router → /login
  }
}

class _ConnectionStatus extends ConsumerWidget {
  const _ConnectionStatus({required this.connection});
  final Connection? connection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = connection;
    if (c == null) {
      return ListTile(
        leading: Icon(Icons.link_off, color: theme.colorScheme.onSurfaceVariant),
        title: const Text('Не підключено'),
        trailing: FilledButton(onPressed: () => context.go('/onboarding'), child: const Text('Підключити')),
        contentPadding: EdgeInsets.zero,
      );
    }
    final active = c.isActive;
    return Column(
      children: [
        ListTile(
          leading: Icon(active ? Icons.check_circle : Icons.error, color: active ? Colors.green : theme.colorScheme.error),
          title: Text(active ? 'Підключено' : 'Доступ втрачено'),
          subtitle: Text(c.lastSyncAt != null ? 'Остання синхронізація: ${_date(c.lastSyncAt!)}' : 'Ще синхронізуємо…'),
          contentPadding: EdgeInsets.zero,
        ),
        Row(
          children: [
            if (!active)
              Expanded(child: OutlinedButton(onPressed: () => context.go('/onboarding'), child: const Text('Перепідключити'))),
            if (!active) const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _confirmDisconnect(context, ref, c.id),
                style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                child: const Text("Від'єднати банк"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmDisconnect(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Від'єднати monobank?"),
        content: const Text('Заберемо доступ і зітремо завантажені транзакції. Підписки залишаться, поки не підключиш знову.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Скасувати')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Від'єднати")),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(subflowApiProvider).disconnect(id);
    ref.invalidate(connectionsProvider);
  }

  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
