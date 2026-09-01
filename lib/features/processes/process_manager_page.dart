import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'process_info.dart';
import 'process_manager_bloc.dart';

class ProcessManagerPage extends StatefulWidget {
  const ProcessManagerPage({super.key});

  @override
  State<ProcessManagerPage> createState() => _ProcessManagerPageState();
}

class _ProcessManagerPageState extends State<ProcessManagerPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: const Text('Process manager'),
        commandBar: Button(
          onPressed: () => context
              .read<ProcessManagerBloc>()
              .add(const ProcessRefreshRequested()),
          child: const Row(children: [
            Icon(FluentIcons.refresh),
            SizedBox(width: 8),
            Text('Refresh'),
          ]),
        ),
      ),
      children: [
        BlocBuilder<ProcessManagerBloc, ProcessManagerState>(
          builder: (context, state) {
            final processes = state.visibleProcesses;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.status == ProcessManagerStatus.loading ||
                    state.actionStatus == ProcessActionStatus.running)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: ProgressBar(),
                  ),
                if (state.errorMessage != null)
                  _messageBar(state.errorMessage!, true),
                if (state.actionMessage != null)
                  _messageBar(
                    state.actionMessage!,
                    state.actionStatus == ProcessActionStatus.failure,
                  ),
                _toolbar(context, state),
                const SizedBox(height: 14),
                Text(
                  '${processes.length} of ${state.processes.length} processes',
                  style: FluentTheme.of(context).typography.caption,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 520,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _ProcessList(
                          processes: processes,
                          selectedPid: state.selectedProcess?.pid,
                          onSelected: (process) => context
                              .read<ProcessManagerBloc>()
                              .add(ProcessSelected(process)),
                        ),
                      ),
                      if (MediaQuery.sizeOf(context).width >= 980) ...[
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 340,
                          child: _ProcessDetails(
                            process: state.selectedProcess,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (MediaQuery.sizeOf(context).width < 980 &&
                    state.selectedProcess != null) ...[
                  const SizedBox(height: 16),
                  _ProcessDetails(process: state.selectedProcess),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _toolbar(BuildContext context, ProcessManagerState state) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 300,
          child: TextBox(
            controller: _searchController,
            placeholder: 'Search name, PID, or path',
            prefix: const Padding(
              padding: EdgeInsets.only(left: 10),
              child: Icon(FluentIcons.search),
            ),
            onChanged: (value) => context
                .read<ProcessManagerBloc>()
                .add(ProcessSearchChanged(value)),
          ),
        ),
        ComboBox<ProcessSortField>(
          value: state.sortField,
          items: ProcessSortField.values
              .map((field) => ComboBoxItem(
                    value: field,
                    child: Text(_sortLabel(field)),
                  ))
              .toList(),
          onChanged: (field) {
            if (field != null) {
              context
                  .read<ProcessManagerBloc>()
                  .add(ProcessSortChanged(field));
            }
          },
        ),
        Button(
          onPressed: () => context
              .read<ProcessManagerBloc>()
              .add(const ProcessSortDirectionToggled()),
          child: Text(state.sortAscending ? 'Ascending' : 'Descending'),
        ),
        ComboBox<ProcessRefreshInterval>(
          value: state.refreshInterval,
          items: ProcessRefreshInterval.values
              .map((interval) => ComboBoxItem(
                    value: interval,
                    child: Text(interval.label),
                  ))
              .toList(),
          onChanged: (interval) {
            if (interval != null) {
              context
                  .read<ProcessManagerBloc>()
                  .add(ProcessRefreshIntervalChanged(interval));
            }
          },
        ),
        ToggleSwitch(
          checked: state.status != ProcessManagerStatus.paused,
          content: const Text('Auto refresh'),
          onChanged: (enabled) => context.read<ProcessManagerBloc>().add(
                enabled
                    ? const ProcessManagerStarted()
                    : const ProcessManagerStopped(),
              ),
        ),
      ],
    );
  }

  Widget _messageBar(String message, bool error) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InfoBar(
          title: Text(error ? 'Process manager issue' : 'Action completed'),
          content: Text(message),
          severity: error ? InfoBarSeverity.error : InfoBarSeverity.success,
        ),
      );

  String _sortLabel(ProcessSortField field) => switch (field) {
        ProcessSortField.name => 'Name',
        ProcessSortField.pid => 'PID',
        ProcessSortField.cpu => 'CPU usage',
        ProcessSortField.memory => 'Memory usage',
        ProcessSortField.startTime => 'Start time',
        ProcessSortField.status => 'Status',
      };
}

class _ProcessList extends StatelessWidget {
  const _ProcessList({
    required this.processes,
    required this.selectedPid,
    required this.onSelected,
  });

