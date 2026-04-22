import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';

void main() {
  runApp(const ClinicalCuratorApp());
}

class ClinicalCuratorApp extends StatelessWidget {
  const ClinicalCuratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: App());
  }
}
