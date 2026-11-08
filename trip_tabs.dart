import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../db.dart';
import '../services.dart';
import '../widgets.dart';

Widget _box(Widget child) => Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );

// ---------------------------------------------------------------- TRIP PASS
/// Boarding-pass style summary: departure, return, destination, budget, balance.
class _TripPass extends StatelessWidget {
  final Rec t;
  final double spent;
  const _TripPass({required this.t, required this.spent});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hint = Theme.of(context).hintColor;
    final s = DateTime.parse(t['start_date'] as String), e = DateTime.parse(t['end_date'] as String);
    final now = DateTime.now(), d0 = DateTime(now.year, now.month, now.day);
    final status = d0.isAfter(e) ? 'Completed' : (d0.isBefore(s) ? 'Upcoming' : 'Ongoing');
    final days = e.difference(s).inDays + 1;
    final budget = (t['budget'] as num).toDouble();
    final left = budget - spent;

    Widget date(String label, DateTime d, CrossAxisAlignment al) => Column(crossAxisAlignment: al, children: [
          Text(label, style: TextStyle(fontSize: 11, color: hint)),
          Text(DateFormat('d MMM').format(d), style: serif(28)),
          Text(DateFormat('EEE, yyyy').format(d), style: TextStyle(fontSize: 12, color: hint)),
        ]);
    Widget cell(String label, String value, {Color? color}) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11, color: hint)),
            const SizedBox(height: 2),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
          ]),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.07), blurRadius: 14, offset: const Offset(0, 5))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          color: cs.primary,
          child: Row(children: [
            Text('TRIP PASS', style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: Colors.white.withOpacity(.9), borderRadius: BorderRadius.circular(12)),
              child: Text(status, style: const TextStyle(fontSize: 11, color: kSageDark, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Icon(Icons.flight, color: cs.onPrimary, size: 18),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            date('DEPARTURE', s, CrossAxisAlignment.start),
            Expanded(
              child: Column(children: [
                Row(children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: LayoutBuilder(builder: (_, c) {
                      final n = (c.maxWidth / 8).floor();
                      return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [for (var i = 0; i < n; i++) Container(width: 3, height: 2, color: hint)]);
                    }),
                  ),
                  Icon(Icons.flight, color: cs.primary),
                  Expanded(
                    child: LayoutBuilder(builder: (_, c) {
                      final n = (c.maxWidth / 8).floor();
                      return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [for (var i = 0; i < n; i++) Container(width: 3, height: 2, color: hint)]);
                    }),
                  ),
                  const SizedBox(width: 8),
                ]),
                const SizedBox(height: 4),
                Text('$days day${days == 1 ? '' : 's'}', style: TextStyle(fontSize: 12, color: hint)),
              ]),
            ),
            date('RETURN', e, CrossAxisAlignment.end),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
          child: Divider(color: cs.primaryContainer, thickness: 1.5),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
          child: Row(children: [
            cell('DESTINATION', '${t['destination']}'.split(',').first),
            cell('BUDGET', budget.toStringAsFixed(0)),
            cell(left >= 0 ? 'REMAINING' : 'OVER BY', (left >= 0 ? left : -left).toStringAsFixed(0), color: left >= 0 ? null : Colors.red),
          ]),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ OVERVIEW
class Overview extends StatefulWidget {
  final Rec trip;
  final VoidCallback onCover;
  const Overview({super.key, required this.trip, required this.onCover});
  @override
  State<Overview> createState() => _OvState();
}

