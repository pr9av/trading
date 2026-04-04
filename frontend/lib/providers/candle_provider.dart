import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/api/candle.dart';
import '../data/repositories/price_history_repository.dart';
import '../data/services/backend_service.dart';

final backendServiceProvider = Provider<BackendService>((ref) {
  return BackendService();
});

final priceHistoryRepositoryProvider = Provider<PriceHistoryRepository>((ref) {
  final service = ref.watch(backendServiceProvider);
  return PriceHistoryRepository(service);
});

// A FutureProvider family to fetch candles by symbol and range (1D, 5D, 1M, etc)
final candleProvider = FutureProvider.autoDispose.family<List<Candle>, ({String symbol, String range})>((ref, args) {
  final repo = ref.watch(priceHistoryRepositoryProvider);
  return repo.fetchCandles(args.symbol, args.range);
});

final candleCustomRangeProvider = FutureProvider.autoDispose.family<List<Candle>, ({String symbol, DateTime from, DateTime to})>((ref, args) {
  final repo = ref.watch(priceHistoryRepositoryProvider);
  return repo.fetchCandlesForRange(args.symbol, args.from, args.to);
});

final marketSnapshotProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(backendServiceProvider);
  return service.getSnapshot();
});

final trendingStocksProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(backendServiceProvider);
  return service.getTrendingStocks();
});

final fundamentalSearchProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, query) {
  final service = ref.watch(backendServiceProvider);
  if (query.isEmpty) return Future.value([]);
  return service.searchFundamentals(query);
});

final aiAnalysisProvider = FutureProvider.autoDispose.family<String, String>((ref, symbol) {
  final service = ref.watch(backendServiceProvider);
  // We pass 0.0 as the price; the backend can fall back to the last known price.
  // The key benefit is that price updates won't re-trigger this provider.
  return service.getAiAnalysis(symbol, 0.0);
});
