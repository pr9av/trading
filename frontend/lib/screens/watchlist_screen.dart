import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/portfolio_provider.dart';
import 'main_screen.dart'; // for websocketProvider
import 'stock_detail_screen.dart';

class WatchlistScreen extends ConsumerWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchlist = ref.watch(watchlistProvider);
    final ws = ref.watch(websocketProvider); // Listen to live ticks
    final marketData = ws.ticks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WATCHLIST', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
      ),
      body: watchlist.isEmpty
          ? const Center(child: Text('Watchlist is empty.', style: TextStyle(color: Colors.white54)))
          : ListView.builder(
              itemCount: watchlist.length,
              itemBuilder: (context, index) {
                final symbol = watchlist[index];
                final tick = marketData[symbol];
                
                if (tick == null) {
                  return ListTile(title: Text(symbol), subtitle: const Text('Waiting for data...'));
                }

                final isPositive = (tick.change ?? 0.0) >= 0;
                final color = isPositive ? const Color(0xFF00FFA3) : Colors.redAccent;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: const Color(0xFF1E1E1E),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(symbol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹${tick.ltp.toStringAsFixed(2)}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
                        Text('${isPositive ? '+' : ''}${(tick.changePercent ?? 0.0).toStringAsFixed(2)}%', style: TextStyle(color: color, fontSize: 14)),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => StockDetailScreen(symbol: symbol, initialPrice: tick.ltp)));
                    },
                  ),
                );
              },
            ),
    );
  }
}
