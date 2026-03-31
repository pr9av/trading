import 'package:hive/hive.dart';

part 'watchlist_item.g.dart';

@HiveType(typeId: 3)
class WatchlistItem extends HiveObject {
  @HiveField(0)
  String symbol;

  @HiveField(1)
  String exchange;

  @HiveField(2)
  DateTime addedDate;

  WatchlistItem({
    required this.symbol,
    required this.exchange,
    required this.addedDate,
  });
}
