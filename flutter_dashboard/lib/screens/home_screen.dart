import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/websocket_service.dart';
import 'market_screen.dart';
import 'portfolio_screen.dart';
import 'order_history_screen.dart';
import 'signals_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const MarketScreen(),
    const PortfolioScreen(),
    const OrderHistoryScreen(),
    const SignalsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Initialize WebSocket connection on home startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WebSocketService>(context, listen: false).connect();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.auto_graph_rounded, color: Color(0xFF00D1FF)),
            const SizedBox(width: 8),
            Text(
              'BLAUPLUG',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontSize: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
          ),
          PopupMenuButton(
            icon: const Icon(Icons.account_circle_outlined),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: Text('User: ${auth.userId?.substring(0, 8)}...'),
              ),
              PopupMenuItem(
                onTap: () => auth.logout(),
                child: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.show_chart_rounded),
            label: 'Market',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Portfolio',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.psychology_rounded),
            label: 'Signals',
          ),
        ],
      ),
    );
  }
}
