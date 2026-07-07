import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/subflow_api.dart';
import '../../widgets/widgets.dart';

/// One-screen feedback (subF-17): "detection got it wrong" → detection_feedback.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _text = TextEditingController();
  bool _busy = false;

  Future<void> _submit() async {
    final text = _text.text.trim();
    if (text.length < 3) return;
    setState(() => _busy = true);
    try {
      await ref.read(subflowApiProvider).submitFeedback(text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Дякуємо! Врахуємо.')));
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не вдалось надіслати. Спробуй ще раз.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Детекція помилилась?')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Що не так? Пропустили підписку, показали зайве, переплутали суму — напиши, і ми підкрутимо детекцію.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _text,
                maxLines: 6,
                maxLength: 2000,
                decoration: const InputDecoration(hintText: 'Твій відгук…'),
              ),
              const SizedBox(height: 8),
              PrimaryButton(label: 'Надіслати', busy: _busy, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
