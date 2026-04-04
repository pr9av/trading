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
      throw Exception('Compare fetch failed: $e');
    }
  }

  Future<Map<String, Map<String, dynamic>>> getCompareMetrics(List<String> symbols) async {
    final symbolsParam = symbols.join(',');
    final uri = Uri.parse('$_baseUrl/compare/metrics').replace(queryParameters: {'symbols': symbolsParam});
    try {
      final response = await _get(uri);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = _unwrap(response.body);
        return data.cast<String, Map<String, dynamic>>();
      }
      throw Exception('Compare metrics failed: ${response.statusCode}');
    } catch (e) {
      throw Exception('Compare metrics service error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getSnapshot() async {
    final uri = Uri.parse('$_baseUrl/ticks/snapshot');
    try {
      final response = await _get(uri);
      if (response.statusCode == 200) {
        final List data = _unwrap(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      throw Exception('Snapshot fetch failed: ${response.statusCode}');
    } catch (e) {
      throw Exception('Snapshot service error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getTrendingStocks() async {
    final uri = Uri.parse('$_baseUrl/analytics/trending');
    try {
      final response = await _get(uri);
      if (response.statusCode == 200) {
        final List data = _unwrap(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      throw Exception('Trending fetch failed: ${response.statusCode}');
    } catch (e) {
      throw Exception('Trending service error: $e');
    }
  }

  Future<String> getAiAnalysis(String symbol, double price) async {
    final uri = Uri.parse('$_baseUrl/ai/analyze');
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({'symbol': symbol, 'price': price}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['analysis'] ?? 'No analysis available.';
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['details'] ?? data['analysis'] ?? data['error'] ?? 'AI Service error: status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('AI Service error: $e');
    }
  }

  Future<String> getAiChat(String message, {List<Map<String, dynamic>>? history}) async {
    final uri = Uri.parse('$_baseUrl/ai/chat');
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({'message': message, 'history': history ?? []}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message'] ?? 'I am having trouble responding right now.';
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['details'] ?? data['message'] ?? data['error'] ?? 'AI Chat failed: status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('AI Chat service error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> searchFundamentals(String query) async {
    final uri = Uri.parse('$_baseUrl/fundamentals/search').replace(queryParameters: {'q': query});
    try {
      final response = await _get(uri);
      if (response.statusCode == 200) {
        final List data = _unwrap(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      throw Exception('Search failed: ${response.statusCode}');
    } catch (e) {
      throw Exception('Search service error: $e');
    }
  }

  Future<void> syncCandles(String symbol) async {
    final uri = Uri.parse('$_baseUrl/candles/$symbol/sync');
    try {
      final response = await _get(uri);
      if (response.statusCode != 200) {
        throw Exception('Sync failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Sync service error: $e');
    }
  }
}
