import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/local_store.dart';
import '../../core/market/bullion_feed.dart';
import '../../core/market/bullion_repository.dart';
import '../../core/market/jewellery_estimate.dart';
import '../../core/market/jeweller_quotes.dart';
import '../../core/market/mandi_feed.dart';
import '../../core/market/mandi_repository.dart';
import '../../core/market/quote_store.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

const _nationalCity = 'National rate';
const _cityKey = 'monova.market.city';

/// States and union territories, spelled as the mandi source spells them.
const _mandiStates = [
  'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh', 'Goa', 'Gujarat', 'Haryana',
  'Himachal Pradesh', 'Jharkhand', 'Karnataka', 'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur',
  'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana',
  'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal', 'Andaman and Nicobar', 'Chandigarh',
  'Delhi', 'Jammu and Kashmir', 'Ladakh', 'Puducherry',
];

/// Commodities to choose from. Poultry items are included; the source's exact names are confirmed on the first fetch.
// Poultry (egg, chicken, broiler, fish) is switched off for now: the official mandi data does not carry it.
const _mandiCommodities = [
  'Tomato', 'Onion', 'Potato', 'Brinjal', 'Cabbage', 'Carrot', 'Cauliflower', 'Green Chilli', 'Garlic', 'Ginger',
  'Rice', 'Wheat', 'Maize', 'Banana', 'Mango', 'Lemon',
];

/// Cities a person can pick. Each city's rates are the jeweller quotes entered for it, until a paid city feed is added.
const _cities = [
  _nationalCity,
  'Hyderabad', 'Bengaluru', 'Chennai', 'Mumbai', 'Pune', 'Delhi', 'Kolkata', 'Ahmedabad', 'Jaipur', 'Lucknow',
  'Kochi', 'Visakhapatnam', 'Vijayawada', 'Coimbatore', 'Madurai', 'Chandigarh', 'Bhubaneswar', 'Guwahati',
  'Patna', 'Indore', 'Nagpur', 'Surat', 'Mysuru',
];

/// Market rates: the national benchmark, jeweller quotes for each city with their full final cost, history,
/// mandi prices, and what is not available yet. Three tabs keep the page from becoming one long scroll.
class LiveMarketScreen extends StatelessWidget {
  const LiveMarketScreen({super.key, this.repository});

  final BullionRepository? repository;

