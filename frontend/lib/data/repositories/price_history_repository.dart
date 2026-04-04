import '../services/backend_service.dart';
import '../models/api/candle.dart';

class PriceHistoryRepository {
  final BackendService _backendService;
  
  PriceHistoryRepository(this._backendService);

  Future<List<Candle>> fetchCandles(String symbol, String range) {
    DateTime now = DateTime.now();
    DateTime from;
    String interval = '1min';

    switch (range) {
      case '1D':
        from = now.subtract(const Duration(days: 1));
        interval = '1min';
        break;
      case '5D':
        from = now.subtract(const Duration(days: 5));
        interval = '5min';
        break;
      case '1M':
        from = now.subtract(const Duration(days: 30));
        interval = '30min';
        break;
      case '6M':
        from = now.subtract(const Duration(days: 180));
        interval = '60min';
        break;
      case 'YTD':
        from = DateTime(now.year, 1, 1);
        interval = '1day';
        break;
      default:
        from = now.subtract(const Duration(days: 1));
        interval = '1min';
    }

    return _backendService.getCandles(symbol, interval: interval, from: from, to: now);
  }

  Future<List<Candle>> fetchCandlesForRange(String symbol, DateTime from, DateTime to) {
    // Auto-pick interval based on duration
    final durationDays = to.difference(from).inDays;
    String interval;
    if (durationDays <= 3) {
      interval = '1min';
    } else if (durationDays <= 10) {
      interval = '5min';
    } else if (durationDays <= 60) {
      interval = '30min';
    } else if (durationDays <= 365) {
      interval = '60min';
    } else {
      interval = '1day';
    }
    return _backendService.getCandles(symbol, interval: interval, from: from, to: to);
  }
}
