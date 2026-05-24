import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_error_widget.dart';
import 'app_loading.dart';

/// Renderiza un [AsyncValue] manejando loading, error y data.
class AppAsyncView<T> extends StatelessWidget {
  const AppAsyncView({
    required this.value,
    required this.dataBuilder,
    this.loadingMessage,
    this.onRetry,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) dataBuilder;
  final String? loadingMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: dataBuilder,
      loading: () => AppLoading(message: loadingMessage),
      error: (err, _) => AppErrorWidget(
        message: err.toString(),
        onRetry: onRetry,
      ),
    );
  }
}