  @override
  Widget build(BuildContext context) {
    // Two tabs for now. The Coverage tab is hidden until more sources are verified; its code is kept for later.
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Market rates'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Gold & silver'),
              Tab(text: 'Mandi'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _MetalsTab(repository: repository),
            const _MandiTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Gold and silver tab

class _MetalsTab extends StatefulWidget {
  const _MetalsTab({this.repository});

  final BullionRepository? repository;

  @override
  State<_MetalsTab> createState() => _MetalsTabState();
}

class _MetalsTabState extends State<_MetalsTab> {
  static const _staleAfter = Duration(hours: 6);
  static const _weights = [(1.0, '1 g'), (5.0, '5 g'), (10.0, '10 g'), (50.0, '50 g'), (100.0, '100 g'), (1000.0, '1 kg')];
  static const _purities = [('gold_24k', '24K'), ('gold_22k', '22K'), ('gold_18k', '18K')];

  late final BullionRepository _repo = widget.repository ?? BullionRepository();
  List<StoredPrice> _prices = const [];
  List<JewellerQuote> _quotes = const [];
  Map<String, SyncState> _sync = const {};
  bool _loaded = false;
  bool _updating = false;
  String? _message;

  String _metal = 'gold';
  String _purityId = 'gold_24k';
  String _city = _nationalCity;
  String _view = '30';
  final _weight = TextEditingController(text: '10');
  final _making = TextEditingController(text: '12');

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _weight.dispose();
    _making.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final store = await LocalStore.open();
    final saved = store.readList(_cityKey);
    if (saved.isNotEmpty && _cities.contains('${saved.first['city']}')) {
      _city = '${saved.first['city']}';
    }
    await _reload();
    await _autoUpdate();
  }

  Future<void> _reload() async {
    try {
      final prices = await _repo.load();
      final sync = await _repo.syncStates();
      final quotes = await QuoteStore.load();
      if (!mounted) return;
      setState(() {
        _prices = prices;
        _sync = sync;
        _quotes = quotes;
        _loaded = true;
      });
    } catch (e) {
      debugPrint('Market rates load failed: $e');
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _message = 'Saved rates could not be read. Nothing was changed.';
      });
    }
  }

  /// Refreshes the national rate on open when it is more than six hours old, and keeps downloading older days.
  Future<void> _autoUpdate() async {
    if (_updating || !mounted) return;
    final now = DateTime.now().toUtc();
    final times = [_sync['gold']?.lastSuccess, _sync['silver']?.lastSuccess].whereType<DateTime>().toList();
    final stale = times.length < 2 || times.any((t) => now.difference(t) > _staleAfter);
    final pending = await _repo.historyPending();
    if (!stale && !pending) return;
    await _update(rounds: pending ? 6 : 1);
  }

  Future<void> _update({required int rounds}) async {
    if (!mounted) return;
    setState(() {
      _updating = true;
      _message = null;
    });
    String? problem;
    for (var i = 0; i < rounds && mounted; i++) {
      try {
        final report = await _repo.refresh();
        await _reload();
        if (!report.allOk) {
          problem = '${report.failedDatasets.values.join(' ')} Showing the rates saved earlier.';
          break;
        }
      } catch (e) {
        debugPrint('Market rates update failed: $e');
        problem = 'Could not reach the source. Showing the rates saved on this phone.';
        break;
      }
      if (!await _repo.historyPending()) break;
    }
    if (!mounted) return;
    setState(() {
      _updating = false;
      _message = problem;
    });
  }

  Future<void> _setCity(String city) async {
    setState(() => _city = city);
    final store = await LocalStore.open();
    await store.writeList(_cityKey, [
      {'city': city},
    ]);
  }

  List<(String, String)> get _options => _metal == 'gold' ? _purities : const [('silver', 'Silver')];

  String get _selectedId => _options.any((o) => o.$1 == _purityId) ? _purityId : _options.first.$1;

  /// The national benchmark per gram for one product, from the latest stored day.
  double? _nationalPerGram(String productId) {
    final latest = latestAndPrevious(_prices, productId).latest;
    if (latest == null) return null;
    final product = bullionProducts.firstWhere((p) => p.id == productId);
    return perGram(latest.value, product.unit);
  }

  /// The newest jeweller quote for the chosen city and product, when one exists.
  JewellerQuote? _latestQuote(String productId) {
    if (_city == _nationalCity) return null;
    final list = quotesFor(_quotes, _city, productId);
    return list.isEmpty ? null : list.first;
  }

  double _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    if (!_loaded) return const LoadingBox();
    final selected = _selectedId;
    final quote = _latestQuote(selected);
    final national = _nationalPerGram(selected);
    final rate = quote?.perGram ?? national;
    final grams = _num(_weight);
    final JewelleryEstimate? estimate = grams <= 0
        ? null
        : quote != null
            ? quote.costFor(grams)
            : (rate == null ? null : estimateJewellery(perGram: rate, grams: grams, makingPercent: _num(_making)));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _StatusLine(updating: _updating, message: _message, sync: _sync),
        const SizedBox(height: 12),
        _Header(
          metal: _metal,
          city: _city,
          onMetal: (m) => setState(() {
            _metal = m;
            _purityId = m == 'gold' ? 'gold_24k' : 'silver';
          }),
          onCity: _setCity,
        ),
        const SizedBox(height: 14),
        // Equal-width cards: one per purity (or the one silver rate).
        Row(
          children: [
            for (var i = 0; i < _options.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                child: _RateCard(
                  label: _metal == 'gold' ? '${_options[i].$2} gold per gram' : 'Silver per gram',
                  productId: _options[i].$1,
                  prices: _prices,
                  quote: _latestQuote(_options[i].$1),
                  national: _nationalPerGram(_options[i].$1),
                  city: _city,
                  selected: _options[i].$1 == selected,
                  onTap: () => setState(() => _purityId = _options[i].$1),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final calculator = _Calculator(
              options: _options,
              selected: selected,
              onPurity: (id) => setState(() => _purityId = id),
              weight: _weight,
              making: _making,
              weights: _weights,
              quoteInUse: quote != null,
              onChanged: () => setState(() {}),
              onWeight: (w) => setState(() => _weight.text = w == w.roundToDouble() ? w.toStringAsFixed(0) : w.toString()),
            );
            final result = _ResultCard(
              estimate: estimate,
              rate: rate,
              quote: quote,
              city: _city,
              nationalDate: latestAndPrevious(_prices, selected).latest?.date,
            );
            if (constraints.maxWidth >= 640) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: calculator),
                  const SizedBox(width: 12),
                  Expanded(child: result),
                ],
              );
            }
            return Column(children: [calculator, const SizedBox(height: 12), result]);
          },
        ),
        if (_city != _nationalCity) ...[
          const SizedBox(height: 14),
          _QuotesCard(
            city: _city,
            productId: selected,
            label: _options.firstWhere((o) => o.$1 == selected).$2,
            quotes: _quotes,
            prices: _prices,
            grams: grams,
            onAdd: () => _openAddQuote(selected),
            onDelete: _deleteQuote,
          ),
        ],
        const SizedBox(height: 14),
        _HistoryCard(
          prices: _prices,
          productId: selected,
          view: _view,
          onView: (v) => setState(() => _view = v),
        ),
        const SizedBox(height: 14),
        Text(
          'National rate: IBJA daily benchmark, per gram, through snapdata.dev. It excludes GST, making charges and shop premiums. '
          'A city shows a jeweller\'s rate only from quotes entered for that city. Quotes are kept on this phone.',
          style: TextStyle(color: c.muted, fontSize: 11, height: 1.5),
        ),
      ],
    );
  }

  Future<void> _openAddQuote(String productId) async {
    await FormSheet.show<void>(
      context,
      title: 'Add a quote for $_city',
      child: _QuoteForm(
        city: _city,
        options: _options,
        initialProductId: productId,
        onSave: (q) async {
          final all = [..._quotes, q];
          await QuoteStore.save(all);
          await _reload();
        },
      ),
    );
  }

  Future<void> _deleteQuote(JewellerQuote q) async {
    await QuoteStore.save([for (final x in _quotes) if (x.id != q.id) x]);
    await _reload();
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.metal, required this.city, required this.onMetal, required this.onCity});

  final String metal;
  final String city;
  final ValueChanged<String> onMetal;
  final ValueChanged<String> onCity;

  @override
  Widget build(BuildContext context) {
    final metalSwitch = SegmentedButton<String>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: 'gold', label: Text('Gold')),
        ButtonSegment(value: 'silver', label: Text('Silver')),
        ButtonSegment(value: 'platinum', label: Text('Platinum'), enabled: false),
      ],
      selected: {metal},
      onSelectionChanged: (s) {
        if (s.first != 'platinum') onMetal(s.first);
      },
    );
    // Every city is visible as a chip in one scrolling row, so nothing hides behind a menu.
    final cityChips = SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final s in _cities)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(label: Text(s), selected: s == city, onSelected: (_) => onCity(s)),
            ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        metalSwitch,
        const SizedBox(height: 12),
        Text('City', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        cityChips,
      ],
    );
  }
}

