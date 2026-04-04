class AnalyticsPnl {
  final DateTime date;
  final double dailyPnl;

  AnalyticsPnl({
    required this.date,
    required this.dailyPnl,
  });

  factory AnalyticsPnl.fromJson(Map<String, dynamic> json) {
    return AnalyticsPnl(
      date: DateTime.parse(json['date'].toString()),
      dailyPnl: double.parse(json['daily_pnl'].toString()),
    );
  }
}
