import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/models/hive/holding.dart';
import '../data/models/hive/transaction.dart';
import 'portfolio_provider.dart';

class TradingNotifier extends StateNotifier<void> {
  final Ref ref;
  TradingNotifier(this.ref) : super(null);

  Future<bool> executeTrade({
    required String symbol,
    required String transactionType, // 'BUY' or 'SELL'
    required int quantity,
    required double price,
  }) async {
    final repo = ref.read(portfolioRepositoryProvider);
    final portfolio = repo.getPortfolio();
    final holdings = repo.getHoldings();
    
    final totalValue = quantity * price;
    final brokerage = totalValue * 0.001; // 0.1% brokerage
    final totalAmount = transactionType == 'BUY' ? totalValue + brokerage : totalValue - brokerage;

    if (transactionType == 'BUY') {
      if (portfolio.virtualBalance < totalAmount) return false;

      portfolio.virtualBalance -= totalAmount;
      portfolio.totalInvested += totalAmount;

      final existingHolding = holdings.firstWhere(
        (h) => h.symbol == symbol, 
        orElse: () => Holding(symbol: symbol, tradingSymbol: symbol, exchange: 'NSE', quantity: 0, averagePrice: 0.0, lastTransactionDate: DateTime.now())
      );

      final newQuantity = existingHolding.quantity + quantity;
      final newTotalCost = (existingHolding.quantity * existingHolding.averagePrice) + totalAmount;
      existingHolding.averagePrice = newTotalCost / newQuantity;
      existingHolding.quantity = newQuantity;
      existingHolding.lastTransactionDate = DateTime.now();

      await repo.addOrUpdateHolding(existingHolding);
    } else { // SELL
      final existingHolding = holdings.firstWhere(
        (h) => h.symbol == symbol, 
        orElse: () => Holding(symbol: symbol, tradingSymbol: symbol, exchange: 'NSE', quantity: 0, averagePrice: 0.0, lastTransactionDate: DateTime.now())
      );

      if (existingHolding.quantity < quantity) return false;

      portfolio.virtualBalance += totalAmount;
      portfolio.totalInvested -= (existingHolding.averagePrice * quantity);

      existingHolding.quantity -= quantity;
      existingHolding.lastTransactionDate = DateTime.now();

      if (existingHolding.quantity <= 0) {
        await repo.removeHolding(symbol);
      } else {
        await repo.addOrUpdateHolding(existingHolding);
      }
    }

    await repo.updatePortfolio(portfolio);

    final tx = Transaction(
      id: const Uuid().v4(),
      transactionType: transactionType,
      symbol: symbol,
      quantity: quantity,
      price: price,
      totalAmount: totalAmount,
      timestamp: DateTime.now(),
      orderType: 'MARKET',
      brokerage: brokerage,
    );
    await repo.addTransaction(tx);

    ref.read(portfolioNotifierProvider.notifier).refresh();
    return true;
  }
}

final tradingProvider = StateNotifierProvider<TradingNotifier, void>((ref) {
  return TradingNotifier(ref);
});