class _RateCard extends StatelessWidget {
  const _RateCard({
    required this.label,
    required this.productId,
    required this.prices,
    required this.quote,
    required this.national,
    required this.city,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String productId;
  final List<StoredPrice> prices;
  final JewellerQuote? quote;
  final double? national;
  final String city;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final rate = quote?.perGram ?? national;
    // The change shown is the national benchmark's change from the previous day.
    final change = latestAndPrevious(prices, productId);
    final unit = bullionProducts.firstWhere((p) => p.id == productId).unit;
    final latestPerGram = change.latest == null ? null : perGram(change.latest!.value, unit);
    final prevPerGram = change.previous == null ? null : perGram(change.previous!.value, unit);
    final diff = (latestPerGram != null && prevPerGram != null) ? latestPerGram - prevPerGram : null;
    final up = diff != null && diff >= 0;
    final subtitle = quote != null
        ? '${quote!.shop}, quoted ${dayLabel(quote!.quotedOn)}'
        : city == _nationalCity
            ? 'National benchmark'
            : 'No quote for $city yet. Showing national.';
    return Material(
      color: c.glassFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: selected ? c.accentStart : c.border, width: selected ? 1.6 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: c.muted, fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(rate == null ? '–' : money(rate), style: TextStyle(color: c.ink, fontWeight: FontWeight.w800, fontSize: 22)),
              ),
              const SizedBox(height: 8),
              if (diff != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: (up ? c.income : c.expense).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
                  child: Text(
                    '${up ? '▲ +' : '▼ −'}${money(diff.abs())} national',
                    style: TextStyle(color: up ? c.income : c.expense, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              const SizedBox(height: 8),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 11, height: 1.35)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Calculator extends StatelessWidget {
  const _Calculator({
    required this.options,
    required this.selected,
    required this.onPurity,
    required this.weight,
    required this.making,
    required this.weights,
    required this.quoteInUse,
    required this.onChanged,
    required this.onWeight,
  });

  final List<(String, String)> options;
  final String selected;
  final ValueChanged<String> onPurity;
  final TextEditingController weight;
  final TextEditingController making;
  final List<(double, String)> weights;
  final bool quoteInUse;
  final VoidCallback onChanged;
  final ValueChanged<double> onWeight;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return MonovaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Jewellery calculator', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 12),
          if (options.length > 1) ...[
            Text('Purity', style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [for (final o in options) ButtonSegment(value: o.$1, label: Text(o.$2))],
              selected: {selected},
              onSelectionChanged: (s) => onPurity(s.first),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: weight,
            onChanged: (_) => onChanged(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Weight (grams)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: making,
            enabled: !quoteInUse,
            onChanged: (_) => onChanged(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Making (%)',
              helperText: quoteInUse ? 'The quote\'s own making charge is used' : 'Making charges vary by shop',
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final w in weights)
                ActionChip(label: Text(w.$2), onPressed: () => onWeight(w.$1)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'GST 3% is added to gold and making.',
            style: TextStyle(color: c.muted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.estimate, required this.rate, required this.quote, required this.city, required this.nationalDate});

  final JewelleryEstimate? estimate;
  final double? rate;
  final JewellerQuote? quote;
  final String city;
  final DateTime? nationalDate;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final e = estimate;
    if (e == null) {
      return MonovaCard(
        padding: const EdgeInsets.all(16),
        child: Text(
          rate == null ? 'No rate saved yet. It appears once the page has updated.' : 'Enter the weight in grams to see the full cost.',
          style: TextStyle(color: c.muted, height: 1.4),
        ),
      );
    }
    final title = quote != null ? 'Final cost from ${quote!.shop}' : 'Estimated cost at the national rate';
    return MonovaCard(
      gradient: c.hero,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: TextStyle(color: c.onAccent.withValues(alpha: 0.9), fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(money(e.total), style: TextStyle(color: c.onAccent, fontSize: 32, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 12),
          _ResultRow(label: 'Gold value', value: e.baseValue, c: c),
          _ResultRow(label: 'Making charges', value: e.makingCharges, c: c),
          _ResultRow(label: 'GST 3% on gold and making', value: e.gst, c: c),
          if (e.otherCharges > 0) _ResultRow(label: 'Other charges', value: e.otherCharges, c: c),
          const SizedBox(height: 10),
          Text(
            quote != null
                ? '$city quote from ${quote!.shop}, dated ${dayLabel(quote!.quotedOn)}. This is the full cost they quoted, with GST added. Confirm it when you buy.'
                : nationalDate == null
                    ? 'Estimate only. Shop premiums, discounts and hallmarking are not included.'
                    : 'National benchmark for ${dayLabel(nationalDate!)}. Estimate only: shop premiums, discounts and hallmarking are not included.',
            style: TextStyle(color: c.onAccent.withValues(alpha: 0.8), fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value, required this.c});

  final String label;
  final double value;
  final MonovaColors c;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: c.onAccent.withValues(alpha: 0.9), fontSize: 13))),
          Text(money(value), style: TextStyle(color: c.onAccent, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}

/// The jeweller quotes for the chosen city and purity, newest first, with the full cost for the chosen weight.
class _QuotesCard extends StatelessWidget {
  const _QuotesCard({
    required this.city,
    required this.productId,
    required this.label,
    required this.quotes,
    required this.prices,
    required this.grams,
    required this.onAdd,
    required this.onDelete,
  });

  final String city;
  final String productId;
  final String label;
  final List<JewellerQuote> quotes;
  final List<StoredPrice> prices;
  final double grams;
  final VoidCallback onAdd;
  final Future<void> Function(JewellerQuote) onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final list = quotesFor(quotes, city, productId);
    return MonovaCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('$label quotes in $city', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add quote'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (list.isEmpty)
            Text(
              'No jeweller quotes for $city yet. Add the rate a shop quoted you, and it is kept here with its date.',
              style: TextStyle(color: c.muted, fontSize: 12, height: 1.45),
            )
          else
            for (final q in list) _quoteRow(context, c, q, list),
        ],
      ),
    );
  }

  Widget _quoteRow(BuildContext context, MonovaColors c, JewellerQuote q, List<JewellerQuote> list) {
    final change = changeFromPreviousQuote(quotes, q);
    final national = nationalOn(prices, productId, q.quotedOn);
    final gap = national == null ? null : q.perGram - national;
    final cost = grams > 0 ? q.costFor(grams).total : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q.shop, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  '${dayLabel(q.quotedOn)} · ${money(q.perGram)} per gram'
                  '${change == null ? '' : ' · ${change >= 0 ? '▲ +' : '▼ −'}${money(change.abs())} from their last'}',
                  style: TextStyle(color: c.muted, fontSize: 12, height: 1.35),
                ),
                if (gap != null)
                  Text(
                    'National that day ${money(national!)}: ${gap >= 0 ? '+' : '−'}${money(gap.abs())} against it',
                    style: TextStyle(color: c.muted, fontSize: 11, height: 1.35),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(cost == null ? 'Enter weight' : money(cost), style: TextStyle(color: c.ink, fontWeight: FontWeight.w800)),
              Text(cost == null ? '' : 'final, ${grams.toStringAsFixed(grams == grams.roundToDouble() ? 0 : 2)} g', style: TextStyle(color: c.muted, fontSize: 11)),
              IconButton(
                tooltip: 'Delete quote',
                visualDensity: VisualDensity.compact,
                onPressed: () => onDelete(q),
                icon: Icon(Icons.delete_outline_rounded, size: 18, color: c.expense),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuoteForm extends StatefulWidget {
  const _QuoteForm({required this.city, required this.options, required this.initialProductId, required this.onSave});

  final String city;
  final List<(String, String)> options;
  final String initialProductId;
  final Future<void> Function(JewellerQuote) onSave;

  @override
  State<_QuoteForm> createState() => _QuoteFormState();
}

class _QuoteFormState extends State<_QuoteForm> {
  late String _productId = widget.initialProductId;
  final _shop = TextEditingController();
  final _rate = TextEditingController();
  final _making = TextEditingController(text: '12');
  final _other = TextEditingController(text: '0');
  final _note = TextEditingController();

  @override
  void dispose() {
    _shop.dispose();
    _rate.dispose();
    _making.dispose();
    _other.dispose();
    _note.dispose();
    super.dispose();
  }

  double _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final valid = _shop.text.trim().isNotEmpty && _num(_rate) > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Write down what the shop quoted you today, before making and GST. Only quotes you enter are shown.',
          style: TextStyle(color: c.muted, fontSize: 12, height: 1.45),
        ),
        const SizedBox(height: 12),
        if (widget.options.length > 1)
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [for (final o in widget.options) ButtonSegment(value: o.$1, label: Text(o.$2))],
            selected: {_productId},
            onSelectionChanged: (s) => setState(() => _productId = s.first),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _shop,
          onChanged: (_) => setState(() {}),
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Shop or jeweller'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _rate,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Rate per gram (₹)'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _making,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Making (%)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _other,
          onChanged: (_) => setState(() {}),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Other charges (₹)', helperText: 'Hallmarking or similar, if the shop adds them'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: !valid
              ? null
              : () async {
                  final now = DateTime.now();
                  await widget.onSave(JewellerQuote(
                    id: now.microsecondsSinceEpoch.toString(),
                    shop: _shop.text.trim(),
                    city: widget.city,
                    productId: _productId,
                    perGram: _num(_rate),
                    makingPercent: _num(_making),
                    otherCharges: _num(_other),
                    quotedOn: DateTime(now.year, now.month, now.day),
                    note: _note.text.trim(),
                  ));
                  if (context.mounted) Navigator.of(context).pop();
                },
          child: const Text('Save quote'),
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.updating, required this.message, required this.sync});

  final bool updating;
  final String? message;
  final Map<String, SyncState> sync;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final times = [sync['gold']?.lastSuccess, sync['silver']?.lastSuccess].whereType<DateTime>().toList();
    final text = updating
        ? 'Updating the national rate…'
        : times.isEmpty
            ? 'The national rate appears when you have an internet connection.'
            : 'National rate updated ${_stamp(times.reduce((a, b) => a.isBefore(b) ? a : b))}';
    if (!updating && message == null) {
      return Text(text, style: TextStyle(color: c.muted, fontSize: 12));
    }
    return MonovaCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          if (updating) ...[
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text(message ?? text, style: TextStyle(color: c.ink, fontSize: 12, height: 1.4))),
        ],
      ),
    );
  }

  static String _stamp(DateTime utc) {
    final local = utc.toLocal();
    return '${dayLabel(local)}, ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

/// One card for the national history: a chart for 7 or 30 days, or a month-by-month table.
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.prices, required this.productId, required this.view, required this.onView});

  final List<StoredPrice> prices;
  final String productId;
  final String view;
  final ValueChanged<String> onView;

  @override
  Widget build(BuildContext context) {
    final product = bullionProducts.firstWhere((p) => p.id == productId);
    return MonovaCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: '7', label: Text('7 days')),
              ButtonSegment(value: '30', label: Text('30 days')),
              ButtonSegment(value: 'months', label: Text('Months')),
            ],
            selected: {view},
            onSelectionChanged: (s) => onView(s.first),
          ),
          const SizedBox(height: 12),
          if (view == 'months')
            _MonthTable(prices: prices, productId: productId, unit: product.unit)
          else
            _DayChart(prices: prices, productId: productId, unit: product.unit, days: int.parse(view)),
        ],
      ),
    );
  }
}

