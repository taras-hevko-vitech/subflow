import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../widgets/widgets.dart';

class CheckEmailScreen extends ConsumerStatefulWidget {
  const CheckEmailScreen({super.key, this.email});

  final String? email;

  @override
  ConsumerState<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends ConsumerState<CheckEmailScreen> {
  final _token = TextEditingController();
  bool _busy = false;
  String? _error;

  // resend cooldown per the mockup: "Надіслати ще раз · 0:42"
  static const _cooldown = 60;
  int _secondsLeft = _cooldown;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    _tick?.cancel();
    setState(() => _secondsLeft = _cooldown);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        _tick?.cancel();
      }
      setState(() => _secondsLeft = (_secondsLeft - 1).clamp(0, _cooldown));
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _resend() async {
    final email = widget.email;
    if (email == null) return;
    try {
      await ref.read(authControllerProvider.notifier).requestMagicLink(email);
      _startCooldown();
    } catch (_) {
      setState(() => _error = 'Не вдалось надіслати ще раз. Спробуй пізніше.');
    }
  }

  /// Accepts either a bare token or the whole pasted link (?token=...).
  Future<void> _verify() async {
    var token = _token.text.trim();
    final fromUrl = Uri.tryParse(token)?.queryParameters['token'];
    if (fromUrl != null && fromUrl.isNotEmpty) token = fromUrl;
    if (token.length < 16) {
      setState(() => _error = 'Встав лінк із листа або сам токен');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).verify(token);
      // signed-in state flips the router redirect to /home automatically
    } catch (_) {
      setState(() {
        _busy = false;
        _error = 'Лінк невалідний або протермінований (діє 15 хв)';
      });
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
              CircleAvatar(
                radius: 36,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(Icons.mark_email_unread_outlined, size: 36, color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(height: 20),
              Text('Перевір пошту', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  text: 'Надіслали посилання для входу на\n',
                  children: [
                    TextSpan(text: widget.email ?? 'твою пошту', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const TextSpan(text: '. Лінк діє 15 хвилин.'),
                  ],
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: _secondsLeft > 0 ? null : _resend,
                child: Text(
                  _secondsLeft > 0
                      ? 'Надіслати ще раз · 0:${_secondsLeft.toString().padLeft(2, '0')}'
                      : 'Надіслати ще раз',
                ),
              ),
              TextButton(
                onPressed: () => context.go('/login'),
                child: Text('Не той email? Змінити', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              ),
              const Spacer(),
              // Fallback while universal links wait for the subflow.app domain (and always
              // handy in dev): paste the link/token manually.
              Text(
                kDebugMode ? 'Dev: встав лінк/токен з LogMailer' : 'Або встав лінк із листа вручну:',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _token,
                autocorrect: false,
                decoration: InputDecoration(hintText: 'https://subflow.app/auth?token=…', errorText: _error),
                onSubmitted: (_) => _verify(),
              ),
              const SizedBox(height: 16),
              PrimaryButton(label: 'Увійти', busy: _busy, onPressed: _verify),
            ],
          ),
        ),
      ),
    );
  }
}
