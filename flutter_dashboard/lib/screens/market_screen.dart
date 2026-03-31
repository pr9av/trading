import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'main_screen.dart'; // imports websocketProvider
import 'stock_detail_screen.dart';

class MarketScreen extends ConsumerWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ws = ref.watch(websocketProvider);
    final marketData = ws.ticks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MARKETS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
      ),
      body: marketData.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D1FF)))
          : ListView.builder(
              itemCount: marketData.length,
              itemBuilder: (context, index) {
                final symbol = marketData.keys.elementAt(index);
                final tick = marketData[symbol]!;
                
                final isPositive = (tick.change ?? 0.0) >= 0;
                final color = isPositive ? const Color(0xFF00FFA3) : Colors.redAccent;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: const Color(0xFF1E1E1E),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(symbol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Text('Vol: ${tick.volume}'),
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
