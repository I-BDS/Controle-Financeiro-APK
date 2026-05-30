import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'analise_screen.dart';
import 'recebiveis_screen.dart';

class KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const KeepAliveWrapper({required this.child, super.key});

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}

class MainScreen extends StatefulWidget {
  final VoidCallback? onToggleTheme;

  const MainScreen({super.key, this.onToggleTheme});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 1;
  final _analiseKey = GlobalKey<AnaliseScreenState>();
  final _homeKey = GlobalKey<HomeScreenState>();
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentIndex = index);
    if (index == 1) _homeKey.currentState?.reload();
    if (index == 2) _analiseKey.currentState?.reload();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    if (index == 1) _homeKey.currentState?.reload();
    if (index == 2) _analiseKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const PageScrollPhysics(),
        children: [
          KeepAliveWrapper(
            child: RecebiveisScreen(onTransacaoChanged: _onTransacaoChanged),
          ),
          KeepAliveWrapper(
            child: HomeScreen(
              key: _homeKey,
              onTransacaoChanged: _onTransacaoChanged,
              onToggleTheme: widget.onToggleTheme,
            ),
          ),
          KeepAliveWrapper(
            child: AnaliseScreen(key: _analiseKey),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabChanged,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Recebíveis',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Carteira',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Análise',
          ),
        ],
      ),
    );
  }

  void _onTransacaoChanged() {
    _homeKey.currentState?.reload();
    _analiseKey.currentState?.reload();
  }
}