class _OvState extends State<Overview> {
  List<Rec> acts = [], pack = [], exp = [];
  Map<String, dynamic>? wiki, fc;
  bool wxDone = false;
  Rec get t => widget.trip;
  int get tid => t['id'] as int;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    acts = await DB.list('activities', 'trip_id', tid, 'day, time');
    pack = await DB.list('packing', 'trip_id', tid, 'id');
    exp = await DB.list('expenses', 'trip_id', tid, 'id');
    if (mounted) setState(() {});
    wiki = await Net.wiki('${t['destination']}');
    if (mounted) setState(() {});
    Object? la = t['lat'], ln = t['lng'];
    if (la == null) {
      final ll = await Net.geocode('${t['destination']}');
      if (ll != null) {
        la = ll.latitude;
        ln = ll.longitude;
        await DB.update('trips', {'lat': la, 'lng': ln}, tid);
      }
    }
    if (la != null) fc = await Net.forecast((la as num).toDouble(), (ln as num).toDouble());
    wxDone = true;
    if (mounted) setState(() {});
  }

  void copySummary(double spent) {
    final b = StringBuffer()
      ..writeln('${t['title']} - ${t['destination']}')
      ..writeln('${t['start_date']} to ${t['end_date']}')
      ..writeln('Budget ${t['budget']}  |  Spent ${spent.toStringAsFixed(0)}')
      ..writeln('');
    for (final a in acts) {
      b.writeln('${a['day']} ${a['time']}  ${a['title']}${(a['place'] as String).isEmpty ? '' : ' @ ${a['place']}'}');
    }
    Clipboard.setData(ClipboardData(text: b.toString()));
    toast(context, 'Trip summary copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    final s = DateTime.parse(t['start_date'] as String), e = DateTime.parse(t['end_date'] as String);
    final now = DateTime.now(), d0 = DateTime(now.year, now.month, now.day);
    final total = e.difference(s).inDays + 1;
    String head;
    double? prog;
    if (d0.isBefore(s)) {
      head = 'Starts in ${s.difference(d0).inDays} days';
    } else if (d0.isAfter(e)) {
      head = 'Trip completed';
      prog = 1;
    } else {
      final d = d0.difference(s).inDays + 1;
      head = 'Day $d of $total';
      prog = d / total;
    }
    final spent = exp.fold<double>(0, (a, x) => a + (x['amount'] as num));
    final done = pack.where((p) => p['done'] == 1).length;
    final hint = Theme.of(context).hintColor;
    final wx = fc?['current_weather'] as Map?;
    final daily = fc?['daily'] as Map?;
    String localTime = '', sun = '';
    if (fc != null) {
      final off = (fc!['utc_offset_seconds'] as num).toInt();
      localTime = DateFormat('EEE, h:mm a').format(DateTime.now().toUtc().add(Duration(seconds: off)));
    }
    if (daily != null) {
      sun = 'Sunrise ${DateFormat('h:mm a').format(DateTime.parse('${(daily['sunrise'] as List)[0]}'))}   Sunset ${DateFormat('h:mm a').format(DateTime.parse('${(daily['sunset'] as List)[0]}'))}';
    }
    Widget stat(IconData i, String v, String l) => Expanded(
          child: Column(children: [
            Icon(i, color: Theme.of(context).colorScheme.primary),
            Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(l, style: TextStyle(color: hint, fontSize: 12)),
          ]),
        );
    return ListView(padding: const EdgeInsets.all(16), children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: coverBox(
          '${t['cover'] ?? ''}',
          height: 230,
          child: Stack(children: [
            Positioned(
              right: 10,
              bottom: 10,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                onPressed: widget.onCover,
                icon: const Icon(Icons.photo_camera, size: 18),
                label: const Text('Change cover'),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      _TripPass(t: t, spent: spent),
      _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(head, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text('${DateFormat('d MMM').format(s)} - ${DateFormat('d MMM yyyy').format(e)}  •  $total days', style: TextStyle(color: hint)),
        Text('Daily budget: ${((t['budget'] as num) / total).toStringAsFixed(0)}', style: TextStyle(color: hint)),
        if (prog != null) ...[
          const SizedBox(height: 10),
          LinearProgressIndicator(value: prog, minHeight: 8, borderRadius: BorderRadius.circular(8)),
        ],
      ])),
      _box(Row(children: [
        stat(Icons.event_note, '${acts.length}', 'Activities'),
        stat(Icons.checklist, '$done/${pack.length}', 'Packed'),
        stat(Icons.payments, spent.toStringAsFixed(0), 'Spent'),
      ])),
      _box(!wxDone
          ? const Text('Loading live weather...')
          : wx == null
              ? const Text('Weather unavailable')
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${t['destination']} right now', style: TextStyle(color: hint, fontSize: 12)),
                  Text('${Net.wxLabel(wx['weathercode'] as num)}   ${(wx['temperature'] as num).round()}°C',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('Wind ${(wx['windspeed'] as num).round()} km/h  •  Local time $localTime', style: TextStyle(color: hint)),
                  if (sun.isNotEmpty) Text(sun, style: TextStyle(color: hint)),
                  if (daily != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 92,
                      child: ListView(scrollDirection: Axis.horizontal, children: [
                        for (var k = 0; k < (daily['time'] as List).length; k++)
                          Container(
                            width: 66,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(14)),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(DateFormat('E').format(DateTime.parse('${(daily['time'] as List)[k]}')), style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(Net.wxLabel((daily['weathercode'] as List)[k] as num).split(' ').first, style: const TextStyle(fontSize: 22)),
                              Text('${((daily['temperature_2m_max'] as List)[k] as num).round()}° / ${((daily['temperature_2m_min'] as List)[k] as num).round()}°', style: const TextStyle(fontSize: 11)),
                            ]),
                          ),
                      ]),
                    ),
                  ],
                ])),
      if ((t['notes'] ?? '').toString().isNotEmpty)
        _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${t['notes']}'),
        ])),
      if (wiki != null && '${wiki!['extract']}'.isNotEmpty)
        _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('About ${wiki!['title']}', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${wiki!['extract']}', maxLines: 7, overflow: TextOverflow.ellipsis),
        ])),
      FilledButton.tonalIcon(onPressed: () => copySummary(spent), icon: const Icon(Icons.ios_share), label: const Text('Copy trip summary')),
    ]);
  }
}

