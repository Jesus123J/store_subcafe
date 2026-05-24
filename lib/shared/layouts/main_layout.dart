import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sidebar.dart';

class MainLayout extends ConsumerWidget {
  const MainLayout({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Row(
        children: [
          const Sidebar(),
          Expanded(child: child),
        ],
      ),
    );
  }
}
