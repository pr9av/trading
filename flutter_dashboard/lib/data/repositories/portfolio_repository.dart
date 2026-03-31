import 'package:hive_flutter/hive_flutter.dart';
import '../models/hive/watchlist_item.dart';

/// Repository for local analytics data (formerly portfolio data).
/// Now primarily used for managing the user's Watchlist across sessions.
class PortfolioRepository {
  static const String watchlistBoxName = 'watchlist';

  Future<void> init() async {
    await Hive.openBox<WatchlistItem>(watchlistBoxName);
  }

  List<WatchlistItem> getWatchlist() {
    final box = Hive.box<WatchlistItem>(watchlistBoxName);
    return box.values.toList();
  }

  Future<void> addToWatchlist(WatchlistItem item) async {
    final box = Hive.box<WatchlistItem>(watchlistBoxName);
    await box.put(item.symbol, item);
  }

  Future<void> removeFromWatchlist(String symbol) async {
    final box = Hive.box<WatchlistItem>(watchlistBoxName);
    await box.delete(symbol);
  }

  Future<void> clearAll() async {
    await Hive.box<WatchlistItem>(watchlistBoxName).clear();
  }
}