// ----------------------------------------------------------------------- MAP
class TripMap extends StatefulWidget {
  final Rec trip;
  const TripMap({super.key, required this.trip});
  @override
  State<TripMap> createState() => _MapState();
}

class _MapState extends State<TripMap> {
  List<Rec> acts = [];
  LatLng? center;
  bool loading = true;
  int get tid => widget.trip['id'] as int;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    final all = await DB.list('activities', 'trip_id', tid, 'day, time');
    acts = all.where((a) => a['lat'] != null).toList();
    final la = widget.trip['lat'];
    if (la != null) {
      center = LatLng((la as num).toDouble(), (widget.trip['lng'] as num).toDouble());
    } else {
      final ll = await Net.geocode('${widget.trip['destination']}');
      if (ll != null) {
        center = ll;
        await DB.update('trips', {'lat': ll.latitude, 'lng': ll.longitude}, tid);
      }
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (center == null) return const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('Could not locate this destination. Check your internet connection or the destination name.', textAlign: TextAlign.center)));
    return Stack(children: [
      FlutterMap(
        options: MapOptions(initialCenter: center!, initialZoom: 12),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.tripmate.app'),
          MarkerLayer(markers: [
            Marker(
              point: center!,
              width: 48,
              height: 48,
              child: GestureDetector(
                onTap: () => toast(context, '${widget.trip['destination']}'),
                child: const Icon(Icons.location_on, color: Colors.red, size: 44),
              ),
            ),
            for (final a in acts)
              Marker(
                point: LatLng((a['lat'] as num).toDouble(), (a['lng'] as num).toDouble()),
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () => toast(context, '${a['time']}  ${a['title']}  @ ${a['place']}'),
                  child: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Icon(catIcons[a['category']] ?? Icons.place, color: Colors.white, size: 20),
                  ),
                ),
              ),
          ]),
        ],
      ),
      Positioned(
        top: 12,
        left: 12,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text('${acts.length} pinned stop${acts.length == 1 ? '' : 's'}  •  add a "Place" to an activity to pin it'),
          ),
        ),
      ),
      const Positioned(bottom: 4, right: 6, child: Text('© OpenStreetMap contributors', style: TextStyle(fontSize: 10, color: Colors.black87))),
    ]);
  }
}

// ------------------------------------------------------------------- PACKING
class Packing extends StatefulWidget {
  final Rec trip;
  const Packing({super.key, required this.trip});
  @override
  State<Packing> createState() => _PackState();
}

