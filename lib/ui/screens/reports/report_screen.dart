import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cassa1/logic/providers/transaction_provider.dart';
import 'package:cassa1/logic/providers/subject_provider.dart';
import 'package:cassa1/logic/providers/group_provider.dart';
import 'package:cassa1/logic/providers/entry_provider.dart';
import 'package:cassa1/utils/icon_helper.dart';
import 'package:cassa1/utils/constants.dart';
import 'package:cassa1/data/models/transaction.dart';
import 'package:cassa1/data/models/subject.dart';
import 'package:cassa1/data/models/group.dart';
import 'package:cassa1/data/models/entry.dart';

enum _ReportView { group, entry }

class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final subjectsAsync = ref.watch(subjectsProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final entriesAsync = ref.watch(entriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Errore: $error')),
        data: (transactions) {
          return subjectsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Errore: $error')),
            data: (subjects) {
              return groupsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Errore: $error')),
                data: (groups) {
                  return entriesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(child: Text('Errore: $error')),
                    data: (entries) => _ReportContent(
                      transactions: transactions,
                      subjects: subjects,
                      groups: groups,
                      entries: entries,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ReportContent extends StatefulWidget {
  final List<AppTransaction> transactions;
  final List<Subject> subjects;
  final List<Group> groups;
  final List<Entry> entries;

  const _ReportContent({
    required this.transactions,
    required this.subjects,
    required this.groups,
    required this.entries,
  });

  @override
  _ReportContentState createState() => _ReportContentState();
}

class _ReportContentState extends State<_ReportContent> {
  late int _selectedYear;
  int? _selectedMonth;
  _ReportView _view = _ReportView.group;

  final _colors = [
    Color(0xFFEF5350),
    Color(0xFFAB47BC),
    Color(0xFF5C6BC0),
    Color(0xFF26A69A),
    Color(0xFFFFA726),
    Color(0xFF8D6E63),
    Color(0xFFEC407A),
    Color(0xFF66BB6A),
    Color(0xFF42A5F5),
    Color(0xFFFFEE58),
  ];

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
  }

  List<int> get _availableYears {
    final years = <int>{};
    for (final t in widget.transactions) {
      years.add(t.date.year);
    }
    if (years.isEmpty) years.add(DateTime.now().year);
    return years.toList()..sort();
  }

  List<AppTransaction> get _filteredTransactions {
    return widget.transactions.where((t) {
      if (t.type != TransactionType.expense) return false;
      if (t.date.year != _selectedYear) return false;
      if (_selectedMonth != null && t.date.month != _selectedMonth) return false;
      return true;
    }).toList();
  }

  Map<String, double> _calcByGroup() {
    final map = <String, double>{};
    for (final t in _filteredTransactions) {
      final entry = widget.entries.where((e) => e.id == t.entryId).firstOrNull;
      if (entry == null) continue;
      map[entry.groupId] = (map[entry.groupId] ?? 0) + t.amount;
    }
    return map;
  }

  Map<String, double> _calcByEntry() {
    final map = <String, double>{};
    for (final t in _filteredTransactions) {
      if (t.entryId == null) continue;
      map[t.entryId!] = (map[t.entryId!] ?? 0) + t.amount;
    }
    return map;
  }

  String _monthName(int month) => DateFormat('MMMM', 'it_IT').format(DateTime(2024, month));

  Color _colorForIndex(int index) => _colors[index % _colors.length];

  @override
  Widget build(BuildContext context) {
    final years = _availableYears;
    final txs = _filteredTransactions;
    final total = txs.fold<double>(0, (sum, t) => sum + t.amount);

    final Map<String, double> data;
    final List<_ItemInfo> items;

    if (_view == _ReportView.group) {
      data = _calcByGroup();
      final sorted = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      items = sorted.map((e) {
        final idx = sorted.indexOf(e);
        final group = widget.groups.where((g) => g.id == e.key).firstOrNull;
        return _ItemInfo(
          id: e.key,
          label: group?.name ?? 'Gruppo eliminato',
          amount: e.value,
          color: _colorForIndex(idx),
          icon: group?.icon ?? 'folder',
        );
      }).toList();
    } else {
      data = _calcByEntry();
      final sorted = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      items = sorted.map((e) {
        final idx = sorted.indexOf(e);
        final entry = widget.entries.where((en) => en.id == e.key).firstOrNull;
        return _ItemInfo(
          id: e.key,
          label: entry?.name ?? 'Voce eliminata',
          amount: e.value,
          color: _colorForIndex(idx),
          icon: entry?.icon ?? 'receipt',
          subtitle: entry != null
              ? widget.groups.where((g) => g.id == entry.groupId).firstOrNull?.name
              : null,
        );
      }).toList();
    }

    final periodLabel = _selectedMonth != null
        ? '${_monthName(_selectedMonth!)} $_selectedYear'
        : 'Anno $_selectedYear';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Filters row
        Row(
          children: [
            Expanded(
              child: DropdownButton<int>(
                value: _selectedYear,
                isExpanded: true,
                hint: const Text('Anno'),
                items: years.map((y) {
                  return DropdownMenuItem(value: y, child: Text(y.toString()));
                }).toList(),
                onChanged: (v) => setState(() => _selectedYear = v!),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<int?>(
                value: _selectedMonth,
                isExpanded: true,
                hint: const Text('Tutto l\'anno'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Tutto l\'anno'),
                  ),
                  ...List.generate(12, (i) {
                    final m = i + 1;
                    return DropdownMenuItem<int?>(
                      value: m,
                      child: Text(_monthName(m)),
                    );
                  }),
                ],
                onChanged: (v) => setState(() => _selectedMonth = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // View toggle
        SegmentedButton<_ReportView>(
          segments: const [
            ButtonSegment(value: _ReportView.group, label: Text('Gruppo')),
            ButtonSegment(value: _ReportView.entry, label: Text('Voce')),
          ],
          selected: {_view},
          onSelectionChanged: (set) => setState(() => _view = set.first),
        ),
        const SizedBox(height: 16),
        // Total
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(periodLabel, style: Theme.of(context).textTheme.titleSmall),
            Text(
              '€ ${total.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.expenseColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Pie chart
        if (items.isNotEmpty)
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                sections: items.asMap().entries.map((e) {
                  final item = e.value;
                  return PieChartSectionData(
                    value: item.amount,
                    title: '${((item.amount / total) * 100).toStringAsFixed(1)}%',
                    color: item.color,
                    radius: 90,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        const SizedBox(height: 16),
        // List
        if (items.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Nessuna uscita nel periodo',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          )
        else
          ...items.map((item) => _buildCompactItem(context, item)),
      ],
    );
  }

  Widget _buildCompactItem(BuildContext context, _ItemInfo item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              IconHelper.getIconData(item.icon),
              size: 16,
              color: item.color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.subtitle != null)
                  Text(
                    item.subtitle!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '€ ${item.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.expenseColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemInfo {
  final String id;
  final String label;
  final double amount;
  final Color color;
  final String icon;
  final String? subtitle;

  _ItemInfo({
    required this.id,
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    this.subtitle,
  });
}
