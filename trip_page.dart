import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db.dart';
import '../services.dart';
import '../widgets.dart';
import 'trip_extra.dart';
import 'trip_tabs.dart';

class TripPage extends StatefulWidget {
  final Rec trip;
  final int initialTab;
  const TripPage({super.key, required this.trip, this.initialTab = 0});
  @override
  State<TripPage> createState() => _TripPageState();
}

class _TripPageState extends State<TripPage> {
  late Rec trip = widget.trip;

  Future<void> setCover() async {
    final p = await Net.pick();
    if (p == null) return;
    await DB.update('trips', {'cover': p}, trip['id'] as int);
    setState(() => trip = {...trip, 'cover': p});
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 10,
        initialIndex: widget.initialTab,
        child: Scaffold(
          appBar: AppBar(
            foregroundColor: Colors.white,
            title: Text('${trip['title']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            flexibleSpace: Stack(fit: StackFit.expand, children: [
              coverBox('${trip['cover'] ?? ''}'),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x99000000), Color(0xE63E5C3F)]),
                ),
              ),
            ]),
            bottom: const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [
                Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
                Tab(icon: Icon(Icons.event_note), text: 'Itinerary'),
                Tab(icon: Icon(Icons.map), text: 'Map'),
                Tab(icon: Icon(Icons.account_balance_wallet), text: 'Budget'),
                Tab(icon: Icon(Icons.confirmation_number), text: 'Bookings'),
                Tab(icon: Icon(Icons.checklist), text: 'Packing'),
                Tab(icon: Icon(Icons.edit_note), text: 'Journal'),
                Tab(icon: Icon(Icons.photo_library), text: 'Photos'),
                Tab(icon: Icon(Icons.auto_awesome), text: 'Inspire'),
                Tab(icon: Icon(Icons.calculate), text: 'Tools'),
              ],
            ),
          ),
          body: TabBarView(children: [
            Overview(trip: trip, onCover: setCover),
            Itinerary(trip: trip),
            TripMap(trip: trip),
            Expenses(trip: trip, onBudget: (b) => setState(() => trip = {...trip, 'budget': b})),
            Bookings(trip: trip),
            Packing(trip: trip),
            Journal(trip: trip),
            Photos(trip: trip),
            Inspire(trip: trip),
            Tools(trip: trip),
          ]),
        ),
      );
}

const cats = ['Food', 'Sightseeing', 'Transport', 'Stay', 'Shopping', 'Other'];

class Itinerary extends StatefulWidget {
  final Rec trip;
  const Itinerary({super.key, required this.trip});
  @override
  State<Itinerary> createState() => _ItState();
}

