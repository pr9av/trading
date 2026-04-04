import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/analytics_provider.dart';

// ── Available symbols for comparison (auto-derived from volume data) ────────
// Up to 10 can be selected at once, matching the backend's max.

class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key});

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> with SingleTickerProviderStateMixin {
  final Set<String> _selected = {};
  late TabController _tabController;

  static const _accentColors = [
    Color(0xFF00D1FF),
    Color(0xFF00FFA3),
    Color(0xFFFFD700),
    Color(0xFFFF6B6B),
    Color(0xFFDA70D6),
    Color(0xFFFF8C42),
    Color(0xFF7DF9FF),
    Color(0xFFB5EAD7),
    Color(0xFFFFDFBA),
    Color(0xFFC9B6E4),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final symbolsAsync = ref.watch(activeSymbolsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text(
          'COMPARE SYMBOLS',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 16, color: Color(0xFF00D1FF)),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00D1FF),
          labelColor: const Color(0xFF00D1FF),
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: 'Daily P&L'),
            Tab(text: 'Volume'),
            Tab(text: 'Detailed Metrics'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Symbol Selector ───────────────────────────────────
          Container(
            color: const Color(0xFF121212),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.tune, color: Color(0xFF00D1FF), size: 16),
                  const SizedBox(width: 6),
                  const Text('Select symbols (max 10)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const Spacer(),
                  if (_selected.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => _selected.clear()),
                      child: const Text('Clear', style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 12)),
                    ),
                ]),
                const SizedBox(height: 8),
                symbolsAsync.when(
                  loading: () => const SizedBox(height: 36, child: Center(child: CircularProgressIndicator(color: Color(0xFF00D1FF), strokeWidth: 2))),
                  error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  data: (symbols) {
                    if (symbols.isEmpty) {
                      return const Text('No symbols available. Run the simulator first.', style: TextStyle(color: Colors.white54, fontSize: 12));
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: symbols.map((sym) {
                        final isSelected = _selected.contains(sym);
                        return GestureDetector(
                          onTap: () => setState(() {
                            if (isSelected) {
                              _selected.remove(sym);
                            } else if (_selected.length < 10) {
                              _selected.add(sym);
                            }
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF00D1FF).withOpacity(0.15) : const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF00D1FF) : Colors.white12,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Text(
                              sym,
                              style: TextStyle(
                                color: isSelected ? const Color(0xFF00D1FF) : Colors.white60,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── Charts ─────────────────────────────────────────────
          Expanded(
            child: _selected.isEmpty
                ? _emptyState()
                : _CompareCharts(
                    key: ValueKey(_selected.join(',')),
                    symbols: _selected.toList(),
                    tabController: _tabController,
                    colors: _accentColors,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.compare_arrows, size: 64, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text('Select symbols above to compare', style: TextStyle(color: Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Compare charts widget — watches the provider and renders tab content
// ────────────────────────────────────────────────────────────────────────────
class _CompareCharts extends ConsumerWidget {
  final List<String> symbols;
  final TabController tabController;
  final List<Color> colors;

  const _CompareCharts({
    super.key,
    required this.symbols,
    required this.tabController,
    required this.colors,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compareAsync = ref.watch(compareProvider(symbols));
    final metricsAsync = ref.watch(compareMetricsProvider(symbols));

    return compareAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00D1FF))),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load comparison data:\n$e', style: const TextStyle(color: Colors.white24, fontSize: 12), textAlign: TextAlign.center),
        ),
      ),
      data: (data) {
        return TabBarView(
          controller: tabController,
          children: [
            _buildBarChart(data, 'pnl', '₹', 'Daily P&L'),
            _buildBarChart(data, 'volume', '', 'Volume'),
            metricsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00D1FF))),
              error: (e, _) => Center(child: Text('Metrics sync deferred: $e', style: const TextStyle(color: Colors.white24))),
              data: (metrics) => _buildMetricsTable(metrics),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricsTable(Map<String, Map<String, dynamic>> metrics) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: const Color(0xFF161616),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 24,
            headingTextStyle: const TextStyle(color: Color(0xFF00D1FF), fontWeight: FontWeight.bold, fontSize: 12),
            dataTextStyle: const TextStyle(color: Colors.white70, fontSize: 13),
            columns: const [
              DataColumn(label: Text('SYMBOL')),
              DataColumn(label: Text('LTP'), numeric: true),
              DataColumn(label: Text('24H HIGH'), numeric: true),
              DataColumn(label: Text('24H LOW'), numeric: true),
              DataColumn(label: Text('24H VOL')),
            ],
            rows: symbols.map((sym) {
              final m = metrics[sym] ?? {};
              final ltp = double.tryParse(m['ltp']?.toString() ?? '0') ?? 0.0;
              final high = double.tryParse(m['high_24h']?.toString() ?? '0') ?? 0.0;
              final low = double.tryParse(m['low_24h']?.toString() ?? '0') ?? 0.0;
              final vol = double.tryParse(m['volume_24h']?.toString() ?? '0') ?? 0.0;

              return DataRow(cells: [
                DataCell(Text(sym, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                DataCell(Text('₹${ltp.toStringAsFixed(2)}')),
                DataCell(Text('₹${high.toStringAsFixed(2)}')),
                DataCell(Text('₹${low.toStringAsFixed(2)}')),
                DataCell(Text(vol > 1000000 ? '${(vol/1000000).toStringAsFixed(1)}M' : vol.toInt().toString())),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart(List<Map<String, dynamic>> data, String field, String prefix, String label) {
    final values = data.map((d) => (d[field] as num).toDouble()).toList();
    final maxVal = values.fold(0.0, (m, v) => v.abs() > m ? v.abs() : m);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          // Legend row
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: List.generate(data.length, (i) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: colors[i % colors.length], borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 4),
                Text(data[i]['symbol'].toString(), style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            )),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              color: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: BarChart(BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal * 1.3,
                  minY: field == 'pnl' ? -maxVal * 1.3 : 0,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: const Color(0xFF2A2A2A),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final item = data[group.x.toInt()];
                        return BarTooltipItem(
                          '${item['symbol']}\n$prefix${rod.toY.toStringAsFixed(2)}',
                          const TextStyle(color: Colors.white, fontSize: 12),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, m) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(data[idx]['symbol'].toString(), style: const TextStyle(fontSize: 9, color: Colors.white60)),
                        );
                      },
                    )),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(color: Colors.white10, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(data.length, (i) {
                    final val = values[i];
                    final color = field == 'pnl'
                        ? (val >= 0 ? const Color(0xFF00FFA3) : const Color(0xFFFF4D4D))
                        : colors[i % colors.length];
                    return BarChartGroupData(
                      x: i,
                      barRods: [BarChartRodData(
                        toY: val,
                        fromY: field == 'pnl' ? 0 : 0,
                        color: color,
                        width: 28,
                        borderRadius: BorderRadius.circular(4),
                      )],
                    );
                  }),
                )),
              ),
            ),
          ),
          // Summary table
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFF161616),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(children: [
                    const Expanded(child: Text('Symbol', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                    Expanded(child: Text(label, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                  ]),
                  const Divider(color: Colors.white12, height: 12),
                  ...List.generate(data.length, (i) {
                    final val = values[i];
                    final color = field == 'pnl'
                        ? (val >= 0 ? const Color(0xFF00FFA3) : const Color(0xFFFF4D4D))
                        : colors[i % colors.length];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Expanded(child: Text(data[i]['symbol'].toString(), style: const TextStyle(color: Colors.white70, fontSize: 12))),
                        Expanded(child: Text(
                          '$prefix${val.toStringAsFixed(2)}',
                          textAlign: TextAlign.right,
                          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                        )),
                      ]),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
