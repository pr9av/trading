import '../services/backend_service.dart';
import '../models/api/analytics_pnl.dart';
import '../models/api/analytics_behavior.dart';
import '../models/api/analytics_distribution.dart';

class AnalyticsRepository {
  final BackendService _backendService;

  AnalyticsRepository(this._backendService);

  Future<List<AnalyticsPnl>> fetchDailyPnl(String symbol) {
    return _backendService.getDailyPnl(symbol);
  }

  Future<AnalyticsBehavior?> fetchBehavior() {
    return _backendService.getBehavior();
  }

  Future<List<AnalyticsDistribution>> fetchDistribution({String? sector}) {
    return _backendService.getDistribution(sector: sector);
  }
}
