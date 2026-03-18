import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/portfolio_service.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthService>(context, listen: false);
      final portfolio = Provider.of<PortfolioService>(context, listen: false);
      if (auth.token != null) {
        portfolio.fetchPortfolio(auth.token!);
        portfolio.fetchHoldings(auth.token!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSummaryCard(context),
          const SizedBox(height: 24),
          const Text(
            'Holdings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Consumer<PortfolioService>(
              builder: (context, portfolioService, _) {
                if (portfolioService.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (portfolioService.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text(portfolioService.error!, style: const TextStyle(color: Colors.white54)),
                      ],
                    ),
                  );
                }

                if (portfolioService.holdings.isEmpty) {
                  return const Center(
                    child: Text('No holdings yet', style: TextStyle(color: Colors.white54)),
                  );
                }

                return ListView.builder(
                  itemCount: portfolioService.holdings.length,
                  itemBuilder: (context, index) {
                    final holding = portfolioService.holdings[index];
                    return _buildHoldingTile(
                      holding.symbol,
                      holding.quantity,
                      holding.pnl,
                      holding.currentPrice,
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

  Widget _buildSummaryCard(BuildContext context) {
    return Consumer<PortfolioService>(
      builder: (context, portfolioService, _) {
        final portfolio = portfolioService.portfolio;
        
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1E1E), Color(0xFF121212)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              const Text(
                'Total Portfolio Value',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                '₹${(portfolio?.totalValue ?? 0).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat('Day P&L', '+₹${(portfolio?.dayPnl ?? 0).toStringAsFixed(2)}', 
                    (portfolio?.dayPnl ?? 0) >= 0 ? Colors.green : Colors.redAccent),
                  _buildStat('Invested', '₹${((portfolio?.totalValue ?? 0) - (portfolio?.totalPnl ?? 0)).toStringAsFixed(2)}', 
                    Colors.white70),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
        ),
      ],
    );
  }

  Widget _buildHoldingTile(String symbol, int qty, double pnl, double price) {
    final isProfit = pnl >= 0;
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  symbol,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  '$qty shares @ ₹${price.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${pnl.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isProfit ? Colors.green : Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${isProfit ? "+" : ""}${((pnl / (price * qty)) * 100).toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: isProfit ? Colors.green : Colors.redAccent,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(symbol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Qty: $qty', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${(pnl / 10).toStringAsFixed(2)}%', // Mocked returns
                  style: TextStyle(
                    color: isProfit ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${isProfit ? "+" : ""}₹${pnl.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: isProfit ? Colors.green : Colors.red,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
