import 'package:hive/hive.dart';

part 'user_portfolio.g.dart';

@HiveType(typeId: 0)
class UserPortfolio extends HiveObject {
  @HiveField(0)
  double virtualBalance;

  @HiveField(1)
  double totalInvested;

  @HiveField(2)
  DateTime createdDate;

  @HiveField(3)
  double initialBalance;

  UserPortfolio({
    required this.virtualBalance,
    required this.totalInvested,
    required this.createdDate,
    required this.initialBalance,
  });
}
