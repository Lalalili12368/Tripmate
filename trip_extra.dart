import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db.dart';
import '../services.dart';
import '../widgets.dart';

// ------------------------------------------------------------------ BOOKINGS
const btypes = ['Flight', 'Hotel', 'Train', 'Bus', 'Car rental', 'Event', 'Other'];
const bIcons = <String, IconData>{
  'Flight': Icons.flight,
  'Hotel': Icons.hotel,
  'Train': Icons.train,
  'Bus': Icons.directions_bus,
  'Car rental': Icons.directions_car,
  'Event': Icons.confirmation_number,
  'Other': Icons.bookmark,
};

class Bookings extends StatefulWidget {
  final Rec trip;
  const Bookings({super.key, required this.trip});
  @override
  State<Bookings> createState() => _BookingsState();
}

class _BookingsState extends State<Bookings> {
  List<Rec> items = [];
  int get tid => widget.trip['id'] as int;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    items = await DB.list('bookings', 'trip_id', tid, 'date');
    if (mounted) setState(() {});
  }

  Future<void> edit([Rec? b]) async {
    final r = await formSheet(
      context,
      b == null ? 'Add booking' : 'Edit booking',
      [
        const F('type', 'Type', t: 'choice', o: btypes),
        const F('title', 'Name (e.g. Biman BG-147, Hotel Ubud)'),
        const F('date', 'Date', t: 'date'),
        const F('ref', 'Booking reference (optional)', t: 'opt'),
        const F('cost', 'Cost (0 if unknown)', t: 'number'),
      ],
      b ?? {'date': widget.trip['start_date']},
    );
    if (r == null) return;
    final v = <String, Object?>{...r, 'cost': double.parse(r['cost']!), 'trip_id': tid};
    b == null ? await DB.insert('bookings', v) : await DB.update('bookings', v, b['id'] as int);
    load();
  }

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (s, b) => s + (b['cost'] as num));
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(onPressed: () => edit(), child: const Icon(Icons.add)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: [
        card16(Row(children: [
          const Icon(Icons.confirmation_number, size: 30),
          const SizedBox(width: 14),
          Text('${items.length} bookings  •  total ${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ])),
        if (items.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('Keep flights, hotels and tickets in one place'))),
        for (final b in items)
          Card(
            elevation: 0,
            child: ListTile(
              leading: CircleAvatar(child: Icon(bIcons[b['type']] ?? Icons.bookmark)),
              title: Text('${b['title']}'),
              subtitle: Text('${b['type']}  •  ${DateFormat('d MMM yyyy').format(DateTime.parse('${b['date']}'))}${'${b['ref']}'.isEmpty ? '' : '\nRef: ${b['ref']}'}'),
              isThreeLine: '${b['ref']}'.isNotEmpty,
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text((b['cost'] as num).toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => edit(b)),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  onPressed: () async {
                    if (await confirm(context, 'Delete this booking?')) {
                      await DB.delete('bookings', b['id'] as int);
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

// ------------------------------------------------------------------- JOURNAL
const moods = ['😍 Amazing', '😊 Good', '😐 Okay', '😴 Tired', '🤒 Rough'];

class Journal extends StatefulWidget {
  final Rec trip;
  const Journal({super.key, required this.trip});
  @override
  State<Journal> createState() => _JournalState();
}

class _JournalState extends State<Journal> {
  List<Rec> items = [];
  int get tid => widget.trip['id'] as int;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    items = await DB.list('journal', 'trip_id', tid, 'day DESC');
    if (mounted) setState(() {});
  }

  Future<void> edit([Rec? j]) async {
    final r = await formSheet(
      context,
      j == null ? 'New journal entry' : 'Edit entry',
      const [F('day', 'Date', t: 'date'), F('mood', 'How was your day?', t: 'choice', o: moods), F('text', 'What happened today?')],
      j ?? {'day': DateTime.now().toIso8601String().substring(0, 10)},
    );
    if (r == null) return;
    final v = <String, Object?>{...r, 'trip_id': tid};
    j == null ? await DB.insert('journal', v) : await DB.update('journal', v, j['id'] as int);
    load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton(onPressed: () => edit(), child: const Icon(Icons.edit)),
        body: items.isEmpty
            ? const Center(child: Text('Write down your memories day by day ✍️'))
            : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: [
                for (final j in items)
                  card16(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('${j['mood']}'.split(' ').first, style: const TextStyle(fontSize: 30)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(DateFormat('EEEE, d MMM yyyy').format(DateTime.parse('${j['day']}')), style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${j['mood']}'.split(' ').skip(1).join(' '), style: TextStyle(color: Theme.of(context).hintColor)),
                        ]),
                      ),
                      IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => edit(j)),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                        onPressed: () async {
                          if (await confirm(context, 'Delete this entry?')) {
                            await DB.delete('journal', j['id'] as int);
                            load();
                          }
                        },
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text('${j['text']}'),
                  ])),
              ]),
      );
}

// ------------------------------------------------------------------- INSPIRE
class Inspire extends StatefulWidget {
  final Rec trip;
  const Inspire({super.key, required this.trip});
  @override
  State<Inspire> createState() => _InspireState();
}

class _InspireState extends State<Inspire> {
  late final Future<List<Map<String, String>>> f = Net.photos('${widget.trip['destination']}'.split(',').first);

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, String>>>(
        future: f,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final l = snap.data ?? [];
          if (l.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('No photos found for this destination. Check your internet connection.', textAlign: TextAlign.center)));
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.15),
            itemCount: l.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GalleryPage(
                    imgs: l,
                    start: i,
                    onSave: (m) async {
                      await DB.insert('photos', {'trip_id': widget.trip['id'], 'data': m['url'], 'caption': m['title']});
                      if (mounted) toast(context, 'Saved to trip photos');
                    },
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(fit: StackFit.expand, children: [
                  Container(color: Theme.of(context).colorScheme.primaryContainer),
                  Image.network(l[i]['url']!, fit: BoxFit.cover, filterQuality: FilterQuality.high, errorBuilder: (_, __, ___) => const SizedBox()),
                ]),
              ),
            ),
          );
        },
      );
}

