import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Holding {
  final String symbol;
  final int quantity;
  final double avgBuyPrice;
  final double currentPrice;
  final double pnl;

  Holding({
    required this.symbol,
    required this.quantity,
    required this.avgBuyPrice,
    required this.currentPrice,
    required this.pnl,
  });

  factory Holding.fromJson(Map<String, dynamic> json) {
    return Holding(
      symbol: json['symbol'] ?? '',
      quantity: json['quantity'] ?? 0,
      avgBuyPrice: (json['avg_buy_price'] as num?)?.toDouble() ?? 0.0,
      currentPrice: (json['current_price'] as num?)?.toDouble() ?? 0.0,
      pnl: (json['pnl'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PortfolioData {
  final double cashBalance;
  final double holdingsValue;
  final double totalValue;
  final double totalPnl;
  final double dayPnl;

  PortfolioData({
    required this.cashBalance,
    required this.holdingsValue,
    required this.totalValue,
    required this.totalPnl,
    required this.dayPnl,
  });

  factory PortfolioData.fromJson(Map<String, dynamic> json) {
    return PortfolioData(
      cashBalance: (json['cash_balance'] as num?)?.toDouble() ?? 0.0,
      holdingsValue: (json['holdings_value'] as num?)?.toDouble() ?? 0.0,
      totalValue: (json['total_value'] as num?)?.toDouble() ?? 0.0,
      totalPnl: (json['total_pnl'] as num?)?.toDouble() ?? 0.0,
      dayPnl: (json['day_pnl'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PortfolioService with ChangeNotifier {
  PortfolioData? _portfolio;
  List<Holding> _holdings = [];
  bool _isLoading = false;
  String? _error;

  PortfolioData? get portfolio => _portfolio;
  List<Holding> get holdings => _holdings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final String _baseUrl = 'http://localhost:8000/api/portfolio';

  Future<void> fetchPortfolio(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        _portfolio = PortfolioData.fromJson(jsonDecode(response.body));
      } else {
        _error = 'Failed to fetch portfolio: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Error fetching portfolio: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchHoldings(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/holdings'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _holdings = data.map((item) => Holding.fromJson(item)).toList();
      } else {
        _error = 'Failed to fetch holdings: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Error fetching holdings: $e';
    }

    _isLoading = false;
    notifyListeners();
  }
}
