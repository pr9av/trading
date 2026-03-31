import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/analytics_provider.dart';

// Known sectors — extend this list as your fundamentals table grows
const _kSectors = ['All', 'Finance', 'Technology', 'Energy', 'Healthcare', 'Agriculture', 'Metals'];

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String _selectedSector = 'All';

  String? get _sectorParam => _selectedSector == 'All' ? null : _selectedSector;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text(
          'MARKET ANALYTICS',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 16, color: Color(0xFF00D1FF)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Sector Filter Chips ──────────────────────────────
            _buildSectorFilterRow(),
            const SizedBox(height: 20),

            _buildSectionHeader('📈 Live P&L Trend — All Active Symbols'),
            const SizedBox(height: 12),
            _buildAllPnlCharts(),
            const SizedBox(height: 24),
            _buildSectionHeader('📊 Market Volume (Last 24h)'),
            const SizedBox(height: 12),
            _buildVolumeChart(),
            const SizedBox(height: 24),
            _buildSectionHeader('🥧 Top Asset Distribution (DB)'),
            const SizedBox(height: 12),
            _buildDistributionChart(),
            const SizedBox(height: 24),
            _buildSectionHeader('🏦 Trading Behavior (Backend)'),
            const SizedBox(height: 12),
            _buildBehaviorMetrics(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectorFilterRow() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _kSectors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final sector = _kSectors[i];
          final selected = sector == _selectedSector;
          return GestureDetector(
            onTap: () => setState(() => _selectedSector = sector),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF00D1FF) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? const Color(0xFF00D1FF) : Colors.white12),
              ),
              child: Text(
                sector,
                style: TextStyle(
                  color: selected ? Colors.black : Colors.white70,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1),
    );
  }

  Widget _buildAllPnlCharts() {
    final symbolsAsync = ref.watch(activeSymbolsProvider);
    return symbolsAsync.when(
      loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(color: Color(0xFF00D1FF), strokeWidth: 2))),
      error: (e, _) => _errorCard('Could not load symbol list: $e'),
      data: (symbols) {
        if (symbols.isEmpty) {
          return _infoCard('No market data in DB yet. Make sure the simulator is running.');
        }
        return Column(
          children: [
            for (int i = 0; i < symbols.length; i++) ...[
              _buildPnlChart(symbols[i]),
              if (i < symbols.length - 1) const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPnlChart(String symbol) {
    final pnlAsync = ref.watch(dailyPnlProvider(symbol));
    return pnlAsync.when(
      loading: () => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator(color: Color(0xFF00D1FF), strokeWidth: 2))),
      error: (e, _) => _errorCard('P&L data unavailable: $e'),
      data: (data) {
        if (data.length < 2) {
          return _infoCard('Insufficient P&L data for $symbol. Collecting ticks...');
        }
        final reversed = data.reversed.toList();
        final spots = List.generate(reversed.length, (i) => FlSpot(i.toDouble(), reversed[i].dailyPnl));
        final isPositive = data.first.dailyPnl >= 0;
        final color = isPositive ? const Color(0xFF00FFA3) : const Color(0xFFFF4D4D);

        return Card(
          color: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(symbol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                  Text(
                    '${isPositive ? "+" : ""}${data.first.dailyPnl.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
                  ),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                  height: 140,
                  child: LineChart(LineChartData(
                    gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: null,
                      getDrawingHorizontalLine: (_) => FlLine(color: Colors.white10, strokeWidth: 1)),
                    titlesData: const FlTitlesData(
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: color,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: color.withOpacity(0.15)),
                    )],
                  )),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVolumeChart() {
    final volAsync = ref.watch(backendVolumeProvider(_sectorParam));
    return volAsync.when(
      loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(color: Color(0xFF00D1FF), strokeWidth: 2))),
      error: (e, _) => _errorCard('Volume data unavailable: $e'),
      data: (data) {
        if (data.isEmpty) return _infoCard(_sectorParam != null ? 'No volume data for sector "$_sectorParam".' : 'No volume data yet.');
        final colors = [const Color(0xFF00D1FF), const Color(0xFF00FFA3), const Color(0xFFFFD700), const Color(0xFFFF6B6B), const Color(0xFFDA70D6)];
        final maxVol = data.fold(0.0, (m, d) => d.volume > m ? d.volume : m);

        return Card(
          color: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 180,
              child: BarChart(BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVol * 1.2,
                barTouchData: BarTouchData(enabled: true),
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
                        child: Text(data[idx].symbol, style: const TextStyle(fontSize: 9, color: Colors.white60)),
                      );
                    },
                  )),
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: Colors.white10, strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(data.length, (i) => BarChartGroupData(
                  x: i,
                  barRods: [BarChartRodData(toY: data[i].volume, color: colors[i % colors.length], width: 22, borderRadius: BorderRadius.circular(4))],
                )),
              )),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDistributionChart() {
    final distAsync = ref.watch(backendDistributionProvider(_sectorParam));
    return distAsync.when(
      loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(color: Color(0xFF00D1FF), strokeWidth: 2))),
      error: (e, _) => _errorCard('Distribution unavailable: $e'),
      data: (data) {
        if (data.isEmpty) return _infoCard(_sectorParam != null ? 'No distribution for sector "$_sectorParam".' : 'No trade distribution data yet.');
        final colors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple];
        final total = data.fold(0.0, (s, d) => s + d.volume);
        if (total == 0) return _infoCard('No distribution data.');

        return Card(
          color: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 220,
              child: PieChart(PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 36,
                sections: List.generate(data.length, (i) {
                  final pct = (data[i].volume / total * 100).toStringAsFixed(1);
                  return PieChartSectionData(
                    color: colors[i % colors.length],
                    value: data[i].volume,
                    title: '${data[i].symbol}\n$pct%',
                    radius: 75,
                    titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  );
                }),
              )),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBehaviorMetrics() {
    final behaviorAsync = ref.watch(backendBehaviorProvider);
    return behaviorAsync.when(
      loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: Color(0xFF00D1FF), strokeWidth: 2))),
      error: (e, _) => _errorCard('Behavior data unavailable: $e'),
      data: (behavior) {
        if (behavior == null || behavior.totalTrades == 0) {
          return _infoCard('No recorded trades in the database yet.');
        }
        final buyRatio = (behavior.buys / behavior.totalTrades * 100).toStringAsFixed(1);
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            _metricCard('Total Trades', '${behavior.totalTrades}', const Color(0xFF00D1FF)),
            _metricCard('Total Volume', '₹${(behavior.totalVolume / 1000).toStringAsFixed(1)}K', const Color(0xFF00FFA3)),
            _metricCard('Fees Paid', '₹${behavior.totalFees.toStringAsFixed(2)}', Colors.orangeAccent),
            _metricCard('Buy Ratio', '$buyRatio%', Colors.purpleAccent),
          ],
        );
      },
    );
  }

  Widget _metricCard(String title, String value, Color color) {
    return Card(
      color: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _errorCard(String msg) => Card(
    color: Colors.red.withOpacity(0.1),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(padding: const EdgeInsets.all(16), child: Text(msg, style: const TextStyle(color: Colors.redAccent))),
  );

  Widget _infoCard(String msg) => Card(
    color: const Color(0xFF1A1A1A),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(padding: const EdgeInsets.all(16), child: Text(msg, style: const TextStyle(color: Colors.white54))),
  );
}
