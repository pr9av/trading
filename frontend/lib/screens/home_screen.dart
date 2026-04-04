import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'main_screen.dart'; // for websocketProvider
import 'stock_detail_screen.dart';
import '../providers/candle_provider.dart';
import '../providers/market_hours_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ws = ref.watch(websocketProvider);
    final marketData = ws.ticks;
    final wsMarketStatus = ws.marketStatus;
    final isLive = wsMarketStatus.isOpen && marketData.isNotEmpty;

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
          // ── Market Status Banner ──────────────────────────
          SliverToBoxAdapter(
            child: _MarketStatusBanner(
              mode: wsMarketStatus.mode,
              message: wsMarketStatus.message,
              nextOpen: wsMarketStatus.nextOpen,
              isLive: isLive,
            ),
          ),

          // ── Gemini AI Banner ──────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6B4EE6), Color(0xFF4E2EBF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF6B4EE6).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Gemini Market Insights', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Market Sentiment: Nifty 50 is showing strong recovery near 24,000. Institutional buying is increasing across IT and Banking sectors.',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),

          // ── Live Market Feed (when ticks are streaming) ───
          if (isLive) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Row(
                  children: const [
                    Icon(Icons.bolt, color: Color(0xFF00FFA3), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'LIVE MARKET FEED',
                      style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Color(0xFF00FFA3), fontSize: 14),
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
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      color: const Color(0xFF1E1E1E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Text(tick.symbol[0], style: TextStyle(color: color, fontWeight: FontWeight.bold))),
                        title: Text(tick.symbol, style: const TextStyle(fontWeight: FontWeight.w900)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₹${tick.ltp.toStringAsFixed(2)}', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
                            Text(
                              '${(tick.changePercent ?? 0) >= 0 ? "+" : ""}${(tick.changePercent ?? 0).toStringAsFixed(2)}%',
                              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => StockDetailScreen(symbol: tick.symbol, initialPrice: tick.ltp)));
                        },
                      ),
                    );
                  },
                  childCount: marketData.length,
                ),
              ),
            ),
          ]
          // ── Closed / Historical View (last known prices from DB) ──
          else
            SliverToBoxAdapter(
              child: Consumer(
                builder: (context, ref, child) {
                  final trendingAsync = ref.watch(trendingStocksProvider);
                  return trendingAsync.when(
                    loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Color(0xFF00D1FF)))),
                    error: (e, _) => const SizedBox(),
                    data: (stocks) {
                      return Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Padding(
                             padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                             child: Row(
                               children: [
                                 Icon(
                                   wsMarketStatus.mode == 'CLOSED' ? Icons.history : Icons.trending_up,
                                   color: Colors.white38, size: 18,
                                 ),
                                 const SizedBox(width: 8),
                                 Text(
                                   wsMarketStatus.mode == 'CLOSED' ? 'Last Known Prices' : 'Trending Stocks',
                                   style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1),
                                 ),
                               ],
                             ),
                           ),
                           ListView.builder(
                             shrinkWrap: true,
                             physics: const NeverScrollableScrollPhysics(),
                             padding: const EdgeInsets.symmetric(horizontal: 16),
                             itemCount: stocks.length,
                             itemBuilder: (context, index) {
                               final item = stocks[index];
                               final symbol = item['symbol'] as String;
                               final ltp = double.tryParse(item['ltp']?.toString() ?? '0') ?? 0.0;
                               final change = double.tryParse(item['change_percent']?.toString() ?? '0') ?? 0.0;
                               final isPositive = change >= 0;
                               
                               return Card(
                                 margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                 color: const Color(0xFF141414),
                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                 child: ListTile(
                                   contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                   leading: CircleAvatar(
                                     backgroundColor: const Color(0xFF00D1FF).withOpacity(0.05),
                                     radius: 24,
                                     child: Text(symbol[0], style: const TextStyle(color: Color(0xFF00D1FF), fontWeight: FontWeight.w900)),
                                   ),
                                   title: Column(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       Text(symbol, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16)),
                                       Text(item['sector'] ?? 'NSE', style: const TextStyle(fontSize: 10, color: Colors.white24, fontWeight: FontWeight.bold)),
                                     ],
                                   ),
                                   trailing: Column(
                                     mainAxisAlignment: MainAxisAlignment.center,
                                     crossAxisAlignment: CrossAxisAlignment.end,
                                     children: [
                                       Text('₹${ltp.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 14)),
                                       Text(
                                         '${isPositive ? '+' : ''}${change.toStringAsFixed(2)}%',
                                         style: TextStyle(color: isPositive ? const Color(0xFF00FFA3) : Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                       ),
                                     ],
                                   ),
                                   onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StockDetailScreen(symbol: symbol, initialPrice: ltp))),
                                 ),
                               );
                             },
                           ),
                         ],
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// A compact status banner that shows market mode
class _MarketStatusBanner extends StatelessWidget {
  final String mode;
  final String message;
  final String? nextOpen;
  final bool isLive;

  const _MarketStatusBanner({
    required this.mode,
    required this.message,
    this.nextOpen,
    required this.isLive,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;
    final IconData icon;

    switch (mode) {
      case 'LIVE':
        bgColor = const Color(0xFF00FFA3).withOpacity(0.08);
        textColor = const Color(0xFF00FFA3);
        icon = Icons.wifi_tethering;
        break;
      case 'PRE_MARKET':
        bgColor = Colors.orange.withOpacity(0.08);
        textColor = Colors.orange;
        icon = Icons.access_time;
        break;
      case 'CLOSED':
      default:
        bgColor = Colors.redAccent.withOpacity(0.06);
        textColor = Colors.redAccent.withOpacity(0.8);
        icon = Icons.nights_stay_outlined;
        break;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mode == 'LIVE' ? '● LIVE' : mode == 'PRE_MARKET' ? '● PRE-MARKET' : '● MARKET CLOSED',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
