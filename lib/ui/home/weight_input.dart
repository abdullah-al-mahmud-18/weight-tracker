import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../domain/weight_entry.dart';
import '../../providers/providers.dart';

/// Text field + Add button for logging a weight.
class WeightInput extends ConsumerStatefulWidget {
  const WeightInput({super.key});

  @override
  ConsumerState<WeightInput> createState() => _WeightInputState();
}

class _WeightInputState extends ConsumerState<WeightInput> {
  final _controller = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      // Rebuild for the Add button state; clear stale errors while typing.
      setState(() => _error = null);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final result = parseWeightInput(_controller.text);
    if (!result.isValid) {
      setState(() => _error = result.error);
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(entryActionsProvider).add(result.value!);
      _controller.clear();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Saved ${formatWeight(result.value!)}'),
            duration: const Duration(seconds: 2),
          ),
        );
    } catch (_) {
      setState(() => _error = 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _controller.text.trim().isNotEmpty && !_saving;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              labelText: 'Weight',
              suffixText: 'kg',
              errorText: _error,
            ),
            onSubmitted: (_) {
              if (canSubmit) _submit();
            },
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: canSubmit ? _submit : null,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ),
      ],
    );
  }
}