class _ItState extends State<Itinerary> {
  List<Rec> items = [];
  int get tid => widget.trip['id'] as int;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    items = await DB.list('activities', 'trip_id', tid, 'day, time');
    if (mounted) setState(() {});
  }

  Future<void> edit([Rec? a, String? day]) async {
    final r = await formSheet(
      context,
      a == null ? 'Add activity' : 'Edit activity',
      const [
        F('title', 'Activity'),
        F('place', 'Place (optional)', t: 'opt'),
        F('day', 'Date', t: 'date'),
        F('time', 'Time', t: 'time'),
        F('category', 'Category', t: 'choice', o: cats),
      ],
      a ?? <String, Object?>{'day': day ?? widget.trip['start_date']},
    );
    if (r == null) return;
    final v = <String, Object?>{...r, 'trip_id': tid};
    if (r['place']!.isNotEmpty) {
      final ll = await Net.geocode('${r['place']}, ${widget.trip['destination']}');
      if (ll != null) {
        v['lat'] = ll.latitude;
        v['lng'] = ll.longitude;
      }
    } else {
      v['lat'] = null;
      v['lng'] = null;
    }
    a == null ? await DB.insert('activities', v) : await DB.update('activities', v, a['id'] as int);
    load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hint = Theme.of(context).hintColor;
    final start = DateTime.parse(widget.trip['start_date'] as String);
    final end = DateTime.parse(widget.trip['end_date'] as String);
    final totalDays = end.difference(start).inDays + 1;
    final byDay = <String, List<Rec>>{};
    for (final a in items) {
      byDay.putIfAbsent(a['day'] as String, () => []).add(a);
    }
    // every day of the trip is shown (even empty ones) plus any day that has activities
    final keys = <String>{
      for (var i = 0; i < (totalDays > 120 ? 120 : totalDays); i++)
        DateFormat('yyyy-MM-dd').format(DateTime(start.year, start.month, start.day + i)),
      ...byDay.keys,
    }.toList()
      ..sort();

    Widget actTile(Rec a) {
      final col = catColors[a['category']] ?? cs.primary;
      final place = '${a['place'] ?? ''}';
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          CircleAvatar(radius: 20, backgroundColor: col.withOpacity(.15), child: Icon(catIcons[a['category']] ?? Icons.event, color: col, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${a['title']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text('${a['time']}${place.isEmpty ? '' : '  •  $place'}', style: TextStyle(color: hint, fontSize: 12)),
            ]),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (v) async {
              if (v == 'edit') {
                edit(a);
              } else if (await confirm(context, 'Delete this activity?')) {
                await DB.delete('activities', a['id'] as int);
                load();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'del', child: Text('Delete', style: TextStyle(color: Colors.red))),
            ],
          ),
        ]),
      );
    }

    Widget dayBlock(String d) {
      final dt = DateTime.parse(d);
      final n = dt.difference(start).inDays + 1;
      final list = byDay[d] ?? [];
      return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 46,
            child: Column(children: [
              Text('Day', style: TextStyle(fontSize: 11, color: hint)),
              const SizedBox(height: 2),
              CircleAvatar(radius: 16, backgroundColor: cs.primary, child: Text('$n', style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.bold, fontSize: 13))),
              Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 4), color: cs.primaryContainer)),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 8),
                  child: Text(DateFormat('EEEE, d MMM').format(dt), style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
                ),
                if (list.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('Nothing planned yet', style: TextStyle(color: hint, fontStyle: FontStyle.italic))),
                for (final a in list) actTile(a),
                TextButton.icon(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                  onPressed: () => edit(null, d),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Add activity'),
                ),
              ]),
            ),
          ),
        ]),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(onPressed: () => edit(), child: const Icon(Icons.add)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 90), children: [
        Text('${widget.trip['destination']}', style: serif(26)),
        const SizedBox(height: 2),
        Text('$totalDays days  •  ${items.length} activit${items.length == 1 ? 'y' : 'ies'}  •  ${DateFormat('d MMM').format(start)} - ${DateFormat('d MMM').format(end)}', style: TextStyle(color: hint)),
        if (items.isEmpty) const Padding(padding: EdgeInsets.only(top: 10), child: Text('No activities yet. Tap + to plan your days')),
        for (final d in keys) dayBlock(d),
      ]),
    );
  }
}

class Expenses extends StatefulWidget {
  final Rec trip;
  final void Function(double)? onBudget;
  const Expenses({super.key, required this.trip, this.onBudget});
  @override
  State<Expenses> createState() => _ExState();
}

