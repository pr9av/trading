class AnalyticsBehavior {
  final int totalTrades;
  final double totalVolume;
  final double totalFees;
  final int buys;
  final int sells;

  AnalyticsBehavior({
    required this.totalTrades,
    required this.totalVolume,
    required this.totalFees,
    required this.buys,
    required this.sells,
  });

  factory AnalyticsBehavior.fromJson(Map<String, dynamic> json) {
    return AnalyticsBehavior(
      totalTrades: int.parse(json['total_trades'].toString()),
      totalVolume: double.parse(json['total_volume'].toString()),
      totalFees: double.parse(json['total_fees'].toString()),
      buys: int.parse(json['buys'].toString()),
      sells: int.parse(json['sells'].toString()),
    );
  }
}
