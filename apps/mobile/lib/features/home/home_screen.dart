import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../widgets/widgets.dart';

/// Placeholder shell: proves the authed contract works end-to-end. The aha screen
/// (totals + subscription list) replaces this in subF-15.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final email = auth is SignedIn ? auth.email : '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subflow'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Вийти',
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ти в системі ✅', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(email),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Expanded(
                child: EmptyView(
                  title: 'Тут будуть твої підписки',
                  subtitle: 'Підключення monobank — subF-14,\nекран підписок — subF-15.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
