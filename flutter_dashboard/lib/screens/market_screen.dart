import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/websocket_service.dart';
import '../widgets/order_form.dart';

class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search Symbols (e.g., RELIANCE)',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
            ),
          ),
        ),
        Expanded(
          child: Consumer<WebSocketService>(
            builder: (context, ws, _) {
              final tickList = ws.ticks.values.toList();
              
              if (tickList.isEmpty && !ws.isConnected) {
                return const Center(child: CircularProgressIndicator());
              }

              if (tickList.isEmpty) {
                return const Center(
                  child: Text('Waiting for market data...', style: TextStyle(color: Colors.white54)),
                );
              }

              return ListView.separated(
                itemCount: tickList.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white12),
                itemBuilder: (context, index) {
                  final tick = tickList[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(
                      tick.symbol,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    subtitle: const Text('NSE', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          tick.ltp.toStringAsFixed(2),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        if (tick.change != null)
                          Text(
                            '${tick.change! >= 0 ? "+" : ""}${tick.changePercent!.toStringAsFixed(2)}% (${tick.change! >= 0 ? "+" : ""}${tick.change!.toStringAsFixed(2)})',
                            style: TextStyle(
                              color: tick.change! >= 0 ? const Color(0xFF00FFA3) : Colors.redAccent,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    onTap: () {
                      _showOrderSheet(context, tick.symbol, tick.ltp);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showOrderSheet(BuildContext context, String symbol, double price) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => OrderForm(symbol: symbol, currentPrice: price),
    );
  }
}
