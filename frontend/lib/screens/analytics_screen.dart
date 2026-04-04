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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF00D1FF), width: 1.5)),
      ),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildAllPnlCharts() {
    final symbolsAsync = ref.watch(activeSymbolsProvider);
    return symbolsAsync.when(
      loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(color: Color(0xFF00D1FF), strokeWidth: 2))),
      error: (e, _) => _errorCard('Could not load symbol list: $e'),
      data: (symbols) {
        if (symbols.isEmpty) {
          return _infoCard('Stock market is currently CLOSED. Syncing historical trends from Zerodha...');
        }
        return Column(
          children: [
            for (int i = 0; i < symbols.length; i++) ...[
              _buildPnlChart(symbols[i]),
              if (i < symbols.length - 1) const SizedBox(height: 12),
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
        if (data.isEmpty) {
          return _infoCard('Establishing secure connection for $symbol...');
        }
        final spots = List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i].dailyPnl.toDouble()));
        final isPositive = data.last.dailyPnl >= data.first.dailyPnl;
        final color = isPositive ? const Color(0xFF00FFA3) : const Color(0xFFFF4D4D);

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(symbol, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white, letterSpacing: 1)),
                      const Text('30-DAY PERFORMANCE TRENDS', style: TextStyle(fontSize: 10, color: Colors.white38, letterSpacing: 0.5)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      '${isPositive ? "+" : ""}${data.last.dailyPnl.toStringAsFixed(2)}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16),
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
                SizedBox(
                  height: 120,
                  child: LineChart(LineChartData(
                    gridData: const FlGridData(show: false),
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
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true, 
                        gradient: LinearGradient(
                          colors: [color.withOpacity(0.2), color.withOpacity(0.01)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      ),
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
        if (data.isEmpty) return _infoCard('Analyzing market liquidity...');
        final colors = [const Color(0xFF00D1FF), const Color(0xFF00FFA3), const Color(0xFFFFD700), const Color(0xFFFF6B6B), const Color(0xFFDA70D6)];
        final maxVol = data.fold(0.0, (m, d) => d.volume > m ? d.volume : m);

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SECTOR VOLUME DISTRIBUTION', style: TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              SizedBox(
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
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(data[idx].symbol, style: const TextStyle(fontSize: 9, color: Colors.white54, fontWeight: FontWeight.bold)),
                        );
                      },
                    )),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(data.length, (i) => BarChartGroupData(
                    x: i,
                    barRods: [BarChartRodData(
                      toY: data[i].volume, 
                      color: colors[i % colors.length], 
                      width: 16, 
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4))
                    )],
                  )),
                )),
              ),
            ],
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
        if (data.isEmpty) return _infoCard('Aggregating market capitalizations...');
        final colors = [const Color(0xFF00D1FF), const Color(0xFF00FFA3), Colors.orange, Colors.purple, Colors.red];
        final total = data.fold(0.0, (s, d) => s + d.volume);
        if (total == 0) return _infoCard('No market cap data found.');

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CAPITALIZATION EXPOSURE', style: TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              SizedBox(
                height: 220,
                child: PieChart(PieChartData(
                  sectionsSpace: 4,
                  centerSpaceRadius: 40,
                  sections: List.generate(data.length, (i) {
                    final pct = (data[i].volume / total * 100).toStringAsFixed(1);
                    return PieChartSectionData(
                      color: colors[i % colors.length],
                      value: data[i].volume,
                      title: '${data[i].symbol}\n$pct%',
                      radius: 80,
                      titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                    );
                  }),
                )),
              ),
            ],
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
        if (behavior == null) return _infoCard('Awaiting architecture status...');
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            _metricCard('Data Engine', behavior.status, const Color(0xFF00D1FF)),
            _metricCard('Tracked Symbols', '${behavior.symbolsTracked}', const Color(0xFF00FFA3)),
            _metricCard('Sync Points', '${(behavior.totalDataPoints / 1000).toStringAsFixed(1)}K', Colors.orangeAccent),
            _metricCard('System Uptime', '${(behavior.uptime / 3600).toStringAsFixed(1)} Hrs', Colors.purpleAccent),
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
