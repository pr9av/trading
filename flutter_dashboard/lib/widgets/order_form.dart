import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class OrderForm extends StatefulWidget {
  final String symbol;
  final double currentPrice;

  const OrderForm({super.key, required this.symbol, required this.currentPrice});

  @override
  State<OrderForm> createState() => _OrderFormState();
}

class _OrderFormState extends State<OrderForm> {
  final _qtyController = TextEditingController(text: '10');
  String _orderType = 'MARKET';
  String _side = 'BUY';
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_side} ${widget.symbol}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Current Price: ₹${widget.currentPrice.toStringAsFixed(2)}',
            style: const TextStyle(color: Color(0xFF00D1FF), fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'BUY', label: Text('BUY'), icon: Icon(Icons.add_shopping_cart)),
              ButtonSegment(value: 'SELL', label: Text('SELL'), icon: Icon(Icons.sell_outlined)),
            ],
            selected: {_side},
            onSelectionChanged: (newSelection) {
              setState(() {
                _side = newSelection.first;
              });
            },
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return _side == 'BUY' ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2);
                }
                return null;
              }),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _qtyController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Quantity',
              border: OutlineInputBorder(),
              suffixText: 'Shares',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _orderType,
            decoration: const InputDecoration(
              labelText: 'Order Type',
              border: OutlineInputBorder(),
            ),
            items: ['MARKET', 'LIMIT', 'SL', 'SL-M']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => setState(() => _orderType = val!),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isSubmitting ? null : () => _placeOrder(auth.token, auth.userId),
            style: ElevatedButton.styleFrom(
              backgroundColor: _side == 'BUY' ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isSubmitting
                ? const CircularProgressIndicator(color: Colors.white)
                : Text('PLACE $_side ORDER', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _placeOrder(String? token, String? userId) async {
    if (token == null || userId == null) return;

    setState(() => _isSubmitting = true);

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/api/orders'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'user_id': userId,
          'symbol': widget.symbol,
          'side': _side,
          'quantity': int.tryParse(_qtyController.text) ?? 1,
          'order_type': _orderType,
          'exchange': 'NSE',
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order placed successfully!'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception('Failed to place order: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
