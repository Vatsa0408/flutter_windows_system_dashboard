import 'package:fluent_ui/fluent_ui.dart';

import '../dashboard/dashboard_page.dart';
import '../processes/process_manager_page.dart';
import '../settings/settings_page.dart';
import '../utilities/utilities_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      titleBar: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        child: Text(
          'Windows System Dashboard',
          style: FluentTheme.of(context).typography.subtitle,
        ),
      ),
      pane: NavigationPane(
        selected: _selectedIndex,
        onChanged: (index) => setState(() => _selectedIndex = index),
        displayMode: PaneDisplayMode.auto,
        items: [
          PaneItem(
            icon: const Icon(FluentIcons.home),
            title: const Text('Dashboard'),
            body: const DashboardPage(),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.processing),
            title: const Text('Processes'),
            body: const ProcessManagerPage(),
          ),
          PaneItem(
            icon: const Icon(FluentIcons.toolbox),
            title: const Text('Utilities'),
            body: const UtilitiesPage(),
          ),
        ],
        footerItems: [
          PaneItem(
            icon: const Icon(FluentIcons.settings),
            title: const Text('Settings'),
            body: const SettingsPage(),
          ),
        ],
      ),
    );
  }
}
