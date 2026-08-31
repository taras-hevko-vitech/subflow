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
  static const _reasons = [
    'Це взагалі не підписка',
    'Сума або дата неправильні',
    'Це дублікат іншої підписки',
    'Інше',
  ];

  final _text = TextEditingController();
  String? _reason;
  bool _busy = false;

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) return;
    final comment = _text.text.trim();
    setState(() => _busy = true);
    try {
      await ref.read(subflowApiProvider).submitFeedback(comment.isEmpty ? reason : '$reason: $comment');
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
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Розкажи, що не так — це напряму покращує розпізнавання.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            for (final r in _reasons)
              RadioListTile<String>(
                value: r,
                // ignore: deprecated_member_use
                groupValue: _reason,
                // ignore: deprecated_member_use
                onChanged: (v) => setState(() => _reason = v),
                title: Text(r),
                contentPadding: EdgeInsets.zero,
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _text,
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(hintText: 'Розкажи детальніше (необов\'язково)'),
            ),
            const SizedBox(height: 8),
            PrimaryButton(label: 'Надіслати', busy: _busy, onPressed: _reason == null ? null : _submit),
          ],
        ),
      ),
    );
  }
}
