import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:candlesticks/candlesticks.dart' as chart;
import '../providers/candle_provider.dart';
import '../data/models/hive/watchlist_item.dart';
import '../data/services/gemini_service.dart';
import '../providers/portfolio_provider.dart';

class StockDetailScreen extends ConsumerStatefulWidget {
  final String symbol;
  final double initialPrice;

  const StockDetailScreen({super.key, required this.symbol, required this.initialPrice});

  @override
  ConsumerState<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends ConsumerState<StockDetailScreen> {
  String _selectedInterval = '1min';
  
  @override
  Widget build(BuildContext context) {
    final candlesAsync = ref.watch(candleProvider((symbol: widget.symbol, interval: _selectedInterval)));
    final watchlist = ref.watch(watchlistProvider);
    final isWatched = watchlist.contains(widget.symbol);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.symbol, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        actions: [
          IconButton(
            icon: Icon(isWatched ? Icons.bookmark : Icons.bookmark_border, color: Theme.of(context).colorScheme.primary),
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
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => _showAiAnalysisDialog(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildIntervalSelector(),
          Expanded(
            child: candlesAsync.when(
              data: (candles) {
                if (candles.length < 15) {
                  return Center(
                    child: Text(
                      'Insufficient data for $_selectedInterval interval (${candles.length}/15).\nPlease select a smaller interval or wait for more market data.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54, height: 1.5),
                    ),
                  );
                }
                
                final chartCandles = candles.map((c) => chart.Candle(
                  date: c.time,
                  high: c.high,
                  low: c.low,
                  open: c.open,
                  close: c.close,
                  volume: c.volume.toDouble(),
                )).toList();

                return chart.Candlesticks(
                  candles: chartCandles,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00D1FF))),
              error: (e, st) => Center(child: Text('Error loading chart: $e', style: const TextStyle(color: Colors.red))),
            ),
          ),
          // Trading bar removed to pivot towards data analytics
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildIntervalSelector() {
    final intervals = ['1min', '5min', '1day'];
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: intervals.length,
        itemBuilder: (context, index) {
          final interval = intervals[index];
          final isSelected = _selectedInterval == interval;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
            child: ChoiceChip(
              label: Text(interval),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) setState(() => _selectedInterval = interval);
              },
            ),
          );
        },
      ),
    );
  }

  void _showAiAnalysisDialog(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(children: const [Icon(Icons.auto_awesome, color: Color(0xFF00D1FF)), SizedBox(width: 8), Text('Gemini Analysis')]),
        content: const Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Analyzing market context...')]),
      )
    );

    final gemini = GeminiService();
    // Removed user holdings from the Gemini prompt to pivot towards objective data analytics
    final analysis = await gemini.analyzeStock(widget.symbol, "Current Price: ${widget.initialPrice}. Analyze the recent trend and suggest potential support/resistance levels based on price action.");

    if (mounted) {
      Navigator.pop(context); // close loading
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Gemini Insights'),
          content: SingleChildScrollView(child: Text(analysis)),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CLOSE'))],
        )
      );
    }
  }
}
