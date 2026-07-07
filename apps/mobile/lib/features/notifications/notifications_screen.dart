import 'package:flutter/material.dart';

/// Notifications inbox (design "Сповіщення") — the feed itself arrives with push
/// notifications (subF-16). Until then: an honest, styled empty state.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Сповіщення')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(Icons.notifications_none, size: 36, color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(height: 20),
              Text('Тут з\'являться сповіщення', style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Попередимо за день до списання — і коли підписка подорожчає.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
