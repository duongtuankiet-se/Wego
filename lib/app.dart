import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'providers/trip_offer_provider.dart';
import 'providers/trip_pools_provider.dart';
import 'router.dart';

class WeGoApp extends ConsumerWidget {
  const WeGoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Phase 5N: keep the pool auto-cancel sweeper alive for the
    // lifetime of the app so abandoned pools get cleaned up while the
    // user has the app open. The provider is keepAlive: true and self-
    // disposes the underlying Timer.
    ref.watch(poolAutoCancelJobProvider);
    // Phase 5R: search loop — offers pending free-point trips to next
    // eligible driver every 10s and flips trips past their
    // search_timeout_at to noDriverFound. Same keepAlive Timer pattern.
    ref.watch(tripSearchJobProvider);
    return MaterialApp.router(
      title: 'WeGo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      locale: const Locale('vi', 'VN'),
      supportedLocales: const [Locale('vi', 'VN'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
