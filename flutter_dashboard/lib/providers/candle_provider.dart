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

// A FutureProvider family to fetch candles by symbol and interval
final candleProvider = FutureProvider.autoDispose.family<List<Candle>, ({String symbol, String interval})>((ref, args) {
  final repo = ref.watch(priceHistoryRepositoryProvider);
  return repo.fetchCandles(args.symbol, args.interval);
});
