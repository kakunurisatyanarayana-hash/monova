import 'package:monova_app/core/input_rules.dart';
import 'package:flutter/material.dart';

import '../../core/calculator_engine.dart';
import '../../core/local_store.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

const calcHistoryKey = 'monova.calcHistory';

/// Full calculator: basic and scientific keypads, memory, history, degree/radian modes.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final _engine = CalculatorEngine();
  LocalStore? _store;
  String _expression = '';
  String _result = '0';
  bool _error = false;
  bool _scientific = false;
  bool _justEvaluated = false;
  double _memory = 0;
  final List<({String expr, String result})> _history = [];

  @override
  void initState() {
    super.initState();
    LocalStore.open().then((store) {
      if (!mounted) return;
      _store = store;
      final saved = store.readList(calcHistoryKey);
      setState(() {
        _history.addAll(saved.map((e) => (expr: '${e['expr']}', result: '${e['result']}')));
      });
    });
  }

  Future<void> _saveHistory() async {
    await _store?.writeList(calcHistoryKey, [for (final h in _history) {'expr': h.expr, 'result': h.result}]);
  }

  void _press(String key) {
    setState(() {
      _error = false;
      if (key == 'C') {
        _expression = '';
        _result = '0';
        _justEvaluated = false;
        return;
      }
      if (key == '⌫') {
        if (_justEvaluated) {
          _expression = '';
          _result = '0';
          _justEvaluated = false;
        } else if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
        return;
      }
      if (key == '=') {
        _evaluate();
        return;
      }
      if (key == 'DEG' || key == 'RAD') {
        _engine.degrees = key == 'DEG';
        return;
      }
      if (_justEvaluated && RegExp(r'^[0-9.(πe]|sin|cos|tan|log|ln|√|cbrt|asin|acos|atan|abs|exp$').hasMatch(key)) {
        _expression = '';
      }
      _justEvaluated = false;
      _expression += _insertText(key);
      _livePreview();
    });
  }

  String _insertText(String key) => switch (key) {
        '×' => '*',
        '÷' => '/',
        '−' => '-',
        'π' => 'pi',
        '√' => 'sqrt(',
        'sin' || 'cos' || 'tan' || 'asin' || 'acos' || 'atan' || 'log' || 'ln' || 'cbrt' || 'abs' || 'exp' => '$key(',
        'x²' => '^2',
        'xʸ' => '^',
        'x!' => '!',
        _ => key,
      };

  void _livePreview() {
    try {
      _result = CalculatorEngine.format(_engine.evaluate(_expression));
    } catch (_) {
      // Incomplete input is normal while typing; the preview simply stays where it was.
    }
  }

  void _evaluate() {
    if (_expression.trim().isEmpty) return;
    try {
      final value = _engine.evaluate(_expression);
      final text = CalculatorEngine.format(value);
      _history.insert(0, (expr: _expression, result: text));
      if (_history.length > 15) _history.removeLast();
      _saveHistory();
      _result = text;
      _expression = text;
      _justEvaluated = true;
    } on FormatException catch (e) {
      _error = true;
      _result = e.message;
    }
  }

  void _memoryOp(String op) {
    setState(() {
      final current = double.tryParse(_result) ?? 0;
      switch (op) {
        case 'MC':
          _memory = 0;
        case 'MR':
          _expression += CalculatorEngine.format(_memory);
          _livePreview();
        case 'M+':
          _memory += current;
        case 'M-':
          _memory -= current;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final basic = [
      ['C', '⌫', '%', '÷'],
      ['7', '8', '9', '×'],
      ['4', '5', '6', '−'],
      ['1', '2', '3', '+'],
      ['(', '0', '.', '='],
    ];
    final scientific = [
      ['sin', 'cos', 'tan', 'π'],
      ['asin', 'acos', 'atan', 'e'],
      ['log', 'ln', '√', 'cbrt'],
      ['x²', 'xʸ', 'x!', 'abs'],
      ['(', ')', '%', 'exp'],
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculator'),
        actions: [
          IconButton(tooltip: 'History', icon: const Icon(Icons.history_rounded), onPressed: _showHistory),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Row(children: [
                        if (_memory != 0) Text('M', style: TextStyle(color: c.accentStart, fontWeight: FontWeight.w800)),
                        const SizedBox(width: 8),
                        Text(_scientific ? (_engine.degrees ? 'DEG' : 'RAD') : '', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700)),
                      ]),
                      Text(_scientific ? 'Scientific' : 'Basic', style: TextStyle(color: c.muted)),
                    ]),
                    const Spacer(),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(_expression.isEmpty ? ' ' : _expression, style: TextStyle(color: c.muted, fontSize: 20)),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        _result,
                        style: TextStyle(color: _error ? c.expense : c.ink, fontSize: _error ? 20 : 48, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                for (final m in ['MC', 'MR', 'M+', 'M-'])
                  Expanded(child: TextButton(onPressed: () => _memoryOp(m), child: Text(m, style: TextStyle(color: c.accentStart, fontWeight: FontWeight.w700)))),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: SegmentedButton<bool>(
                segments: const [ButtonSegment(value: false, label: Text('Basic')), ButtonSegment(value: true, label: Text('Scientific'))],
                selected: {_scientific},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _scientific = s.first),
              ),
            ),
            if (_scientific)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: Row(children: [
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: const [ButtonSegment(value: 'DEG', label: Text('DEG')), ButtonSegment(value: 'RAD', label: Text('RAD'))],
                      selected: {_engine.degrees ? 'DEG' : 'RAD'},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) => setState(() => _engine.degrees = s.first == 'DEG'),
                    ),
                  ),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                children: [
                  if (_scientific)
                    for (final row in scientific) _keyRow(row, c, science: true),
                  for (final row in basic) _keyRow(row, c),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _keyRow(List<String> keys, MonovaColors c, {bool science = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          for (final k in keys)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _Key(
                  label: k,
                  colors: c,
                  kind: _kindOf(k, science),
                  onTap: () => _press(k),
                ),
              ),
            ),
        ],
      ),
    );
  }

  _KeyKind _kindOf(String k, bool science) {
    if (k == '=') return _KeyKind.primary;
    if (k == 'C' || k == '⌫') return _KeyKind.danger;
    if (k == '÷' || k == '×' || k == '−' || k == '+') return _KeyKind.operator;
    if (science && !RegExp(r'^[0-9.]$').hasMatch(k)) return _KeyKind.function;
    return _KeyKind.number;
  }

  void _showHistory() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: _history.isEmpty
            ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No calculations yet.')))
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final h in _history)
                    ListTile(
                      title: Text(h.expr),
                      trailing: Text('= ${h.result}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      onTap: () {
                        setState(() {
                          _expression = h.result;
                          _result = h.result;
                          _justEvaluated = true;
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                ],
              ),
      ),
    );
  }
}