  final List<ProcessInfo> processes;
  final int? selectedPid;
  final ValueChanged<ProcessInfo> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const _ProcessHeader(),
          const Divider(),
          Expanded(
            child: processes.isEmpty
                ? const Center(child: Text('No matching processes.'))
                : ListView.builder(
                    itemCount: processes.length,
                    itemExtent: 54,
                    itemBuilder: (context, index) {
                      final process = processes[index];
                      return _ProcessRow(
                        process: process,
                        selected: process.pid == selectedPid,
                        onPressed: () => onSelected(process),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProcessHeader extends StatelessWidget {
  const _ProcessHeader();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 42,
        child: Row(children: [
          SizedBox(width: 16),
          Expanded(flex: 4, child: Text('Process')),
          SizedBox(width: 80, child: Text('PID')),
          SizedBox(width: 82, child: Text('CPU')),
          SizedBox(width: 100, child: Text('Memory')),
          SizedBox(width: 100, child: Text('Status')),
        ]),
      );
}

class _ProcessRow extends StatelessWidget {
  const _ProcessRow({
    required this.process,
    required this.selected,
    required this.onPressed,
  });
  final ProcessInfo process;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return HoverButton(
      onPressed: onPressed,
      builder: (context, states) {
        final color = selected
            ? FluentTheme.of(context).accentColor.withValues(alpha: 0.16)
            : states.isHovered
                ? FluentTheme.of(context)
                    .resources
                    .subtleFillColorSecondary
                : Colors.transparent;
        return Container(
          color: color,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(
              flex: 4,
              child: Row(children: [
                if (process.isCritical) ...[
                  const Icon(FluentIcons.lock, size: 14),
                  const SizedBox(width: 7),
                ],
                Expanded(
                  child: Text(
                    process.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
            SizedBox(width: 80, child: Text('${process.pid}')),
            SizedBox(
              width: 82,
              child: Text('${process.cpuPercent.toStringAsFixed(1)}%'),
            ),
            SizedBox(
              width: 100,
              child: Text('${process.memoryMb.toStringAsFixed(1)} MB'),
            ),
            SizedBox(width: 100, child: Text(process.statusLabel)),
          ]),
        );
      },
    );
  }
}

class _ProcessDetails extends StatelessWidget {
  const _ProcessDetails({required this.process});
  final ProcessInfo? process;

  @override
  Widget build(BuildContext context) {
    final value = process;
    if (value == null) {
      return const Card(
        padding: EdgeInsets.all(20),
        child: Center(child: Text('Select a process to view details.')),
      );
    }

    return Card(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value.name, style: FluentTheme.of(context).typography.subtitle),
            const SizedBox(height: 16),
            _detail('Process ID', '${value.pid}'),
            _detail('CPU usage', '${value.cpuPercent.toStringAsFixed(2)}%'),
            _detail('Memory', '${value.memoryMb.toStringAsFixed(2)} MB'),
            _detail('Status', value.statusLabel),
            _detail('Started', _date(value.startTime)),
            _detail('Threads', '${value.threadCount}'),
            _detail('Handles', '${value.handleCount}'),
            _detail('Executable', value.executablePath ?? 'Unavailable'),
            if (value.isCritical)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: InfoBar(
                  title: Text('Protected process'),
                  content: Text('Termination and restart are disabled.'),
                  severity: InfoBarSeverity.warning,
                ),
              ),
            Wrap(spacing: 8, runSpacing: 8, children: [
              Button(
                onPressed: value.executablePath == null
                    ? null
                    : () => context.read<ProcessManagerBloc>().add(
                          ProcessFileLocationRequested(value),
                        ),
                child: const Text('Open location'),
              ),
              Button(
                onPressed: () => _copy(context, '${value.pid}', 'PID copied.'),
                child: const Text('Copy PID'),
              ),
              Button(
                onPressed: value.executablePath == null
                    ? null
                    : () => _copy(
                          context,
                          value.executablePath!,
                          'Path copied.',
                        ),
                child: const Text('Copy path'),
              ),
              Button(
                onPressed: value.isCritical || value.executablePath == null
                    ? null
                    : () => _confirm(context, value, restart: true),
                child: const Text('Restart'),
              ),
              FilledButton(
                onPressed: value.isCritical
                    ? null
                    : () => _confirm(context, value, restart: false),
                child: const Text('End process'),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 2),
            SelectableText(value),
          ],
        ),
      );

  String _date(DateTime? date) =>
      date == null ? 'Unavailable' : date.toString().split('.').first;

  Future<void> _copy(BuildContext context, String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      displayInfoBar(context, builder: (context, close) => InfoBar(
            title: Text(message),
            severity: InfoBarSeverity.success,
          ));
    }
  }

  Future<void> _confirm(
    BuildContext context,
    ProcessInfo process, {
    required bool restart,
  }) async {
    final controller = TextEditingController();
    var typedName = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => ContentDialog(
          title: Text(restart ? 'Restart process?' : 'End process?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                restart
                    ? 'This ends ${process.name} and launches its executable again. Unsaved work may be lost.'
                    : 'Ending ${process.name} may cause unsaved work to be lost.',
              ),
              const SizedBox(height: 12),
              Text('Type ${process.name} to continue:'),
              const SizedBox(height: 8),
              TextBox(
                controller: controller,
                autofocus: true,
                onChanged: (value) =>
                    setDialogState(() => typedName = value.trim()),
              ),
            ],
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: typedName == process.name
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: Text(restart ? 'Restart' : 'End process'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();

    if (confirmed == true && context.mounted) {
      context.read<ProcessManagerBloc>().add(
            restart
                ? ProcessRestartConfirmed(process)
                : ProcessTerminationConfirmed(process),
          );
    }
  }
}
