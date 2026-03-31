import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'data/models/hive/watchlist_item.dart';
import 'data/repositories/portfolio_repository.dart';
import 'providers/portfolio_provider.dart';

import 'screens/main_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive for local analytics data (Watchlist)
  await Hive.initFlutter();
  Hive.registerAdapter(WatchlistItemAdapter());

  final repo = PortfolioRepository();
  await repo.init();

  runApp(
    ProviderScope(
      overrides: [
        portfolioRepositoryProvider.overrideWithValue(repo),
      ],
      child: const BlauplugTradingApp(),
    ),
  );
}

class BlauplugTradingApp extends ConsumerWidget {
  const BlauplugTradingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return MaterialApp(
      title: 'Blauplug V2',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00D1FF),
          brightness: Brightness.dark,
          primary: const Color(0xFF00D1FF),
          secondary: const Color(0xFF00FFA3),
          surface: const Color(0xFF121212),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      ),
      home: auth.isAuthenticated ? const MainScreen() : const LoginScreen(),
    );
  }
}
