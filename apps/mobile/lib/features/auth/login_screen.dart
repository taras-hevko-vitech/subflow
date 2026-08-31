import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../widgets/widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Введи коректний email');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).requestMagicLink(email);
      if (mounted) context.go('/check-email', extra: email);
    } catch (_) {
      setState(() => _error = 'Не вдалось надіслати лист. Спробуй ще раз.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text('subflow',
                  style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              Text('Твої підписки —\nпід контролем', style: theme.textTheme.headlineLarge),
              const SizedBox(height: 12),
              Text(
                'Підключи monobank за хвилину — і побачиш, скільки насправді з\'їдають твої підписки.',
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: InputDecoration(labelText: 'Твій email', errorText: _error),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              PrimaryButton(label: 'Надіслати лінк для входу', busy: _busy, onPressed: _submit),
              const SizedBox(height: 12),
              Text(
                'Без паролів: надішлемо одноразове посилання.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const Spacer(flex: 2),
              Text(
                'Продовжуючи, ти приймаєш умови і політику приватності.',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
