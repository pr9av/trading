import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/api/analytics_pnl.dart';
import '../data/models/api/analytics_behavior.dart';
import '../data/models/api/analytics_distribution.dart';
import '../data/repositories/analytics_repository.dart';
import 'candle_provider.dart';
import 'portfolio_provider.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  final service = ref.watch(backendServiceProvider);
  return AnalyticsRepository(service);
});

// ── Live Backend Providers (Public API) ──────────────────────

final dailyPnlProvider = FutureProvider.autoDispose.family<List<AnalyticsPnl>, String>((ref, symbol) {
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.fetchDailyPnl(symbol);
});

final backendBehaviorProvider = FutureProvider.autoDispose<AnalyticsBehavior?>((ref) {
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.fetchBehavior();
});

final backendDistributionProvider = FutureProvider.autoDispose.family<List<AnalyticsDistribution>, String?>((ref, sector) {
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.fetchDistribution(sector: sector);
});

final backendVolumeProvider = FutureProvider.autoDispose.family<List<AnalyticsDistribution>, String?>((ref, sector) {
  final service = ref.watch(backendServiceProvider);
  return service.getVolume(sector: sector);
});

/// Compare provider — returns merged PnL + volume for a list of symbols
final compareProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, List<String>>((ref, symbols) {
  final service = ref.watch(backendServiceProvider);
  return service.getCompare(symbols);
});

final compareMetricsProvider = FutureProvider.autoDispose.family<Map<String, Map<String, dynamic>>, List<String>>((ref, symbols) {
  final service = ref.watch(backendServiceProvider);
  return service.getCompareMetrics(symbols);
});

/// Derives active symbols from unfiltered volume (no sector)
final activeSymbolsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final volumeData = await ref.watch(backendVolumeProvider(null).future);
  return volumeData.map((e) => e.symbol).toList();
});

// Note: Local Hive-based fallbacks (formerly for individual portfolio tracking) 
// have been removed to focus entirely on objective market-wide analytics.