class _PackState extends State<Packing> {
  List<Rec> items = [];
  int get tid => widget.trip['id'] as int;
  static const pcats = ['Clothes', 'Documents', 'Gadgets', 'Toiletries', 'Other'];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    items = await DB.list('packing', 'trip_id', tid, 'id');
    if (mounted) setState(() {});
  }

  Future<void> edit([Rec? p]) async {
    final r = await formSheet(
      context,
      p == null ? 'Add item' : 'Edit item',
      const [F('item', 'Item name'), F('category', 'Category', t: 'choice', o: pcats)],
      p ?? {},
    );
    if (r == null) return;
    final v = <String, Object?>{...r, 'trip_id': tid};
    if (p == null) {
      v['done'] = 0;
      await DB.insert('packing', v);
    } else {
      await DB.update('packing', v, p['id'] as int);
    }
    load();
  }

  Future<void> seed() async {
    final base = <List<String>>[
      ['Passport / ID', 'Documents'], ['Tickets & bookings', 'Documents'], ['T-shirts', 'Clothes'], ['Underwear & socks', 'Clothes'],
      ['Phone charger', 'Gadgets'], ['Power bank', 'Gadgets'], ['Toothbrush', 'Toiletries'], ['Medicines', 'Other'], ['Water bottle', 'Other'],
    ];
    var note = '';
    final la = widget.trip['lat'], ln = widget.trip['lng'];
    if (la != null) {
      final fc = await Net.forecast((la as num).toDouble(), (ln as num).toDouble());
      final d = fc?['daily'] as Map?;
      if (d != null) {
        final hi = (d['temperature_2m_max'] as List).map((e) => (e as num).toDouble()).reduce((a, b) => a > b ? a : b);
        final lo = (d['temperature_2m_min'] as List).map((e) => (e as num).toDouble()).reduce((a, b) => a < b ? a : b);
        final rainy = (d['weathercode'] as List).any((c) => (c as num) >= 51 && (c as num) <= 82);
        if (hi >= 28) base.addAll([['Hat / cap', 'Clothes'], ['Sunglasses', 'Other'], ['Sunscreen', 'Toiletries'], ['Light cotton clothes', 'Clothes']]);
        if (lo <= 15) base.addAll([['Jacket', 'Clothes'], ['Warm sweater', 'Clothes'], ['Scarf & gloves', 'Clothes']]);
        if (rainy) base.addAll([['Umbrella', 'Other'], ['Raincoat', 'Clothes'], ['Waterproof phone pouch', 'Gadgets']]);
        note = 'Smart list built from the forecast (${lo.round()}° to ${hi.round()}°C${rainy ? ', rain expected' : ''})';
      }
    }
    for (final b in base) {
      await DB.insert('packing', {'trip_id': tid, 'item': b[0], 'category': b[1], 'done': 0});
    }
    if (mounted && note.isNotEmpty) toast(context, note);
    load();
  }

  @override
  Widget build(BuildContext context) {
    final done = items.where((p) => p['done'] == 1).length;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(onPressed: () => edit(), child: const Icon(Icons.add)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: [
        _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$done of ${items.length} packed', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: items.isEmpty ? 0 : done / items.length, minHeight: 8, borderRadius: BorderRadius.circular(8)),
        ])),
        if (items.isEmpty)
          FilledButton.tonalIcon(onPressed: seed, icon: const Icon(Icons.auto_awesome), label: const Text('Smart packing list (based on weather)')),
        for (final p in items)
          Card(
            elevation: 0,
            child: ListTile(
              leading: Checkbox(
                value: p['done'] == 1,
                onChanged: (_) async {
                  await DB.update('packing', {'done': p['done'] == 1 ? 0 : 1}, p['id'] as int);
                  load();
                },
              ),
              title: Text('${p['item']}', style: TextStyle(decoration: p['done'] == 1 ? TextDecoration.lineThrough : null)),
              subtitle: Text('${p['category']}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => edit(p)),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  onPressed: () async {
                    if (await confirm(context, 'Remove "${p['item']}"?')) {
                      await DB.delete('packing', p['id'] as int);
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

// -------------------------------------------------------------------- PHOTOS
class Photos extends StatefulWidget {
  final Rec trip;
  const Photos({super.key, required this.trip});
  @override
  State<Photos> createState() => _PhotosState();
}

class _PhotosState extends State<Photos> {
  List<Rec> items = [];
  int get tid => widget.trip['id'] as int;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    items = await DB.list('photos', 'trip_id', tid, 'id DESC');
    if (mounted) setState(() {});
  }

  Future<void> add() async {
    final p = await Net.pick();
    if (p == null || !mounted) return;
    final r = await formSheet(context, 'Add a caption', const [F('caption', 'Caption (optional)', t: 'opt')]);
    await DB.insert('photos', {'trip_id': tid, 'data': p, 'caption': r?['caption'] ?? ''});
    load();
  }

  void view(Rec p) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: InteractiveViewer(child: Image(image: imgOf('${p['data']}'), fit: BoxFit.contain))),
          ListTile(title: Text('${p['caption']}'.isEmpty ? 'No caption' : '${p['caption']}')),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Caption'),
              onPressed: () async {
                Navigator.pop(ctx);
                final r = await formSheet(context, 'Edit caption', const [F('caption', 'Caption', t: 'opt')], p);
                if (r != null) {
                  await DB.update('photos', {'caption': r['caption']}, p['id'] as int);
                  load();
                }
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.delete, color: Colors.red),
              label: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.pop(ctx);
                if (await confirm(context, 'Delete this photo?')) {
                  await DB.delete('photos', p['id'] as int);
                  load();
                }
              },
            ),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton(onPressed: add, child: const Icon(Icons.add_a_photo)),
        body: items.isEmpty
            ? const Center(child: Text('No memories yet. Tap the camera button to add photos'))
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final p = items[i];
                  final cap = '${p['caption']}';
                  return GestureDetector(
                    onTap: () => view(p),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(fit: StackFit.expand, children: [
                        Image(image: imgOf('${p['data']}'), fit: BoxFit.cover),
                        if (cap.isNotEmpty)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              color: Colors.black54,
                              padding: const EdgeInsets.all(6),
                              child: Text(cap, style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                      ]),
                    ),
                  );
                },
              ),
      );
}
