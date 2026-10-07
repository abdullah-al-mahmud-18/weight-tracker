import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/bmi.dart';

/// Feet + inches form. Calls [onSave] with total inches.
class HeightForm extends StatefulWidget {
  const HeightForm({
    super.key,
    this.initialTotalInches,
    required this.onSave,
    this.onCancel,
  });

  final int? initialTotalInches;
  final Future<void> Function(int totalInches) onSave;
  final VoidCallback? onCancel;

  @override
  State<HeightForm> createState() => _HeightFormState();
}

class _HeightFormState extends State<HeightForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _feet;
  late final TextEditingController _inches;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTotalInches;
    final parts = initial == null ? null : feetAndInches(initial);
    _feet = TextEditingController(text: parts?.feet.toString() ?? '');
    _inches = TextEditingController(text: parts?.inches.toString() ?? '');
  }

  @override
  void dispose() {
    _feet.dispose();
    _inches.dispose();
    super.dispose();
  }

  static String? Function(String?) _rangeValidator(int min, int max) =>
      (value) {
        final n = int.tryParse(value?.trim() ?? '');
        if (n == null) return 'Required';
        if (n < min || n > max) return '$min–$max';
        return null;
      };

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        totalInchesFrom(int.parse(_feet.text), int.parse(_inches.text)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController c, String label, String suffix,
          String? Function(String?) validator, TextInputAction action) =>
      TextFormField(
        controller: c,
        keyboardType: TextInputType.number,
        textInputAction: action,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        decoration: InputDecoration(labelText: label, suffixText: suffix),
        validator: validator,
        onFieldSubmitted: action == TextInputAction.done ? (_) => _submit() : null,
      );

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field(
                  _feet,
                  'Feet',
                  'ft',
                  _rangeValidator(minHeightFeet, maxHeightFeet),
                  TextInputAction.next,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  _inches,
                  'Inches',
                  'in',
                  _rangeValidator(0, 11),
                  TextInputAction.done,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.onCancel != null) ...[
                TextButton(
                  onPressed: _saving ? null : widget.onCancel,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
              ],
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: const Text('Save height'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
