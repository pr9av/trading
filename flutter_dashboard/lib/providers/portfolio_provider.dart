import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/portfolio_repository.dart';

final portfolioRepositoryProvider = Provider<PortfolioRepository>((ref) {
  return PortfolioRepository();
});

/// Provider for the user's local watchlist symbols.
final watchlistProvider = StateProvider<List<String>>((ref) {
  final repo = ref.watch(portfolioRepositoryProvider);
  try {
    return repo.getWatchlist().map((e) => e.symbol).toList();
  } catch (e) {
    return [];
  }
});

/// Notifier to refresh local analytics state (Watchlist).
class PortfolioNotifier extends StateNotifier<void> {
  final Ref ref;
  PortfolioNotifier(this.ref) : super(null);

  void refresh() {
    final repo = ref.read(portfolioRepositoryProvider);
    ref.read(watchlistProvider.notifier).state =
        repo.getWatchlist().map((e) => e.symbol).toList();
  }
}

final portfolioNotifierProvider =
    StateNotifierProvider<PortfolioNotifier, void>((ref) {
  return PortfolioNotifier(ref);
});
