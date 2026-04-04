class AnalyticsDistribution {
  final String symbol;
  final double volume;

  AnalyticsDistribution({
    required this.symbol,
    required this.volume,
  });

  factory AnalyticsDistribution.fromJson(Map<String, dynamic> json) {
    return AnalyticsDistribution(
      symbol: json['symbol'].toString(),
      volume: double.parse(json['volume'].toString()),
    );
  }
}
