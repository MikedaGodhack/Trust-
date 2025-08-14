
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const IRSRefundTrackerApp());
}

class IRSRefundTrackerApp extends StatelessWidget {
  const IRSRefundTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IRS Refund Tracker',
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class RefundModel {
  DateTime? expectedDeposit;
  List<TranscriptEntry> entries;

  RefundModel({this.expectedDeposit, required this.entries});

  Map<String, dynamic> toJson() => {
        'expectedDeposit': expectedDeposit?.toIso8601String(),
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  static RefundModel fromJson(Map<String, dynamic> json) => RefundModel(
        expectedDeposit: json['expectedDeposit'] != null
            ? DateTime.parse(json['expectedDeposit'])
            : null,
        entries: (json['entries'] as List<dynamic>? ?? [])
            .map((e) => TranscriptEntry.fromJson(e))
            .toList(),
      );
}

class TranscriptEntry {
  String code;
  String description;
  DateTime date;
  double amount;

  TranscriptEntry({
    required this.code,
    required this.description,
    required this.date,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'description': description,
        'date': date.toIso8601String(),
        'amount': amount,
      };

  static TranscriptEntry fromJson(dynamic json) => TranscriptEntry(
        code: json['code'],
        description: json['description'],
        date: DateTime.parse(json['date']),
        amount: (json['amount'] as num).toDouble(),
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;
  RefundModel _model = RefundModel(expectedDeposit: null, entries: []);
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString('refundModel');
    setState(() {
      if (raw != null) {
        _model = RefundModel.fromJson(jsonDecode(raw));
      } else {
        _model = RefundModel(expectedDeposit: null, entries: []);
      }
    });
  }

  Future<void> _save() async {
    await _prefs.setString('refundModel', jsonEncode(_model.toJson()));
  }

  void _updateExpected(DateTime? dt) async {
    setState(() => _model.expectedDeposit = dt);
    await _save();
  }

  void _addEntry(TranscriptEntry e) async {
    setState(() => _model.entries.add(e));
    await _save();
  }

  void _deleteEntry(int i) async {
    setState(() => _model.entries.removeAt(i));
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      StatusTab(model: _model, onPickDate: _updateExpected),
      TimelineTab(entries: _model.entries, onDelete: _deleteEntry),
      CodesTab(onAdd: _addEntry),
      SettingsTab(
        model: _model,
        onExport: () => _prefs.getString('refundModel') ?? '',
        onImport: (s) async {
          try {
            final m = RefundModel.fromJson(jsonDecode(s));
            setState(() => _model = m);
            await _save();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Import successful')),
            );
          } catch (_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Import failed: bad JSON')),
            );
          }
        },
        onReset: () async {
          setState(() => _model = RefundModel(expectedDeposit: null, entries: []));
          await _save();
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('IRS Refund Tracker')),
      body: pages[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.check_circle_outline), label: 'Status'),
          NavigationDestination(icon: Icon(Icons.timeline), label: 'Timeline'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Codes'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
      ),
    );
  }
}

class StatusTab extends StatelessWidget {
  final RefundModel model;
  final void Function(DateTime?) onPickDate;
  const StatusTab({super.key, required this.model, required this.onPickDate});

  String _statusFromCodes(List<TranscriptEntry> entries) {
    // Very simple inference
    final codes = entries.map((e) => e.code).toSet();
    if (codes.contains('846')) return 'Refund issued (TC 846 present)';
    if (codes.contains('570')) return 'Account on hold (TC 570)';
    if (codes.contains('971')) return 'Notice issued (TC 971)';
    if (codes.contains('150')) return 'Return processed (TC 150)';
    if (codes.isEmpty) return 'No codes entered yet';
    return 'Processing';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final expected = model.expectedDeposit;
    Duration? remaining = expected != null ? expected.difference(now) : null;
    final status = _statusFromCodes(model.entries);
    final fmt = DateFormat.yMMMMd();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current status', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(status),
          const Divider(height: 32),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Expected deposit date', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(expected == null ? 'Not set' : fmt.format(expected)),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 2),
                    initialDate: expected ?? now,
                  );
                  onPickDate(picked);
                },
                child: const Text('Set'),
              )
            ],
          ),
          const SizedBox(height: 16),
          if (remaining != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Countdown', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(remaining.isNegative
                        ? 'Target date passed.'
                        : '${remaining.inDays} days, ${remaining.inHours % 24} hours remaining'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text('Quick tips', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('• Watch for TC 846 for refund issued.'),
          const Text('• If TC 570 appears, expect a review hold.'),
          const Text('• TC 971 means a notice was (or will be) mailed.'),
        ],
      ),
    );
  }
}

class TimelineTab extends StatelessWidget {
  final List<TranscriptEntry> entries;
  final void Function(int) onDelete;
  const TimelineTab({super.key, required this.entries, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd();
    final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));

    if (sorted.isEmpty) {
      return const Center(child: Text('No events yet. Add transcript codes in the Codes tab.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, i) {
        final e = sorted[i];
        return Dismissible(
          key: ValueKey('${e.code}-${e.date.toIso8601String()}-$i'),
          background: Container(color: Colors.redAccent),
          onDismissed: (_) => onDelete(entries.indexOf(e)),
          child: ListTile(
            leading: CircleAvatar(child: Text(e.code)),
            title: Text(e.description),
            subtitle: Text('${fmt.format(e.date)} • \$${e.amount.toStringAsFixed(2)}'),
          ),
        );
      },
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemCount: sorted.length,
    );
  }
}

class CodesTab extends StatefulWidget {
  final void Function(TranscriptEntry) onAdd;
  const CodesTab({super.key, required this.onAdd});

  @override
  State<CodesTab> createState() => _CodesTabState();
}

class _CodesTabState extends State<CodesTab> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _codeCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Transcript Code', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _codeCtrl,
              decoration: const InputDecoration(
                labelText: 'Code (e.g., 150, 806, 570, 971, 290, 846)',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Enter a code' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Enter a description' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount (use negative for credits)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter amount (use 0 if N/A)';
                      final d = double.tryParse(v);
                      return (d == null) ? 'Invalid number' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2015),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  child: Text(DateFormat.yMMMd().format(_date)),
                )
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  final entry = TranscriptEntry(
                    code: _codeCtrl.text.trim(),
                    description: _descCtrl.text.trim(),
                    date: _date,
                    amount: double.tryParse(_amountCtrl.text.trim()) ?? 0.0,
                  );
                  widget.onAdd(entry);
                  _codeCtrl.clear();
                  _descCtrl.clear();
                  _amountCtrl.clear();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code added')),
                  );
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          ],
        ),
      ),
    );
  }
}

class SettingsTab extends StatefulWidget {
  final RefundModel model;
  final String Function() onExport;
  final Future<void> Function(String) onImport;
  final Future<void> Function() onReset;

  const SettingsTab({
    super.key,
    required this.model,
    required this.onExport,
    required this.onImport,
    required this.onReset,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final _jsonCtrl = TextEditingController();

  @override
  void dispose() {
    _jsonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Backup / Restore', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton(
              onPressed: () {
                final data = widget.onExport();
                _jsonCtrl.text = data;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Data exported below')),
                );
              },
              child: const Text('Export'),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () async {
                await widget.onImport(_jsonCtrl.text);
              },
              child: const Text('Import'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _jsonCtrl,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: 'Your JSON export will appear here. Paste here to import.',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        Text('Danger zone', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () async {
            await widget.onReset();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All data cleared.')),
              );
            }
          },
          child: const Text('Clear all data'),
        )
      ],
    );
  }
}
