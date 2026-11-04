import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

class QuickpatchApp extends ConsumerWidget {
  const QuickpatchApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'QUICKPATCH',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.claro(),
    darkTheme: AppTheme.oscuro(),
    routerConfig: ref.watch(routerProvider),
  );
}
