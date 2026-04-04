class Candle {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final int volume;

  Candle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  factory Candle.fromJson(Map<String, dynamic> json) {
    return Candle(
      time: DateTime.parse(json['time'].toString()),
      open: double.parse(json['open'].toString()),
      high: double.parse(json['high'].toString()),
      low: double.parse(json['low'].toString()),
      close: double.parse(json['close'].toString()),
      volume: int.tryParse(json['volume'].toString()) ?? 0,
    );
  }
}
