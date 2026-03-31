import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'main_screen.dart'; // for websocketProvider
import 'stock_detail_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ws = ref.watch(websocketProvider);
    final marketData = ws.ticks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ANALYTICS DASHBOARD', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, size: 28),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('User Profile'),
                  content: const Text('Welcome to Blauplug V2!\n\nThis platform provides advanced real-time market analytics and insights.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('CLOSE'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Analyze real-time market trends and data-driven signals.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          if (marketData.isEmpty)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: Color(0xFF00D1FF))),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up, color: Color(0xFF00FFA3), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'MARKET OVERVIEW',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final tick = marketData.values.elementAt(index);
                    final isPositive = (tick.change ?? 0.0) >= 0;
                    final color = isPositive ? const Color(0xFF00FFA3) : Colors.redAccent;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      color: const Color(0xFF1E1E1E),
                      child: ListTile(
                        title: Text(tick.symbol, style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: Text(
                          '₹${tick.ltp.toStringAsFixed(2)}',
                          style: TextStyle(color: color, fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StockDetailScreen(
                                symbol: tick.symbol,
                                initialPrice: tick.ltp,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  childCount: marketData.length > 5 ? 5 : marketData.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
