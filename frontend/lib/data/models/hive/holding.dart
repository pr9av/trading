import 'package:hive/hive.dart';

part 'holding.g.dart';

@HiveType(typeId: 1)
class Holding extends HiveObject {
  @HiveField(0)
  String symbol;

  @HiveField(1)
  String tradingSymbol;

  @HiveField(2)
  String exchange;

  @HiveField(3)
  int quantity;

  @HiveField(4)
  double averagePrice;

  @HiveField(5)
  DateTime lastTransactionDate;

  Holding({
    required this.symbol,
    required this.tradingSymbol,
    required this.exchange,
    required this.quantity,
    required this.averagePrice,
    required this.lastTransactionDate,
  });
}
