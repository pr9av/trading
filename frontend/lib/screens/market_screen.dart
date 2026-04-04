import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'main_screen.dart';
import 'stock_detail_screen.dart';
import '../providers/candle_provider.dart';
import '../providers/market_hours_provider.dart';

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToStock(String symbol) {
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => StockDetailScreen(symbol: symbol.toUpperCase(), initialPrice: 0.0)));
  }

  @override
  Widget build(BuildContext context) {
    final ws = ref.watch(websocketProvider);
    final marketData = ws.ticks;
    final isMarketOpen = ref.watch(isMarketOpenProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('MARKETS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 20)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _buildAutocomplete(),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildMarketBanner(isMarketOpen),
          Expanded(child: _buildMainList(marketData)),
        ],
      ),
    );
  }

  Widget _buildAutocomplete() {
    return Autocomplete<Map<String, dynamic>>(
      optionsBuilder: (TextEditingValue textValue) async {
        final q = textValue.text.trim();
        if (q.isEmpty) return const [];

        try {
          final results = await ref.read(fundamentalSearchProvider(q).future);
          if (results.isEmpty) {
            // If nothing found, offer to navigate directly
            return [
              {'symbol': q.toUpperCase(), 'company_name': 'Search NSE for "$q"', 'source': 'direct', '_is_fallback': true}
            ];
          }
          return results;
        } catch (_) {
          return [
            {'symbol': q.toUpperCase(), 'company_name': 'Search NSE for "$q"', 'source': 'direct', '_is_fallback': true}
          ];
        }
      },
      displayStringForOption: (option) => option['symbol'] as String? ?? '',
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          style: const TextStyle(color: Colors.white),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) _navigateToStock(v.trim());
          },
          decoration: InputDecoration(
            hintText: 'Search any NSE stock (e.g. ZOMATO, WIPRO, SBIN)',
            hintStyle: const TextStyle(color: Colors.white24),
            prefixIcon: const Icon(Icons.search, color: Color(0xFF00D1FF)),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF2A2A2A),
            child: SizedBox(
              width: MediaQuery.of(context).size.width - 32,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: options.map((stock) {
                  final isFallback = stock['_is_fallback'] == true;
                  final source = stock['source'] as String? ?? 'unknown';

                  // Source badge styling
                  Color badgeColor;
                  String badgeText;
                  switch (source) {
                    case 'zerodha':
                      badgeColor = const Color(0xFF00FFA3);
                      badgeText = 'ZERODHA';
                      break;
                    case 'fundamentals':
                      badgeColor = const Color(0xFF00D1FF);
                      badgeText = 'LOCAL';
                      break;
                    case 'database':
                      badgeColor = Colors.orange;
                      badgeText = 'SERVER';
                      break;
                    default:
                      badgeColor = Colors.deepPurpleAccent;
                      badgeText = 'SEARCH';
                      break;
                  }

                  return InkWell(
                    onTap: () => onSelected(stock),
                    child: ListTile(
                      dense: true,
                      leading: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: isFallback ? Colors.deepPurple.withOpacity(0.2) : badgeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: isFallback
                            ? const Icon(Icons.cloud_download, color: Colors.deepPurpleAccent, size: 18)
                            : Center(child: Text(
                                (stock['symbol'] as String? ?? '?').isNotEmpty ? (stock['symbol']! as String)[0] : '?',
                                style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold),
                              )),
                      ),
                      title: Text(stock['symbol'] as String? ?? '', style: TextStyle(color: isFallback ? const Color(0xFF00D1FF) : Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(stock['company_name'] as String? ?? '', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Show price if available
                          if (stock['ltp'] != null) ...[
                            Text(
                              '₹${(double.tryParse(stock['ltp'].toString()) ?? 0).toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (!isFallback)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: badgeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: badgeColor.withOpacity(0.3)),
                              ),
                              child: Text(badgeText, style: TextStyle(color: badgeColor, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
      onSelected: (option) {
        final ltp = double.tryParse(option['ltp']?.toString() ?? '0') ?? 0.0;
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => StockDetailScreen(symbol: (option['symbol'] as String).toUpperCase(), initialPrice: ltp),
        ));
      },
    );
  }

  Widget _buildMarketBanner(bool isOpen) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isOpen ? const Color(0xFF00FFA3).withOpacity(0.08) : Colors.orange.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isOpen ? const Color(0xFF00FFA3).withOpacity(0.3) : Colors.orange.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: isOpen ? const Color(0xFF00FFA3) : Colors.orange)),
          const SizedBox(width: 10),
          Text(
            isOpen ? 'NSE LIVE  ·  Market Open (9:15 AM – 3:30 PM)' : 'NSE CLOSED  ·  Showing Historical Data from Zerodha',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isOpen ? const Color(0xFF00FFA3) : Colors.orange, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildMainList(Map<dynamic, dynamic> marketData) {
    if (marketData.isNotEmpty) {
      return ListView.builder(
        itemCount: marketData.length,
        itemBuilder: (context, index) {
          final symbol = marketData.keys.elementAt(index) as String;
          final tick = marketData[symbol]!;
          return _buildMarketCard(symbol, tick.ltp, tick.changePercent ?? 0.0, true);
        },
      );
    }
    return Consumer(builder: (context, ref, child) {
      final snapshotAsync = ref.watch(marketSnapshotProvider);
      return snapshotAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00D1FF))),
        error: (e, _) => Center(child: Text('Market sync deferred: $e', style: const TextStyle(color: Colors.white24))),
        data: (snapshot) {
          if (snapshot.isEmpty) return const Center(child: Text('No stored market data found.', style: TextStyle(color: Colors.white24)));
          return ListView.builder(
            itemCount: snapshot.length,
            itemBuilder: (context, index) {
              final item = snapshot[index];
              return _buildMarketCard(item['symbol'], double.tryParse(item['ltp']?.toString() ?? '0') ?? 0.0, 0.0, false);
            },
          );
        },
      );
    });
  }

  Widget _buildMarketCard(String symbol, double ltp, double change, bool isLive) {
    final isPositive = change >= 0;
    final color = isPositive ? const Color(0xFF00FFA3) : Colors.redAccent;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Text(symbol[0], style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ),
        title: Text(symbol, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white)),
        subtitle: Text(isLive ? 'LIVE UPDATING' : 'LAST SNAPSHOT',
            style: TextStyle(fontSize: 9, color: isLive ? const Color(0xFF00FFA3) : Colors.orange, fontWeight: FontWeight.bold)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(ltp > 0 ? '₹${ltp.toStringAsFixed(2)}' : '---',
                style: TextStyle(color: isLive ? color : Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
            if (change != 0)
              Text('${isPositive ? '+' : ''}${change.toStringAsFixed(2)}%',
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        onTap: () => _navigateToStock(symbol),
      ),
    );
  }
}
