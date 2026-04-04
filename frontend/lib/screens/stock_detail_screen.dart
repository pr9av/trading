import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:candlesticks/candlesticks.dart' as chart;
import '../providers/candle_provider.dart';
import '../providers/market_hours_provider.dart';
import '../data/models/hive/watchlist_item.dart';
import '../providers/portfolio_provider.dart';
import 'widgets/gemini_insights_card.dart';

class StockDetailScreen extends ConsumerStatefulWidget {
  final String symbol;
  final double initialPrice;

  const StockDetailScreen({super.key, required this.symbol, required this.initialPrice});

  @override
  ConsumerState<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends ConsumerState<StockDetailScreen> {
  String _selectedRange = '1D';
  DateTime? _customFrom;
  DateTime? _customTo;

  @override
  Widget build(BuildContext context) {
    final isMarketOpen = ref.watch(isMarketOpenProvider);
    final watchlist = ref.watch(watchlistProvider);
    final isWatched = watchlist.contains(widget.symbol);

    // Determine data source: custom range or standard range
    final bool isCustom = _selectedRange == 'CUSTOM' && _customFrom != null && _customTo != null;
    final candlesAsync = isCustom
        ? ref.watch(candleCustomRangeProvider((symbol: widget.symbol, from: _customFrom!, to: _customTo!)))
        : ref.watch(candleProvider((symbol: widget.symbol, range: _selectedRange)));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.symbol, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
            const Text('NSE INDIA', style: TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          // Market Open indicator
          Container(
            margin: const EdgeInsets.only(right: 4, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isMarketOpen ? const Color(0xFF00FFA3).withOpacity(0.15) : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isMarketOpen ? '● LIVE' : '● CLOSED',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: isMarketOpen ? const Color(0xFF00FFA3) : Colors.orange,
              ),
            ),
          ),
          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00D1FF)),
            tooltip: 'Sync from Zerodha',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Syncing latest market data...'), backgroundColor: Color(0xFF1E1E1E)),
              );
              try {
                await ref.read(backendServiceProvider).syncCandles(widget.symbol);
                ref.invalidate(candleProvider((symbol: widget.symbol, range: _selectedRange)));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Market data synchronized!'), backgroundColor: Color(0xFF00FFA3)),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
          ),
          // Watchlist Toggle
          IconButton(
            icon: Icon(isWatched ? Icons.auto_awesome_motion : Icons.auto_awesome_motion_outlined,
                color: isWatched ? const Color(0xFF00D1FF) : Colors.white24),
            onPressed: () async {
              final repo = ref.read(portfolioRepositoryProvider);
              if (isWatched) {
                await repo.removeFromWatchlist(widget.symbol);
              } else {
                await repo.addToWatchlist(WatchlistItem(symbol: widget.symbol, exchange: 'NSE', addedDate: DateTime.now()));
              }
              ref.read(portfolioNotifierProvider.notifier).refresh();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildPriceHeader(isMarketOpen),
            _buildRangeSelector(),
            if (isCustom && _customFrom != null && _customTo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${_formatDate(_customFrom!)}  →  ${_formatDate(_customTo!)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            SizedBox(
              height: 400,
              child: candlesAsync.when(
                data: (candles) {
                  if (candles.length < 20) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(candles.isEmpty ? Icons.cloud_download_outlined : Icons.auto_graph, color: Colors.white24, size: 48),
                          const SizedBox(height: 12),
                          Text(candles.isEmpty ? 'No chart data for this stock.' : 'Not enough data points to plot the chart.', style: const TextStyle(color: Colors.white54)),
                          const SizedBox(height: 4),
                          Text(candles.isEmpty ? 'Pulls history from Zerodha (~30s)' : 'Collected ${candles.length}/20 points. Fetching more history...', style: const TextStyle(color: Colors.white24, fontSize: 11)),
                          const SizedBox(height: 16),
                          _SyncButton(
                            symbol: widget.symbol,
                            onSyncComplete: () {
                              ref.invalidate(candleProvider((symbol: widget.symbol, range: _selectedRange)));
                              if (_customFrom != null && _customTo != null) {
                                ref.invalidate(candleCustomRangeProvider((symbol: widget.symbol, from: _customFrom!, to: _customTo!)));
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  }
                  final chartCandles = candles.map((c) => chart.Candle(
                    date: c.time, high: c.high, low: c.low, open: c.open, close: c.close, volume: c.volume.toDouble(),
                  )).toList();
                  return chart.Candlesticks(candles: chartCandles);
                },
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00D1FF))),
                error: (e, _) => Center(child: Text('History fetch deferred: $e', style: const TextStyle(color: Colors.white24, fontSize: 12))),
              ),
            ),
            const SizedBox(height: 10),
            GeminiInsightsCard(symbol: widget.symbol, currentPrice: widget.initialPrice),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Widget _buildPriceHeader(bool isMarketOpen) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.initialPrice > 0 ? '₹${widget.initialPrice.toStringAsFixed(2)}' : '---',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1),
              ),
              const Text('LAST TRADED PRICE', style: TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isMarketOpen ? const Color(0xFF00FFA3).withOpacity(0.1) : Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isMarketOpen ? const Color(0xFF00FFA3).withOpacity(0.2) : Colors.orange.withOpacity(0.15)),
            ),
            child: Text(
              isMarketOpen ? 'REAL-TIME' : 'HISTORICAL',
              style: TextStyle(
                color: isMarketOpen ? const Color(0xFF00FFA3) : Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeSelector() {
    final ranges = ['1D', '5D', '1M', '6M', 'YTD', 'CUSTOM'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ranges.map((range) {
            final isSelected = _selectedRange == range;
            return GestureDetector(
              onTap: () async {
                if (range == 'CUSTOM') {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: _customFrom != null && _customTo != null
                        ? DateTimeRange(start: _customFrom!, end: _customTo!)
                        : DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now()),
                    builder: (context, child) => Theme(
                      data: ThemeData.dark().copyWith(
                        colorScheme: const ColorScheme.dark(primary: Color(0xFF00D1FF), surface: Color(0xFF1E1E1E)),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedRange = 'CUSTOM';
                      _customFrom = picked.start;
                      _customTo = picked.end;
                    });
                  }
                } else {
                  setState(() => _selectedRange = range);
                }
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF00D1FF).withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? const Color(0xFF00D1FF) : (range == 'CUSTOM' ? Colors.white24 : Colors.transparent)),
                ),
                child: Row(
                  children: [
                    if (range == 'CUSTOM') const Icon(Icons.calendar_month, size: 12, color: Colors.white38),
                    if (range == 'CUSTOM') const SizedBox(width: 4),
                    Text(
                      range,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF00D1FF) : (range == 'CUSTOM' ? Colors.white38 : Colors.white38),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Stateful sync button that shows a loading spinner while pulling 6 months of data from Zerodha
class _SyncButton extends StatefulWidget {
  final String symbol;
  final VoidCallback onSyncComplete;
  const _SyncButton({required this.symbol, required this.onSyncComplete});
  @override
  State<_SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends State<_SyncButton> {
  bool _loading = false;
  String _status = '';

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Column(children: [
        const CircularProgressIndicator(color: Color(0xFF00D1FF), strokeWidth: 2),
        const SizedBox(height: 12),
        Text(_status.isEmpty ? 'Connecting to Zerodha...' : _status,
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ]);
    }
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00D1FF).withOpacity(0.1),
        foregroundColor: const Color(0xFF00D1FF),
        side: const BorderSide(color: Color(0xFF00D1FF), width: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      onPressed: () async {
        setState(() { _loading = true; _status = 'Fetching from Zerodha...'; });
        try {
          final service = ProviderScope.containerOf(context).read(backendServiceProvider);
          await service.syncCandles(widget.symbol);
          if (mounted) setState(() { _status = 'Done! Reloading chart...'; });
          await Future.delayed(const Duration(milliseconds: 800));
          // Always reset so the button is usable again if data is still missing
          if (mounted) setState(() { _loading = false; _status = ''; });
          widget.onSyncComplete();
        } catch (e) {
          if (mounted) {
            setState(() { _loading = false; _status = ''; });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Sync failed. Zerodha token may be expired.\n$e'),
                backgroundColor: Colors.redAccent,
                duration: const Duration(seconds: 6),
              ),
            );
          }
        }
      },
      icon: const Icon(Icons.download, size: 16),
      label: const Text('Fetch from Zerodha', style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
