import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      appBar: AppBar(title: const Text('Перевір пошту')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Text(
                  'Ми надіслали лінк для входу на\n${widget.email ?? 'твою пошту'}.\n\n'
                  'Відкрий лист на цьому пристрої й тапни лінк — застосунок відкриється сам.',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              const SizedBox(height: 24),
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
