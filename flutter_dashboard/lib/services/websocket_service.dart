import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class TickData {
  final String symbol;
  final double ltp;
  final double? change;
  final double? changePercent;

  TickData({required this.symbol, required this.ltp, this.change, this.changePercent});

  factory TickData.fromJson(Map<String, dynamic> json) {
    return TickData(
      symbol: json['symbol'] ?? '',
      ltp: (json['ltp'] as num?)?.toDouble() ?? 0.0,
      change: (json['change'] as num?)?.toDouble(),
      changePercent: (json['change_percent'] as num?)?.toDouble(),
    );
  }

  TickData withChange(double openPrice) {
    if (openPrice <= 0) return this;
    final ch = ltp - openPrice;
    final chPct = (ch / openPrice) * 100;
    return TickData(symbol: symbol, ltp: ltp, change: ch, changePercent: chPct);
  }
}

class WebSocketService with ChangeNotifier {
  WebSocketChannel? _marketChannel;
  final Map<String, TickData> _ticks = {};
  final Map<String, double> _openPrices = {}; // first LTP seen per symbol
  bool _isConnected = false;

  Map<String, TickData> get ticks => _ticks;
  bool get isConnected => _isConnected;

  void connect() {
    if (_isConnected) return;

    try {
      _marketChannel = WebSocketChannel.connect(
        Uri.parse('ws://localhost:8000/ws/market'),
      );

      _marketChannel!.stream.listen(
        (message) {
          _isConnected = true;
          final data = jsonDecode(message);
          final tick = TickData.fromJson(data);
          // Track opening price per symbol for change % calculation
          _openPrices.putIfAbsent(tick.symbol, () => tick.ltp);
          _ticks[tick.symbol] = tick.withChange(_openPrices[tick.symbol]!);
          notifyListeners();
        },
        onDone: () {
          _isConnected = false;
          notifyListeners();
          _reconnect();
        },
        onError: (error) {
          _isConnected = false;
          notifyListeners();
          _reconnect();
        },
      );
    } catch (e) {
      debugPrint('WebSocket connection error: $e');
      _reconnect();
    }
  }

  void _reconnect() {
    Future.delayed(const Duration(seconds: 5), () => connect());
  }

  void disconnect() {
    _marketChannel?.sink.close();
    _isConnected = false;
    notifyListeners();
  }
}
