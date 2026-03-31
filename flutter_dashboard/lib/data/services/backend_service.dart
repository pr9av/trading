import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';
import '../models/api/candle.dart';
import '../models/api/analytics_pnl.dart';
import '../models/api/analytics_behavior.dart';
import '../models/api/analytics_distribution.dart';

class BackendService {
  final String _baseUrl = ApiConfig.baseUrl;

  /// Reads the stored JWT from SharedPreferences and returns auth headers.
  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Authenticated GET helper — every protected endpoint uses this.
  Future<http.Response> _get(Uri uri) async {
    final headers = await _authHeaders();
    return http.get(uri, headers: headers);
  }

  /// Helper to unwrap { data: ... } response format from V1 API
  dynamic _unwrap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded.containsKey('data')) {
      return decoded['data'];
    }
    return decoded;
  }

  Future<List<Candle>> getCandles(String symbol, {
    String interval = '1min',
    DateTime? from,
    DateTime? to,
  }) async {
    final queryParams = <String, String>{'interval': interval};
    if (from != null) queryParams['from'] = from.toIso8601String();
    if (to != null) queryParams['to'] = to.toIso8601String();

    final uri = Uri.parse('$_baseUrl/candles/$symbol').replace(queryParameters: queryParams);
    try {
      final response = await _get(uri);
      if (response.statusCode == 200) {
        final List data = _unwrap(response.body);
        return data.map((e) => Candle.fromJson(e)).toList();
      } else {
        throw Exception('Status Code ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Error fetching candles: $e');
      throw Exception('Candle fetch failed: $e');
    }
  }

  Future<List<AnalyticsPnl>> getDailyPnl(String symbol) async {
    final uri = Uri.parse('$_baseUrl/analytics/pnl').replace(queryParameters: {'symbol': symbol});
    try {
      final response = await _get(uri);
      if (response.statusCode == 200) {
        final List data = _unwrap(response.body);
        return data.map((e) => AnalyticsPnl.fromJson(e)).toList();
      } else {
        throw Exception('Status Code ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Error fetching PNL analytics: $e');
      throw Exception('PNL fetch failed: $e');
    }
  }

  Future<AnalyticsBehavior?> getBehavior() async {
    final uri = Uri.parse('$_baseUrl/analytics/behavior');
    try {
      final response = await _get(uri);
      if (response.statusCode == 200) {
        final data = _unwrap(response.body);
        return AnalyticsBehavior.fromJson(data);
      } else {
        throw Exception('Status Code ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Error fetching behavior: $e');
      throw Exception('Behavior fetch failed: $e');
    }
  }

  Future<List<AnalyticsDistribution>> getDistribution({String? sector}) async {
    final params = <String, String>{};
    if (sector != null && sector.isNotEmpty) params['sector'] = sector;
    final uri = Uri.parse('$_baseUrl/analytics/distribution').replace(queryParameters: params.isEmpty ? null : params);
    try {
      final response = await _get(uri);
      if (response.statusCode == 200) {
        final List data = _unwrap(response.body);
        return data.map((e) => AnalyticsDistribution.fromJson(e)).toList();
      } else {
        throw Exception('Status Code ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Error fetching distribution: $e');
      throw Exception('Distribution fetch failed: $e');
    }
  }

  Future<List<AnalyticsDistribution>> getVolume({String? sector}) async {
    final params = <String, String>{};
    if (sector != null && sector.isNotEmpty) params['sector'] = sector;
    final uri = Uri.parse('$_baseUrl/analytics/volume').replace(queryParameters: params.isEmpty ? null : params);
    try {
      final response = await _get(uri);
      if (response.statusCode == 200) {
        final List data = _unwrap(response.body);
        return data.map((e) => AnalyticsDistribution(
          symbol: e['symbol'].toString(),
          volume: double.parse(e['total_volume'].toString()),
        )).toList();
      } else {
        throw Exception('Status Code ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Error fetching volume: $e');
      throw Exception('Volume fetch failed: $e');
    }
  }

  /// Fetch compare metrics for multiple symbols at once.
  /// /compare/pnl  → { data: { "TCS": [{daily_pnl, date}, ...], ... } }  (Map)
  /// /compare/volume → { data: [{symbol, total_volume}, ...] }             (List)
  Future<List<Map<String, dynamic>>> getCompare(List<String> symbols) async {
    final symbolsParam = symbols.join(',');
    final pnlUri = Uri.parse('$_baseUrl/compare/pnl').replace(queryParameters: {'symbols': symbolsParam});
    final volUri = Uri.parse('$_baseUrl/compare/volume').replace(queryParameters: {'symbols': symbolsParam});
    try {
      final headers = await _authHeaders();
      final results = await Future.wait([
        http.get(pnlUri, headers: headers),
        http.get(volUri, headers: headers),
      ]);

      // PnL: { data: { "SYMBOL": [{daily_pnl, date}, ...] } }
      final pnlMap = _unwrap(results[0].body) as Map<String, dynamic>;

      // Volume: { data: [{symbol, total_volume}] }
      final volList = _unwrap(results[1].body) as List;
      final volMap = <String, double>{};
      for (final v in volList) {
        volMap[v['symbol'].toString()] =
            double.tryParse(v['total_volume']?.toString() ?? '0') ?? 0.0;
      }

      // Build one entry per requested symbol
      return symbols.map((sym) {
        final rows = pnlMap[sym] as List? ?? [];
        final latestPnl = rows.isNotEmpty
            ? double.tryParse(rows.first['daily_pnl']?.toString() ?? '0') ?? 0.0
            : 0.0;
        return {
          'symbol': sym,
          'pnl': latestPnl,
          'volume': volMap[sym] ?? 0.0,
        };
      }).toList();
    } catch (e) {
      print('Error fetching compare data: $e');
      throw Exception('Compare fetch failed: $e');
    }
  }
}
