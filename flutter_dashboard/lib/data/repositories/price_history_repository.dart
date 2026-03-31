import '../services/backend_service.dart';
import '../models/api/candle.dart';

class PriceHistoryRepository {
  final BackendService _backendService;
  
  PriceHistoryRepository(this._backendService);

  Future<List<Candle>> fetchCandles(String symbol, String interval) {
    return _backendService.getCandles(symbol, interval: interval);
  }
}
