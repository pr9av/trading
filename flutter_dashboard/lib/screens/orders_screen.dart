import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/portfolio_provider.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider);
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('ORDERS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
      ),
      body: transactions.isEmpty
          ? const Center(child: Text('No order history.', style: TextStyle(color: Colors.white54)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final tx = transactions[index];
                final isBuy = tx.transactionType == 'BUY';
                
                return Card(
                  color: const Color(0xFF1E1E1E),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: isBuy ? const Color(0xFF00D1FF).withOpacity(0.2) : Colors.redAccent.withOpacity(0.2),
                      child: Icon(isBuy ? Icons.arrow_downward : Icons.arrow_upward, 
                        color: isBuy ? const Color(0xFF00D1FF) : Colors.redAccent, size: 20),
                    ),
                    title: Text('${isBuy ? 'BOUGHT' : 'SOLD'} ${tx.symbol}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(dateFormat.format(tx.timestamp)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${tx.quantity} @ ₹${tx.price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(currency.format(tx.totalAmount), style: TextStyle(color: isBuy ? Colors.redAccent : const Color(0xFF00FFA3), fontSize: 12)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
