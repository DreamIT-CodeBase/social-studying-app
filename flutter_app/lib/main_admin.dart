import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_study_app/core/config/app_flavor.dart';
import 'package:social_study_app/core/routing/router.dart';
import 'package:social_study_app/core/theme/app_theme.dart';

void main() {
  setAppFlavor(AppFlavor.admin);
  runApp(const ProviderScope(child: _AdminApp()));
}

class _AdminApp extends ConsumerWidget {
  const _AdminApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Social Study — Admin',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