class _DayChart extends StatelessWidget {
  const _DayChart({required this.prices, required this.productId, required this.unit, required this.days});

  final List<StoredPrice> prices;
  final String productId;
  final String unit;
  final int days;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).subtract(Duration(days: days - 1));
    final points = [
      for (final p in prices)
        if (p.productId == productId && !p.date.isBefore(start)) p,
    ]..sort((a, b) => a.date.compareTo(b.date));
    if (points.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text('No saved national rates in the last $days days yet.', textAlign: TextAlign.center, style: TextStyle(color: c.muted, height: 1.4)),
      );
    }
    final values = [for (final p in points) perGram(p.value, unit)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 180, child: LineChart(_chartData(points, start, values, c.accentStart, c.border))),
        const SizedBox(height: 6),
        Text(
          '${points.length} of $days days have a value. Gaps are days the source reported no rate. National, per gram.',
          style: TextStyle(color: c.muted, fontSize: 11, height: 1.4),
        ),
      ],
    );
  }

  LineChartData _chartData(List<StoredPrice> points, DateTime start, List<double> values, Color line, Color grid) {
    final runs = <List<FlSpot>>[];
    var current = <FlSpot>[];
    int? lastDay;
    for (var i = 0; i < points.length; i++) {
      final day = points[i].date.difference(start).inDays;
      if (lastDay != null && day != lastDay + 1) {
        runs.add(current);
        current = <FlSpot>[];
      }
      current.add(FlSpot(day.toDouble(), values[i]));
      lastDay = day;
    }
    if (current.isNotEmpty) runs.add(current);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final pad = (maxV - minV) == 0 ? maxV * 0.01 : (maxV - minV) * 0.15;
    return LineChartData(
      minX: 0,
      maxX: (days - 1).toDouble(),
      minY: minV - pad,
      maxY: maxV + pad,
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: grid, strokeWidth: 0.6)),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        for (final run in runs)
          LineChartBarData(spots: run, isCurved: false, color: line, barWidth: 2.5, dotData: FlDotData(show: true)),
      ],
    );
  }
}

