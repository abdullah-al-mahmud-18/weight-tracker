import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'empty_state.dart';

/// Renders an [AsyncValue] with consistent loading and error states.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({super.key, required this.value, required this.data});

  final AsyncValue<T> value;
  final Widget Function(T data) data;

  @override
  Widget build(BuildContext context) {
    return value.when(
      // Keep showing the previous data while dependent providers refresh.
      skipLoadingOnReload: true,
      data: data,
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const EmptyState(
        icon: Icons.error_outline,
        message: 'Something went wrong loading your data.',
      ),
    );
  }
}
