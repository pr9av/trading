import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/websocket_service.dart';
import 'home_screen.dart';
import 'market_screen.dart';
import 'watchlist_screen.dart';
import 'analytics_screen.dart';
import 'compare_screen.dart';
import 'chat_screen.dart';

// Provide WebSocketService (this keeps it active across tabs)
final websocketProvider = ChangeNotifierProvider<WebSocketService>((ref) {
  final ws = WebSocketService();
  ws.connect();
  ref.onDispose(() => ws.disconnect());
  return ws;
});

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    MarketScreen(),
    WatchlistScreen(),
    CompareScreen(),
    ChatScreen(),
  ];

  @override
  void initState() {
    super.initState();
    ref.read(websocketProvider); // Wake up WS on app start
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search_outlined), selectedIcon: Icon(Icons.search), label: 'Markets'),
          NavigationDestination(icon: Icon(Icons.bookmark_border), selectedIcon: Icon(Icons.bookmark), label: 'Watchlist'),
          NavigationDestination(icon: Icon(Icons.compare_arrows_outlined), selectedIcon: Icon(Icons.compare_arrows), label: 'Compare'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'AI Chat'),
        ],
      ),
    );
  }
}
