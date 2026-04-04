import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// NSE trading hours: Monday–Friday, 09:15 – 15:30 IST (UTC+5:30)
/// Client-side fallback check (used before server response arrives).
bool checkMarketOpen() {
  final now = DateTime.now().toLocal();
  final weekday = now.weekday; // 1=Mon, 7=Sun
  if (weekday == DateTime.saturday || weekday == DateTime.sunday) return false;

  final openTime = DateTime(now.year, now.month, now.day, 9, 15);
  final closeTime = DateTime(now.year, now.month, now.day, 15, 30);
  return now.isAfter(openTime) && now.isBefore(closeTime);
}

/// Client-side fallback provider
final isMarketOpenProvider = Provider<bool>((ref) => checkMarketOpen());

/// Server-authoritative market status
class ServerMarketStatus {
  final String mode;     // 'LIVE', 'CLOSED', 'PRE_MARKET'
  final bool isOpen;
  final String message;
  final String? nextOpen;
  final String? lastUpdated;
  final String? broker;

  ServerMarketStatus({
    required this.mode,
    required this.isOpen,
    required this.message,
    this.nextOpen,
    this.lastUpdated,
    this.broker,
  });

  factory ServerMarketStatus.fromJson(Map<String, dynamic> json) {
    return ServerMarketStatus(
      mode: json['mode'] ?? 'CLOSED',
      isOpen: json['is_open'] ?? false,
      message: json['message'] ?? 'Unknown',
      nextOpen: json['next_open'] as String?,
      lastUpdated: json['last_updated'] as String?,
      broker: json['broker'] as String?,
    );
  }

  /// Fallback instance before server responds
  static ServerMarketStatus get fallback => ServerMarketStatus(
    mode: checkMarketOpen() ? 'LIVE' : 'CLOSED',
    isOpen: checkMarketOpen(),
    message: checkMarketOpen() ? 'Market is open.' : 'Market closed.',
  );
}

/// Fetches market status from backend GET /v1/market/status
final marketStatusProvider = FutureProvider.autoDispose<ServerMarketStatus>((ref) async {
  try {
    final uri = Uri.parse('${ApiConfig.baseUrl}/market/status');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return ServerMarketStatus.fromJson(jsonDecode(response.body));
    }
    return ServerMarketStatus.fallback;
  } catch (e) {
    return ServerMarketStatus.fallback;
  }
});
