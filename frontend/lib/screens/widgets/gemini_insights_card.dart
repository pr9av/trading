import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../providers/candle_provider.dart';

class GeminiInsightsCard extends ConsumerWidget {
  final String symbol;
  final double currentPrice;

  const GeminiInsightsCard({
    super.key,
    required this.symbol,
    required this.currentPrice,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiAsync = ref.watch(aiAnalysisProvider(symbol));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00D1FF).withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF00D1FF).withOpacity(0.1), Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFF00D1FF), size: 18),
                  const SizedBox(width: 10),
                  const Text(
                    'AI MULTI-PERIOD ANALYSIS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  _buildSignalBadge(aiAsync.asData?.value ?? ''),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20),
              child: aiAsync.when(
                data: (analysis) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MarkdownBody(
                      data: analysis,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.6),
                        h1: const TextStyle(color: Color(0xFF00D1FF), fontSize: 16, fontWeight: FontWeight.bold),
                        h2: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        h3: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        listBullet: const TextStyle(color: Color(0xFF00D1FF)),
                        tableBorder: TableBorder.all(color: Colors.white10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 8),
                    const Text(
                      'Generated using Gemini 1.5 Flash • 10m Cache',
                      style: TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF00D1FF), strokeWidth: 2)),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'AI Insights unavailable: $e',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalBadge(String analysis) {
    String signal = 'NEUTRAL';
    Color color = Colors.grey;
    
    if (analysis.toUpperCase().contains('BUY')) {
      signal = 'BUY';
      color = const Color(0xFF00FFA3);
    } else if (analysis.toUpperCase().contains('SELL')) {
      signal = 'SELL';
      color = const Color(0xFFFF4D4D);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        signal,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }
}