class _MonthTable extends StatelessWidget {
  const _MonthTable({required this.prices, required this.productId, required this.unit});

  final List<StoredPrice> prices;
  final String productId;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final months = monthlyAverages(prices, productId, unit).reversed.toList();
    if (months.isEmpty) {
      return Text('Previous days are being downloaded. Months appear here as they arrive.', style: TextStyle(color: c.muted, height: 1.4));
    }
    final header = TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w700);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(flex: 3, child: Text('Month', style: header)),
            Expanded(flex: 3, child: Text('Average per gram', textAlign: TextAlign.right, style: header)),
            Expanded(flex: 3, child: Text('Change', textAlign: TextAlign.right, style: header)),
          ],
        ),
        const Divider(height: 14),
        for (var i = 0; i < months.length; i++) _row(c, months, i),
        const SizedBox(height: 6),
        Text(
          'National averages of days with a published benchmark. The first and current months are partial.',
          style: TextStyle(color: c.muted, fontSize: 11, height: 1.4),
        ),
      ],
    );
  }

  Widget _row(MonovaColors c, List<MonthSummary> months, int i) {
    final m = months[i];
    final before = i + 1 < months.length ? months[i + 1] : null;
    final change = before == null ? null : (m.average - before.average) / before.average * 100;
    final changeText = change == null ? 'First month' : '${change >= 0 ? '▲ +' : '▼ '}${change.toStringAsFixed(1)}%';
    final changeColor = change == null ? c.muted : (change >= 0 ? c.income : c.expense);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text('${monthLabel(m.year, m.month)}\n${m.days} ${m.days == 1 ? 'day' : 'days'}', style: TextStyle(color: c.ink, fontWeight: FontWeight.w700, fontSize: 13, height: 1.3)),
          ),
          Expanded(flex: 3, child: Text(money(m.average), textAlign: TextAlign.right, style: TextStyle(color: c.ink, fontWeight: FontWeight.w700))),
          Expanded(flex: 3, child: Text(changeText, textAlign: TextAlign.right, style: TextStyle(color: changeColor, fontWeight: FontWeight.w700, fontSize: 13))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Mandi tab

class _MandiTab extends StatefulWidget {
  const _MandiTab();

  @override
  State<_MandiTab> createState() => _MandiTabState();
}

class _MandiTabState extends State<_MandiTab> {
  final _repo = MandiRepository();
  final _state = TextEditingController(text: 'Karnataka');
  final _commodity = TextEditingController(text: 'Tomato');
  bool _hasKey = false;
  bool _busy = false;
  String? _message;
  List<MandiRecord> _rows = const [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _state.dispose();
    _commodity.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final has = await _repo.hasKey();
    final rows = await _repo.load(state: _state.text.trim(), commodity: _commodity.text.trim());
    if (!mounted) return;
    setState(() {
      _hasKey = has;
      _rows = rows.take(30).toList();
    });
    final last = await _repo.lastFetched();
    final stale = last == null || DateTime.now().toUtc().difference(last) > const Duration(hours: 6);
    if (has && stale) await _fetch(automatic: true);
  }

  Future<void> _fetch({bool automatic = false}) async {
    if (!_hasKey) {
      setState(() => _message = 'Set your free data.gov.in key first (button above).');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final n = await _repo.fetch(state: _state.text.trim(), commodity: _commodity.text.trim());
      final rows = await _repo.load(state: _state.text.trim(), commodity: _commodity.text.trim());
      if (!mounted) return;
      setState(() {
        _busy = false;
        _rows = rows.take(30).toList();
        _message = automatic ? null : (n == 0 ? 'No mandi rows for that state and commodity today.' : 'Read $n rows from the source.');
      });
    } on MandiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _message = e.message;
        });
      }
    }
  }

  Future<void> _openKeySheet() async {
    await FormSheet.show<void>(
      context,
      title: 'data.gov.in key',
      child: _KeyForm(repo: _repo, onSaved: () async {
        await _init();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _hasKey ? 'Mandi prices are kept on this phone and refresh when you open this tab.' : 'Wholesale mandi prices need your free data.gov.in key.',
                style: TextStyle(color: c.muted, fontSize: 12, height: 1.4),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: _openKeySheet,
              icon: Icon(_hasKey ? Icons.key_rounded : Icons.vpn_key_outlined, size: 18),
              label: Text(_hasKey ? 'Key' : 'Set key'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Pick the state from the list; the rows reload for that state.
        DropdownButtonFormField<String>(
          key: ValueKey('mandi-state-${_state.text}'),
          initialValue: _mandiStates.contains(_state.text) ? _state.text : _mandiStates.first,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'State'),
          items: [for (final s in _mandiStates) DropdownMenuItem(value: s, child: Text(s))],
          onChanged: (v) {
            if (v == null) return;
            _state.text = v;
            _fetch();
          },
        ),
        const SizedBox(height: 14),
        Text('Commodity', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        // Pick one commodity.
        ListenableBuilder(
          listenable: _commodity,
          builder: (context, _) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in _mandiCommodities)
                ChoiceChip(
                  label: Text(name),
                  selected: _commodity.text == name,
                  onSelected: (_) {
                    _commodity.text = name;
                    _fetch();
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Vegetables, fruit and grains from government mandi data. Poultry is not available yet.',
          style: TextStyle(color: c.muted, fontSize: 11, height: 1.4),
        ),
        const SizedBox(height: 10),
        if (_busy) Text('Updating mandi prices…', style: TextStyle(color: c.muted, fontSize: 12)),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_message!, style: TextStyle(color: c.ink, fontSize: 13, height: 1.4)),
          ),
        if (_rows.isEmpty)
          MonovaCard(
            padding: const EdgeInsets.all(16),
            child: Text(
              _hasKey ? 'No rows saved for this state and commodity yet. Press done in the fields above.' : 'Set your key to see mandi prices.',
              style: TextStyle(color: c.muted, height: 1.4),
            ),
          )
        else
          MonovaCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                for (final r in _rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${r.commodity}${r.variety.isEmpty ? '' : ' (${r.variety})'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text('${r.market}, ${r.district} · ${dayLabel(r.date)}', style: TextStyle(color: c.muted, fontSize: 12)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${money(r.modalPrice!)} / quintal', style: TextStyle(color: c.ink, fontWeight: FontWeight.w700)),
                            Text('${money(perKilogram(r.modalPrice!))} per kg', style: TextStyle(color: c.muted, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Modal price is the most common price that day. Source: $mandiSourceName.', style: TextStyle(color: c.muted, fontSize: 11, height: 1.4)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _KeyForm extends StatefulWidget {
  const _KeyForm({required this.repo, required this.onSaved});

  final MandiRepository repo;
  final Future<void> Function() onSaved;

  @override
  State<_KeyForm> createState() => _KeyFormState();
}

class _KeyFormState extends State<_KeyForm> {
  final _key = TextEditingController();

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Get a free key from data.gov.in: sign in, then open your profile for the API key. It is kept only on this phone and is never part of the app.',
          style: TextStyle(color: c.muted, fontSize: 12, height: 1.45),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _key,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'data.gov.in API key'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _key.text.trim().isEmpty
                    ? null
                    : () async {
                        await widget.repo.saveKey(_key.text);
                        await widget.onSaved();
                        if (context.mounted) Navigator.of(context).pop();
                      },
                child: const Text('Save key'),
              ),
            ),
            const SizedBox(width: 10),
            TextButton(
              onPressed: () async {
                await widget.repo.removeKey();
                await widget.onSaved();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Remove'),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Coverage tab

class _CoverageTab extends StatelessWidget {
  const _CoverageTab();

  static const _items = [
    ('National gold and silver', 'Daily IBJA benchmark with history', true),
    ('Jeweller quotes by city', 'Rates a shop quoted you, with its full final cost and history', true),
    ('Mandi prices', 'Wholesale, by state and commodity, once you set your key', true),
    ('City-wise published rates', 'Not in a free verified source. Planned as a paid city feed later', false),
    ('Platinum', 'Not in the verified free feed yet', false),
    ('Diamonds', 'No free daily benchmark. Needs a dealer quote', false),
    ('Petrol and diesel', 'Needs a permitted source with city rates', false),
    ('Grains, pulses and flour', 'Awaiting a verified source or community entries', false),
    ('Vegetables and fruits', 'Awaiting a verified source or community entries', false),
    ('Milk, dairy and oils', 'Awaiting a verified source or community entries', false),
    ('Eggs, chicken and fish', 'Awaiting a verified source or community entries', false),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        EqualTileGrid(
          minTileWidth: 220,
          tileHeight: 96,
          children: [
            for (final r in _items) _CoverageTile(title: r.$1, text: r.$2, available: r.$3),
          ],
        ),
        const SizedBox(height: 10),
        MonovaCard(
          padding: const EdgeInsets.all(14),
          child: Text(
            'Sources: India Bullion and Jewellers Association (IBJA), through snapdata.dev, for national gold and silver. '
            'AGMARKNET, through data.gov.in, for mandi prices. Jeweller quotes are entered by you and are not verified by MONOVA. '
            'The IBJA licence is "republished with attribution, no formal licence", so this app shows the source on every national rate.',
            style: TextStyle(color: c.muted, fontSize: 12, height: 1.45),
          ),
        ),
      ],
    );
  }
}

class _CoverageTile extends StatelessWidget {
  const _CoverageTile({required this.title, required this.text, required this.available});

  final String title;
  final String text;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return MonovaCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(available ? Icons.check_circle_rounded : Icons.hourglass_empty_rounded, color: available ? c.income : c.muted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(text, style: TextStyle(color: c.muted, fontSize: 12, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