// --------------------------------------------------------------------- TOOLS
const currencies = ['USD', 'EUR', 'GBP', 'BDT', 'INR', 'JPY', 'IDR', 'THB', 'MYR', 'SGD', 'AED', 'SAR', 'TRY', 'AUD', 'CAD', 'CNY', 'KRW', 'CHF', 'PKR', 'NPR', 'LKR', 'QAR', 'KWD', 'MVR'];

class Tools extends StatefulWidget {
  final Rec trip;
  const Tools({super.key, required this.trip});
  @override
  State<Tools> createState() => _ToolsState();
}

class _ToolsState extends State<Tools> {
  final amt = TextEditingController(text: '100'), total = TextEditingController(), people = TextEditingController(text: '2');
  String from = 'USD', to = 'BDT', res = '', split = '';
  bool busy = false;

  Future<void> convert() async {
    final a = double.tryParse(amt.text.trim());
    if (a == null) {
      toast(context, 'Enter a valid amount');
      return;
    }
    setState(() => busy = true);
    final rates = await Net.rates(from);
    if (!mounted) return;
    setState(() {
      busy = false;
      final r = rates?[to];
      res = r == null
          ? 'Could not get exchange rates. Check your internet.'
          : '${NumberFormat('#,##0.##').format(a)} $from = ${NumberFormat('#,##0.00').format(a * (r as num))} $to\n1 $from = ${(r).toStringAsFixed(4)} $to';
    });
  }

  void splitBill() {
    final t = double.tryParse(total.text.trim()), n = int.tryParse(people.text.trim());
    setState(() => split = (t == null || n == null || n < 1) ? 'Enter a valid total and number of people' : 'Each person pays ${(t / n).toStringAsFixed(2)}');
  }

  Widget drop(String v, void Function(String) on) => Expanded(
        child: DropdownButtonFormField<String>(
          value: v,
          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
          items: [for (final c in currencies) DropdownMenuItem(value: c, child: Text(c))],
          onChanged: (x) => on(x!),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final days = DateTime.parse('${widget.trip['end_date']}').difference(DateTime.parse('${widget.trip['start_date']}')).inDays + 1;
    final daily = (widget.trip['budget'] as num) / days;
    return ListView(padding: const EdgeInsets.all(16), children: [
      card16(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('💱 Currency converter (live rates)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(controller: amt, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
        const SizedBox(height: 10),
        Row(children: [
          drop(from, (x) => setState(() => from = x)),
          IconButton(icon: const Icon(Icons.swap_horiz), onPressed: () => setState(() {
                final t = from;
                from = to;
                to = t;
              })),
          drop(to, (x) => setState(() => to = x)),
        ]),
        const SizedBox(height: 12),
        FilledButton(onPressed: busy ? null : convert, child: Text(busy ? 'Converting...' : 'Convert')),
        if (res.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(res, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
      ])),
      card16(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('🧾 Split the bill', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(controller: total, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total bill')),
        const SizedBox(height: 10),
        TextField(controller: people, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Number of people')),
        const SizedBox(height: 12),
        FilledButton(onPressed: splitBill, child: const Text('Calculate')),
        if (split.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(split, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
      ])),
      card16(Row(children: [
        const Text('📅', style: TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(child: Text('Your budget allows about ${daily.toStringAsFixed(0)} per day over $days days.', style: const TextStyle(fontSize: 15))),
      ])),
    ]);
  }
}
