import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../widgets/widgets.dart';
import '../onboarding_controller.dart';

/// Step 3 — the token. Step-by-step, open api.monobank.ua, paste, validate with a human error.
class ConnectPage extends ConsumerStatefulWidget {
  const ConnectPage({super.key, required this.onConnected});
  final Future<void> Function() onConnected;

  @override
  ConsumerState<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends ConsumerState<ConnectPage> {
  final _token = TextEditingController();

  Future<void> _openMono() async {
    final uri = Uri.parse('https://api.monobank.ua/');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _connect() async {
    final ok = await ref.read(onboardingControllerProvider.notifier).connect(_token.text);
    if (ok && mounted) await widget.onConnected();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(onboardingControllerProvider);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Підключи monobank', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            const _Step(n: 1, text: 'Відкрий api.monobank.ua і увійди'),
            const _Step(n: 2, text: 'Погодься з умовами й натисни «Створити токен»'),
            const _Step(n: 3, text: 'Скопіюй токен і встав його сюди'),
            const SizedBox(height: 16),
            OutlinedButton.icon(onPressed: _openMono, icon: const Icon(Icons.open_in_new), label: const Text('Відкрити api.monobank.ua')),
            const SizedBox(height: 20),
            TextField(
              controller: _token,
              autocorrect: false,
              enableSuggestions: false,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Токен monobank', errorText: state.error),
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: 'Підключити', busy: state.connecting, onPressed: _connect),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});
  final int n;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 14, backgroundColor: theme.colorScheme.primaryContainer, child: Text('$n')),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
