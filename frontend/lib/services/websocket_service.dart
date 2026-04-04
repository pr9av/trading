import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class TickData {
  final String symbol;
  final double ltp;
  final double? open;
  final double? high;
  final double? low;
  final double? close;
  final int? volume;
  final double? change;
  final double? changePercent;
  final String? timestamp;

  TickData({
    required this.symbol, 
    required this.ltp, 
    this.open,
    this.high,
    this.low,
    this.close,
    this.volume,
    this.change, 
    this.changePercent,
    this.timestamp,
  });

  factory TickData.fromJson(Map<String, dynamic> json) {
    return TickData(
      symbol: json['symbol'] ?? '',
      ltp: (json['ltp'] as num?)?.toDouble() ?? 0.0,
      open: (json['open'] as num?)?.toDouble(),
      high: (json['high'] as num?)?.toDouble(),
      low: (json['low'] as num?)?.toDouble(),
      close: (json['close'] as num?)?.toDouble(),
      volume: json['volume'] as int?,
      change: (json['change'] as num?)?.toDouble(),
      changePercent: (json['change_percent'] as num?)?.toDouble(),
      timestamp: json['timestamp'] as String?,
    );
  }

  TickData withChange(double openPrice) {
    if (openPrice <= 0) return this;
    final ch = ltp - openPrice;
    final chPct = (ch / openPrice) * 100;
    return TickData(
      symbol: symbol, 
      ltp: ltp, 
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
      change: ch, 
      changePercent: chPct,
      timestamp: timestamp,
    );
  }
}

/// Market status received from the backend WebSocket
class MarketStatus {
  final String mode; // 'LIVE', 'CLOSED', 'PRE_MARKET'
  final bool isOpen;
  final String message;
  final String? nextOpen;
  final String? lastUpdated;

  MarketStatus({
    required this.mode,
    required this.isOpen,
    required this.message,
    this.nextOpen,
    this.lastUpdated,
  });

  factory MarketStatus.fromJson(Map<String, dynamic> json) {
    return MarketStatus(
      mode: json['mode'] ?? 'CLOSED',
      isOpen: json['is_open'] ?? false,
      message: json['message'] ?? 'Market status unknown.',
      nextOpen: json['next_open'] as String?,
      lastUpdated: json['last_updated'] as String?,
    );
  }

  static MarketStatus get unknown => MarketStatus(
    mode: 'UNKNOWN',
    isOpen: false,
    message: 'Connecting...',
  );
}

class WebSocketService with ChangeNotifier {
  WebSocketChannel? _marketChannel;
  final Map<String, TickData> _ticks = {};
  final Map<String, double> _openPrices = {}; // first LTP seen per symbol
  bool _isConnected = false;
  MarketStatus _marketStatus = MarketStatus.unknown;
  bool _shouldReconnect = true;

  Map<String, TickData> get ticks => _ticks;
  bool get isConnected => _isConnected;
  MarketStatus get marketStatus => _marketStatus;

  void connect() {
    if (_isConnected) return;
    _shouldReconnect = true;

    try {
      _marketChannel = WebSocketChannel.connect(
        Uri.parse('ws://localhost:8000/ws/market'),
      );

      _marketChannel!.stream.listen(
        (message) {
          _isConnected = true;
          final data = jsonDecode(message);
          final type = data['type'] as String?;

          switch (type) {
            case 'MARKET_STATUS':
              _marketStatus = MarketStatus.fromJson(data);
              notifyListeners();
              break;

            case 'MARKET_CLOSED':
              _marketStatus = MarketStatus(
                mode: 'CLOSED',
                isOpen: false,
                message: data['message'] ?? 'Market closed.',
                nextOpen: data['next_open'] as String?,
              );
              // Don't keep reconnecting aggressively when market is closed
              _shouldReconnect = false;
              notifyListeners();
              break;

            case 'TICK':
            default:
              // Parse as tick data (backward compatible with old format)
              if (data.containsKey('symbol') && data.containsKey('ltp')) {
                final tick = TickData.fromJson(data);
                _openPrices.putIfAbsent(tick.symbol, () => tick.ltp);
                _ticks[tick.symbol] = tick.withChange(_openPrices[tick.symbol]!);
                notifyListeners();
              }
              break;
          }
        },
        onDone: () {
          _isConnected = false;
          notifyListeners();
          if (_shouldReconnect) _reconnect();
        },
        onError: (error) {
          _isConnected = false;
          notifyListeners();
          if (_shouldReconnect) _reconnect();
        },
      );
    } catch (e) {
      debugPrint('WebSocket connection error: $e');
      if (_shouldReconnect) _reconnect();
    }
  }

  void _reconnect() {
    // Longer delay when market is closed
    final delay = _marketStatus.isOpen
        ? const Duration(seconds: 5)
        : const Duration(seconds: 30);
    Future.delayed(delay, () => connect());
  }

  void disconnect() {
    _shouldReconnect = false;
    _marketChannel?.sink.close();
    _isConnected = false;
    notifyListeners();
  }
}
