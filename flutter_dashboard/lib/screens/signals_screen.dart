import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class SignalsScreen extends StatefulWidget {
  const SignalsScreen({super.key});

  @override
  State<SignalsScreen> createState() => _SignalsScreenState();
}

class _SignalsScreenState extends State<SignalsScreen> {
  List<dynamic> _signals = [];
  bool _isLoading = true;
  String? _error;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchSignals();
    // Auto-refresh every 10 seconds
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _fetchSignals();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchSignals() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/api/signals/latest'),
        headers: {'Authorization': 'Bearer ${auth.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _signals = (data['signals'] as List).reversed.toList();
          _isLoading = false;
          _error = null;
        });
      } else {
        setState(() {
          _error = 'Failed to load signals (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00D1FF).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.psychology_rounded,
              color: Color(0xFF00D1FF), size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Trading Signals',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 2),
                Text('LSTM model • Auto-refreshes every 10s',
                    style:
                        TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00D1FF)),
            onPressed: _fetchSignals,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.signal_wifi_off_rounded,
                size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _fetchSignals,
                child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_signals.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty_rounded,
                size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text('Generating signals…',
                style: TextStyle(color: Colors.white38, fontSize: 16)),
            SizedBox(height: 8),
            Text('Waiting for enough market ticks to build the LSTM window.',
                style: TextStyle(color: Colors.white24, fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchSignals,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _signals.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) =>
            _SignalTile(signal: _signals[index]),
      ),
    );
  }
}

class _SignalTile extends StatelessWidget {
  final Map<String, dynamic> signal;

  const _SignalTile({required this.signal});

  Color _signalColor(String s) {
    switch (s.toUpperCase()) {
      case 'BUY':  return const Color(0xFF00FFA3);
      case 'SELL': return Colors.redAccent;
      default:     return Colors.orange;
    }
  }

  IconData _signalIcon(String s) {
    switch (s.toUpperCase()) {
      case 'BUY':  return Icons.arrow_upward_rounded;
      case 'SELL': return Icons.arrow_downward_rounded;
      default:     return Icons.remove_rounded;
    }
  }

  String _formatTime(String? ts) {
    if (ts == null) return '—';
    try {
      final dt = DateTime.parse(ts).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}:'
          '${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sigStr = signal['signal'] ?? 'HOLD';
    final confidence = ((signal['confidence'] as num?) ?? 0.0).toDouble();
    final color = _signalColor(sigStr);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_signalIcon(sigStr), color: color, size: 14),
                      const SizedBox(width: 4),
                      Text(sigStr,
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  signal['symbol'] ?? '—',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 17),
                ),
                const Spacer(),
                Text(
                  _formatTime(signal['generated_at']),
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Confidence ',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: confidence,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(confidence * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ],
            ),
            if (signal['features'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildFeatureBadge(
                      'LTP', '₹${((signal['features']['ltp'] as num?)?.toStringAsFixed(2)) ?? "—"}'),
                  const SizedBox(width: 8),
                  _buildFeatureBadge(
                      'Vol', '${signal['features']['volume'] ?? "—"}'),
                  const SizedBox(width: 8),
                  _buildFeatureBadge('Model', signal['model'] ?? 'LSTM'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$label: $value',
          style: const TextStyle(color: Colors.white38, fontSize: 11)),
    );
  }
}
