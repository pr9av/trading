import 'package:hive/hive.dart';

part 'transaction.g.dart';

@HiveType(typeId: 2)
class Transaction extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String symbol;

  @HiveField(2)
  String transactionType; // BUY or SELL

  @HiveField(3)
  int quantity;

  @HiveField(4)
  double price;

  @HiveField(5)
  double totalAmount;

  @HiveField(6)
  double brokerage;

  @HiveField(7)
  DateTime timestamp;

  @HiveField(8)
  String orderType;

  Transaction({
    required this.id,
    required this.symbol,
    required this.transactionType,
    required this.quantity,
    required this.price,
    required this.totalAmount,
    required this.brokerage,
    required this.timestamp,
    required this.orderType,
  });
}
