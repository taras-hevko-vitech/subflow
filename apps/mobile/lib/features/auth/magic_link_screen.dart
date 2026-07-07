import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../widgets/widgets.dart';

/// Landing route for the magic link (https://subflow.app/auth?token=... or
/// subflow://auth?token=...). Verifies immediately and hands off to the router redirect.
class MagicLinkScreen extends ConsumerStatefulWidget {
  const MagicLinkScreen({super.key, this.token});

  final String? token;

  @override
  ConsumerState<MagicLinkScreen> createState() => _MagicLinkScreenState();
}

class _MagicLinkScreenState extends ConsumerState<MagicLinkScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    final token = widget.token;
    if (token == null || token.length < 16) {
      setState(() => _error = 'У лінку немає токена');
      return;
    }
    try {
      await ref.read(authControllerProvider.notifier).verify(token);
      if (mounted) context.go('/home');
    } catch (_) {
      setState(() => _error = 'Лінк невалідний або протермінований (діє 15 хв)');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _error == null
          ? const LoadingView()
          : ErrorView(message: _error!, onRetry: () => context.go('/login')),
    );
  }
}