enum _KeyKind { number, operator, function, primary, danger }

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.colors, required this.kind, required this.onTap});

  final String label;
  final MonovaColors colors;
  final _KeyKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = switch (kind) {
      _KeyKind.primary => null,
      _KeyKind.operator => colors.border,
      _KeyKind.function => colors.raised,
      _KeyKind.danger => colors.raised,
      _KeyKind.number => colors.raised,
    };
    final fg = switch (kind) {
      _KeyKind.primary => colors.onAccent,
      _KeyKind.danger => colors.expense,
      _KeyKind.operator => colors.accentStart,
      _ => colors.ink,
    };
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 52,
        decoration: BoxDecoration(
          gradient: kind == _KeyKind.primary ? colors.aurora : null,
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kind == _KeyKind.primary ? Colors.transparent : colors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: TextStyle(color: fg, fontSize: kind == _KeyKind.function ? 15 : 20, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
    );
  }
}

/// GST calculator: add GST to a base price, or pull GST out of a GST-inclusive price, with CGST/SGST split.
class GstCalculatorScreen extends StatefulWidget {
  const GstCalculatorScreen({super.key});

  @override
  State<GstCalculatorScreen> createState() => _GstCalculatorScreenState();
}

class _GstCalculatorScreenState extends State<GstCalculatorScreen> {
  final _amount = TextEditingController(text: '10000');
  double _rate = 18;
  bool _addGst = true;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final value = double.tryParse(_amount.text.replaceAll(',', '')) ?? 0;
    final gst = _addGst ? value * _rate / 100 : value - value / (1 + _rate / 100);
    final base = _addGst ? value : value - gst;
    final total = _addGst ? value + gst : value;
    return Scaffold(
      appBar: AppBar(title: const Text('GST calculator')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SegmentedButton<bool>(
            segments: const [ButtonSegment(value: true, label: Text('Add GST')), ButtonSegment(value: false, label: Text('Remove GST'))],
            selected: {_addGst},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _addGst = s.first),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: amountFormatters,
            decoration: InputDecoration(labelText: _addGst ? 'Price before GST' : 'Price including GST', prefixText: '₹ '),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          Text('GST rate', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final r in [5, 12, 18, 28])
                ChoiceChip(label: Text('$r%'), selected: _rate == r, onSelected: (_) => setState(() => _rate = r.toDouble())),
            ],
          ),
          const SizedBox(height: 18),
          MonovaCard(
            gradient: c.hero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_addGst ? 'Total with GST' : 'Price before GST', style: TextStyle(color: c.onAccent.withValues(alpha: 0.85))),
                Text('₹ ${(_addGst ? total : base).toStringAsFixed(2)}', style: TextStyle(color: c.onAccent, fontSize: 30, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          MonovaCard(
            child: Column(children: [
              _row('Base amount', base, c),
              _row('GST (${_rate.toStringAsFixed(0)}%)', gst, c),
              _row('CGST (${(_rate / 2).toStringAsFixed(1)}%)', gst / 2, c),
              _row('SGST (${(_rate / 2).toStringAsFixed(1)}%)', gst / 2, c),
              const Divider(),
              _row('Total', total, c, bold: true),
            ]),
          ),
          const SizedBox(height: 8),
          Text('CGST and SGST split applies to intra-state supply. Inter-state supply pays IGST at the full rate.',
              style: TextStyle(color: c.muted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _row(String label, double value, MonovaColors c, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: c.muted, fontWeight: bold ? FontWeight.w800 : FontWeight.w500))),
          Text('₹ ${value.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w700, color: c.ink)),
        ]),
      );
}

