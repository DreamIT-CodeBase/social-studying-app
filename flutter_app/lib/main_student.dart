import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/core/config/app_flavor.dart';
import 'package:social_study_app/core/routing/router.dart';
import 'package:social_study_app/core/theme/app_theme.dart';

void main() {
  setAppFlavor(AppFlavor.student);
  runApp(const ProviderScope(child: _StudentApp()));
}

class _StudentApp extends ConsumerWidget {
  const _StudentApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Social Study',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
