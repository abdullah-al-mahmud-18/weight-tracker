import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'providers/providers.dart';
import 'ui/bmi/bmi_page.dart';
import 'ui/data/data_page.dart';
import 'ui/history/history_page.dart';
import 'ui/home/home_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weight Tracker',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}

/// Bottom-navigation shell holding the four pages.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  int _index = 0;

  static const _titles = ['Weight Tracker', 'History', 'BMI', 'Data'];
  static const _pages = [HomePage(), HistoryPage(), BmiPage(), DataPage()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // "Today" may have changed while the app was in the background.
    if (state == AppLifecycleState.resumed) {
      ref.read(entryActionsProvider).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          FocusScope.of(context).unfocus();
          setState(() => _index = i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_weight_outlined),
            selectedIcon: Icon(Icons.monitor_weight),
            label: 'BMI',
          ),
          NavigationDestination(
            icon: Icon(Icons.import_export_outlined),
            selectedIcon: Icon(Icons.import_export),
            label: 'Data',
          ),
        ],
      ),
    );
  }
}