class _ExState extends State<Expenses> {
  List<Rec> items = [];
  int get tid => widget.trip['id'] as int;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    items = await DB.list('expenses', 'trip_id', tid, 'id DESC');
    if (mounted) setState(() {});
  }

  /// [cat] pre-selects a category (used by the Hotel / Food / Transport quick-add buttons).
  Future<void> edit([Rec? x, String? cat]) async {
    final r = await formSheet(
      context,
      x == null ? 'Add expense' : 'Edit expense',
      const [F('title', 'What did you spend on?'), F('amount', 'Amount', t: 'number'), F('category', 'Category', t: 'choice', o: cats)],
      x ?? <String, Object?>{'category': cat ?? cats.first},
    );
    if (r == null) return;
    final v = <String, Object?>{...r, 'amount': double.parse(r['amount']!), 'trip_id': tid};
    x == null ? await DB.insert('expenses', v) : await DB.update('expenses', v, x['id'] as int);
    load();
  }

  Future<void> setBudget() async {
    final r = await formSheet(
      context,
      'Set total trip budget',
      const [F('budget', 'Total budget', t: 'number')],
      <String, Object?>{'budget': '${widget.trip['budget']}'},
    );
    if (r == null) return;
    final v = double.parse(r['budget']!);
    await DB.update('trips', {'budget': v}, tid);
    widget.onBudget?.call(v);
    if (mounted) {
      setState(() {});
      toast(context, 'Budget updated');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final budget = (widget.trip['budget'] as num).toDouble();
    final spent = items.fold<double>(0, (s, e) => s + (e['amount'] as num));
    final left = budget - spent;
    final pct = budget == 0 ? 0.0 : (spent / budget).clamp(0.0, 1.0);
    final over = left < 0;
    double catSum(String c) => items.where((e) => e['category'] == c).fold<double>(0, (s, e) => s + (e['amount'] as num));

    Widget stat(String label, String value, {Color? color}) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 2),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 20, fontWeight: FontWeight.w800))),
          ]),
        );

    Widget quick(IconData i, String label, String cat) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => edit(null, cat),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(18)),
              child: Column(children: [
                Icon(i, color: cs.primary),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        );

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(onPressed: () => edit(), child: const Icon(Icons.add)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: [
        // ---- budget summary: total budget, total spending, remaining balance
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kSageDark, kSage]),
          ),
          child: Column(children: [
            Row(children: [
              SizedBox(
                width: 92,
                height: 92,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox.expand(child: CircularProgressIndicator(value: pct, strokeWidth: 9, color: over ? const Color(0xFFFFB4A9) : Colors.white, backgroundColor: Colors.white24)),
                  Text('${(pct * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
                ]),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Text('Total budget', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const Spacer(),
                    InkWell(
                      onTap: setBudget,
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Row(children: [
                          Icon(Icons.edit, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Set', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                  ]),
                  Text(budget.toStringAsFixed(0), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white.withOpacity(.14), borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                stat('Total spent', spent.toStringAsFixed(0)),
                stat(over ? 'Over budget by' : 'Remaining balance', (over ? -left : left).toStringAsFixed(0), color: over ? const Color(0xFFFFB4A9) : Colors.white),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        // ---- quick add: hotel, food, transport
        Row(children: [
          quick(Icons.hotel, 'Add hotel', 'Stay'),
          const SizedBox(width: 10),
          quick(Icons.restaurant, 'Add food', 'Food'),
          const SizedBox(width: 10),
          quick(Icons.directions_bus, 'Add transport', 'Transport'),
        ]),
        const SizedBox(height: 14),
        // ---- expense chart
        if (spent > 0)
          card16(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Expense chart', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(children: [
              DonutChart(values: [for (final c in cats) catSum(c)], colors: [for (final c in cats) catColors[c]!], center: spent.toStringAsFixed(0), caption: 'spent'),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final c in cats)
                    if (catSum(c) > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: [
                          Icon(Icons.circle, size: 10, color: catColors[c]),
                          const SizedBox(width: 8),
                          Text('$c  ${(catSum(c) / spent * 100).round()}%'),
                        ]),
                      ),
                ]),
              ),
            ]),
          ])),
        if (spent > 0)
          card16(Column(children: [
            for (final c in cats)
              if (catSum(c) > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    SizedBox(width: 100, child: Text(c)),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: spent == 0 ? 0 : catSum(c) / spent,
                        minHeight: 8,
                        color: catColors[c],
                        backgroundColor: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    SizedBox(width: 60, child: Text(catSum(c).toStringAsFixed(0), textAlign: TextAlign.right)),
                  ]),
                ),
          ])),
        if (items.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('No expenses logged yet'))),
        for (final x in items)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: (catColors[x['category']] ?? cs.primary).withOpacity(.15),
                child: Icon(catIcons[x['category']] ?? Icons.paid, color: catColors[x['category']] ?? cs.primary),
              ),
              title: Text('${x['title']}'),
              subtitle: Text('${x['category']}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text((x['amount'] as num).toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => edit(x)),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  onPressed: () async {
                    if (await confirm(context, 'Delete this expense?')) {
                      await DB.delete('expenses', x['id'] as int);
                      load();
                    }
                  },
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}
