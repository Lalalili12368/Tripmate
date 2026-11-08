import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db.dart';
import '../services.dart';
import '../widgets.dart';
import 'auth.dart';
import 'explore.dart';
import 'insights.dart';
import 'profile.dart';
import 'trip_page.dart';

String tripState(Rec t) {
  final now = DateTime.now(), d0 = DateTime(now.year, now.month, now.day);
  final s = DateTime.parse(t['start_date'] as String), e = DateTime.parse(t['end_date'] as String);
  if (d0.isAfter(e)) return 'Completed';
  if (!d0.isBefore(s)) return 'Ongoing';
  return 'Upcoming';
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Rec> trips = [];
  String q = '', name = '';
  int uid = 0, tab = 0;
  String filter = 'All';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    uid = sp.getInt('uid')!;
    name = sp.getString('name') ?? '';
    trips = await DB.trips(uid);
    if (mounted) setState(() {});
  }

  Future<void> logout() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove('uid');
    await sp.remove('name');
    await sp.remove('email');
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthPage()));
  }

  Future<void> edit([Rec? t, String? dest]) async {
    final r = await formSheet(
      context,
      t == null ? 'New trip' : 'Edit trip',
      const [
        F('title', 'Trip title'),
        F('destination', 'Destination (e.g. Bali, Indonesia)'),
        F('start_date', 'Start date', t: 'date'),
        F('end_date', 'End date', t: 'date'),
        F('budget', 'Budget', t: 'number'),
        F('notes', 'Notes (optional)', t: 'opt'),
      ],
      t ?? {'destination': dest ?? ''},
    );
    if (r == null) return;
    if (r['end_date']!.compareTo(r['start_date']!) < 0) {
      if (mounted) toast(context, 'End date must be after start date');
      return;
    }
    if (mounted) toast(context, 'Saving trip...');
    final v = <String, Object?>{...r, 'budget': double.parse(r['budget']!), 'user_id': uid};
    if (t == null || t['lat'] == null || t['destination'] != r['destination']) {
      final ll = await Net.geocode(r['destination']!);
      if (ll != null) {
        v['lat'] = ll.latitude;
        v['lng'] = ll.longitude;
      }
    }
    if (t == null || '${t['cover'] ?? ''}'.isEmpty) {
      final w = await Net.wiki(r['destination']!);
      if (w != null && w['thumb'] != null) v['cover'] = w['thumb'];
    }
    t == null ? await DB.insert('trips', v) : await DB.update('trips', v, t['id'] as int);
    load();
  }

  static const _inspire = ['Bali', 'Kyoto', 'Swiss Alps', 'Santorini', 'Paris', 'Maldives'];
  final _dest = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: tab == 0
          ? FloatingActionButton.extended(onPressed: () => edit(), icon: const Icon(Icons.add), label: const Text('New Trip'))
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.luggage_outlined), selectedIcon: Icon(Icons.luggage), label: 'Trips'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Insights'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      body: tab == 0
          ? _tripsView()
          : tab == 1
              ? ExploreTab(onPlan: (d) {
                  setState(() => tab = 0);
                  edit(null, d);
                })
              : tab == 2
                  ? InsightsTab(trips: trips)
                  : ProfileTab(trips: trips, onLogout: logout, onChanged: load),
    );
  }

  Future<void> _openTrip(Rec t, [int initialTab = 0]) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => TripPage(trip: t, initialTab: initialTab)));
    load();
  }

  void _go(String v) {
    v = v.trim();
    if (v.isEmpty) return;
    _dest.clear();
    FocusScope.of(context).unfocus();
    edit(null, v);
  }

  Widget _heroSearch() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.07), blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: Row(children: [
        Icon(Icons.search, color: Theme.of(context).hintColor),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _dest,
            textInputAction: TextInputAction.go,
            onSubmitted: _go,
            decoration: const InputDecoration(
              hintText: 'Where do you want to go?',
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
        InkWell(
          onTap: () => _go(_dest.text),
          customBorder: const CircleBorder(),
          child: CircleAvatar(radius: 22, backgroundColor: cs.primary, child: Icon(Icons.arrow_forward, color: cs.onPrimary)),
        ),
      ]),
    );
  }

  Widget _destCard(String d) => Padding(
        padding: const EdgeInsets.only(right: 12),
        child: GestureDetector(
          onTap: () => edit(null, d),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              width: 124,
              child: FutureBuilder<Map<String, dynamic>?>(
                future: Net.wiki(d),
                builder: (_, snap) {
                  final thumb = snap.data?['thumb'] as String?;
                  return Stack(fit: StackFit.expand, children: [
                    Container(color: Theme.of(context).colorScheme.primaryContainer),
                    if (thumb != null) Image.network(thumb, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.center, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87]),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Row(children: [
                        Expanded(child: Text(d, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                        const CircleAvatar(radius: 11, backgroundColor: Colors.white, child: Icon(Icons.arrow_forward, size: 13, color: Colors.black87)),
                      ]),
                    ),
                  ]);
                },
              ),
            ),
          ),
        ),
      );

  Widget _qa(IconData i, String l, VoidCallback f) => Expanded(
        child: GestureDetector(
          onTap: f,
          child: Column(children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Icon(i, color: Theme.of(context).colorScheme.primary, size: 28),
            ),
            const SizedBox(height: 6),
            Text(l, style: const TextStyle(fontSize: 12)),
          ]),
        ),
      );

  Widget _tripsView() {
    final cs = Theme.of(context).colorScheme;
    final shown = trips.where((t) => '${t['title']} ${t['destination']}'.toLowerCase().contains(q.toLowerCase()) && (filter == 'All' || tripState(t) == filter)).toList();
    final today = DateTime.now();
    final upcoming = trips.where((t) => DateTime.parse(t['end_date'] as String).isAfter(today)).length;
    final spent = trips.fold<double>(0, (s, t) => s + (t['spent'] as num));
    final nextList = trips.where((t) => tripState(t) != 'Completed').toList();
    final Rec? next = nextList.isEmpty ? null : nextList.first;
    void needTrip(int tabIdx) {
      if (next == null) {
        toast(context, 'Create a trip first');
      } else {
        _openTrip(next, tabIdx);
      }
    }
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 90), children: [
        Row(children: [
          Expanded(child: Text('Hi, ${name.split(' ').first} 👋', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          GestureDetector(
            onTap: () => setState(() => tab = 3),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: cs.primary,
              child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Text('Your Journey,', style: serif(34)),
        Text('Perfectly Planned.', style: serif(34, color: cs.primary)),
        const SizedBox(height: 6),
        Text('Plan trips, track every expense, travel better.', style: TextStyle(color: Theme.of(context).hintColor)),
        const SizedBox(height: 18),
        _heroSearch(),
        const SizedBox(height: 22),
        Row(children: [
          Expanded(child: Text('Inspiring Destinations', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
          TextButton(onPressed: () => setState(() => tab = 1), child: const Text('See all')),
        ]),
        SizedBox(height: 160, child: ListView(scrollDirection: Axis.horizontal, children: [for (final d in _inspire) _destCard(d)])),
        const SizedBox(height: 18),
        Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Row(children: [
          _qa(Icons.add_location_alt_outlined, 'New Trip', () => edit()),
          _qa(Icons.event_note_outlined, 'Itinerary', () => needTrip(1)),
          _qa(Icons.account_balance_wallet_outlined, 'Budget', () => needTrip(3)),
          _qa(Icons.explore_outlined, 'Explore', () => setState(() => tab = 1)),
        ]),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(colors: [kSageDark, kSage]),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _stat('${trips.length}', 'Trips'),
            _stat('$upcoming', 'Upcoming'),
            _stat(spent.toStringAsFixed(0), 'Total spent'),
          ]),
        ),
        const SizedBox(height: 14),
        if (next != null) ...[_nextCard(next), const SizedBox(height: 14)],
        Text('My Trips', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        TextField(
          decoration: const InputDecoration(hintText: 'Search trips or destinations', prefixIcon: Icon(Icons.search)),
          onChanged: (v) => setState(() => q = v),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 40,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final f in ['All', 'Upcoming', 'Ongoing', 'Completed'])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f, style: TextStyle(color: filter == f ? Colors.white : null)),
                  selected: filter == f,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => filter = f),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        if (shown.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: Text('No trips yet. Tap "New Trip" or browse the Explore tab ✈️', textAlign: TextAlign.center)),
          ),
        for (final t in shown) _card(t),
      ]),
    );
  }

  Widget _nextCard(Rec t) {
    final s = DateTime.parse(t['start_date'] as String);
    final now = DateTime.now(), d0 = DateTime(now.year, now.month, now.day);
    final days = s.difference(d0).inDays;
    final big = days <= 0 ? 'Happening now' : '$days day${days == 1 ? '' : 's'} to go';
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => TripPage(trip: t)));
          load();
        },
        child: coverBox(
          '${t['cover'] ?? ''}',
          height: 170,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black26, Colors.black87]),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
              const Text('NEXT ADVENTURE', style: TextStyle(color: Colors.white70, letterSpacing: 2, fontSize: 11)),
              Text(big, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
              Text('${t['title']}  •  ${t['destination']}', style: const TextStyle(color: Colors.white70), overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _stat(String v, String l) => Column(children: [
        Text(v, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
        Text(l, style: const TextStyle(color: Colors.white70)),
      ]);

  Widget _card(Rec t) {
    final s = DateTime.parse(t['start_date'] as String), e = DateTime.parse(t['end_date'] as String);
    final now = DateTime.now(), d0 = DateTime(now.year, now.month, now.day);
    final days = s.difference(d0).inDays;
    final status = d0.isAfter(e) ? 'Completed' : (days <= 0 ? 'Ongoing' : 'In $days day${days == 1 ? '' : 's'}');
    final budget = (t['budget'] as num).toDouble(), spent = (t['spent'] as num).toDouble();
    final over = spent > budget;
    final hint = Theme.of(context).hintColor;
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: InkWell(
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => TripPage(trip: t)));
          load();
        },
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          coverBox(
            '${t['cover'] ?? ''}',
            height: 180,
            child: Stack(children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87]),
                ),
              ),
              Positioned(left: 14, right: 14, bottom: 10, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('${t['title']}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Row(children: [
                  const Icon(Icons.place, size: 14, color: Colors.white70),
                  const SizedBox(width: 4),
                  Expanded(child: Text('${t['destination']}', style: const TextStyle(color: Colors.white70), overflow: TextOverflow.ellipsis)),
                ]),
              ])),
              Positioned(top: 10, left: 12, child: Chip(label: Text(status), visualDensity: VisualDensity.compact, padding: EdgeInsets.zero)),
              Positioned(
                top: 0,
                right: 0,
                child: PopupMenuButton<String>(
                  iconColor: Colors.white,
                  onSelected: (v) async {
                    if (v == 'edit') {
                      edit(t);
                    } else if (await confirm(context, 'Delete "${t['title']}" and all its data?')) {
                      await DB.deleteTrip(t['id'] as int);
                      load();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'del', child: Text('Delete')),
                  ],
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.calendar_month, size: 16),
                const SizedBox(width: 6),
                Text('${DateFormat('d MMM').format(s)} - ${DateFormat('d MMM yyyy').format(e)}'),
              ]),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: budget == 0 ? 0 : (spent / budget).clamp(0, 1),
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                color: over ? Colors.red : null,
              ),
              const SizedBox(height: 4),
              Text('Spent ${spent.toStringAsFixed(0)} / ${budget.toStringAsFixed(0)}',
                  style: TextStyle(color: over ? Colors.red : hint, fontSize: 12)),
            ]),
          ),
        ]),
      ),
    );
  }
}
