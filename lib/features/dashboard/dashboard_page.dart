import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'dashboard_bloc.dart';
import 'monitoring/system_monitor_bloc.dart';
import 'monitoring/widgets/performance_history_chart.dart';
import 'system_info.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: const Text('System overview'),
        commandBar: Button(
          onPressed: () => context
              .read<DashboardBloc>()
              .add(const DashboardRefreshRequested()),
          child: const Row(
            children: [
              Icon(FluentIcons.refresh),
              SizedBox(width: 8),
              Text('Refresh'),
            ],
          ),
        ),
      ),
      children: [
        const _PerformanceSection(),
        const SizedBox(height: 28),
        Text(
          'System details',
          style: FluentTheme.of(context).typography.subtitle,
        ),
        const SizedBox(height: 12),
        BlocBuilder<DashboardBloc, DashboardState>(
          builder: (context, state) {
            if (state.status == DashboardStatus.loading && state.info == null) {
              return const Center(child: ProgressRing());
            }
            if (state.info == null) {
              return InfoBar(
                title: const Text('Information unavailable'),
                content: Text(state.error ?? 'Waiting for system data.'),
                severity: InfoBarSeverity.warning,
              );
            }
            return _SystemDetails(info: state.info!);
          },
        ),
      ],
    );
  }
}

class _PerformanceSection extends StatelessWidget {
  const _PerformanceSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SystemMonitorBloc, SystemMonitorState>(
      builder: (context, state) {
        final current = state.metrics;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Performance history',
                  style: FluentTheme.of(context).typography.subtitle,
                ),
                ComboBox<MonitorHistoryWindow>(
                  value: state.historyWindow,
                  items: MonitorHistoryWindow.values
                      .map(
                        (window) => ComboBoxItem(
                          value: window,
                          child: Text(window.label),
                        ),
                      )
                      .toList(),
                  onChanged: (window) {
                    if (window != null) {
                      context
                          .read<SystemMonitorBloc>()
                          .add(SystemMonitorWindowChanged(window));
                    }
                  },
                ),
                Button(
                  onPressed: state.history.isEmpty
                      ? null
                      : () => context
                          .read<SystemMonitorBloc>()
                          .add(const SystemMonitorHistoryCleared()),
                  child: const Text('Clear history'),
                ),
                ToggleSwitch(
                  checked: state.isRunning,
                  content: Text(
                    state.isRunning ? 'Monitoring on' : 'Monitoring off',
                  ),
                  onChanged: (enabled) => context
                      .read<SystemMonitorBloc>()
                      .add(
                        enabled
                            ? const SystemMonitorStarted()
                            : const SystemMonitorStopped(),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (state.status == SystemMonitorStatus.loading && current == null)
              const ProgressBar(),
            if (state.error != null) ...[
              InfoBar(
                title: const Text('Monitoring issue'),
                content: Text(state.error!),
                severity: InfoBarSeverity.warning,
              ),
              const SizedBox(height: 14),
            ],
            if (current != null) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth >= 700
                      ? (constraints.maxWidth - 16) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: width,
                        child: _CurrentMetric(
                          title: 'Current CPU',
                          value: current.cpuPercent,
                          detail: _sampleTime(current.sampledAt),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _CurrentMetric(
                          title: 'Current memory',
                          value: current.memoryPercent,
                          detail:
                              '${current.usedMemoryGb.toStringAsFixed(1)} GB '
                              'of ${current.totalMemoryGb.toStringAsFixed(1)} GB',
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
            PerformanceHistoryChart(
              title: 'CPU history',
              history: state.history,
              valueSelector: (sample) => sample.cpuPercent,
              lineColor: Colors.blue,
              average: state.averageCpu,
              maximum: state.maximumCpu,
            ),
            const SizedBox(height: 16),
            PerformanceHistoryChart(
              title: 'Memory history',
              history: state.history,
              valueSelector: (sample) => sample.memoryPercent,
              lineColor: Colors.purple,
              average: state.averageMemory,
              maximum: state.maximumMemory,
            ),
          ],
        );
      },
    );
  }

  static String _sampleTime(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return 'Updated ${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}

class _CurrentMetric extends StatelessWidget {
  const _CurrentMetric({
    required this.title,
    required this.value,
    required this.detail,
  });

  final String title;
  final double value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(0, 100).toDouble();
    return Card(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title)),
              Text('${safeValue.round()}%'),
            ],
          ),
          const SizedBox(height: 12),
          ProgressBar(value: safeValue),
          const SizedBox(height: 8),
          Text(detail),
        ],
      ),
    );
  }
}

class _SystemDetails extends StatelessWidget {
  const _SystemDetails({required this.info});

  final SystemInfo info;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 900
            ? (constraints.maxWidth - 32) / 3
            : constraints.maxWidth >= 560
                ? (constraints.maxWidth - 16) / 2
                : constraints.maxWidth;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _card(width, 'Computer', [info.computer, 'User: ${info.user}']),
            _card(width, 'Operating system', [info.os, info.version]),
            _card(width, 'Processor', [
              info.cpu,
              '${info.cores} logical processors',
            ]),
            _card(width, 'Memory snapshot', [
              '${(info.ramUsage * 100).round()}% used',
              '${info.freeRam.toStringAsFixed(1)} GB free',
            ]),
            _card(width, 'Drive ${info.drive}', [
              '${(info.diskUsage * 100).round()}% used',
              '${info.freeDisk.toStringAsFixed(1)} GB free',
            ]),
            _card(width, 'Session', [
              'Booted: ${_format(info.booted)}',
              'Updated: ${_format(info.updated)}',
            ]),
          ],
        );
      },
    );
  }

  Widget _card(double width, String title, List<String> lines) {
    return SizedBox(
      width: width,
      child: Card(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            const SizedBox(height: 10),
            ...lines.map((line) => Text(line)),
          ],
        ),
      ),
    );
  }

  String _format(DateTime? value) => value == null
      ? 'Unknown'
      : value.toLocal().toString().split('.').first;
}
