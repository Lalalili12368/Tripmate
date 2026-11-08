import 'package:flutter/material.dart';
import '../db.dart';
import '../widgets.dart';

class _Badge {
  final String title, desc;
  final IconData icon;
  final bool ok;
  _Badge(this.title, this.desc, this.icon, this.ok);
}

class InsightsTab extends StatefulWidget {
  final List<Rec> trips;
  const InsightsTab({super.key, required this.trips});
  @override
  State<InsightsTab> createState() => _InsightsState();
}

class _InsightsState extends State<InsightsTab> {
  bool loading = true;
  final Map<String, double> cat = {};
  int acts = 0, photos = 0, journal = 0, days = 0, food = 0;
  bool budgetMaster = false, packed = false;
  final Set<String> places = {};

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant InsightsTab old) {
    super.didUpdateWidget(old);
    // Reload whenever the parent's trip list changes so the tab stays live.
    if (!identical(old.trips, widget.trips) ||
        old.trips.length != widget.trips.length) {
      load();
    }
  }

  Future<void> load() async {
    // Reset everything first so re-running this method is safe.
    cat.clear();
    places.clear();
    acts = photos = journal = days = food = 0;
    budgetMaster = packed = false;
    if (mounted) setState(() => loading = true);

    for (final t in widget.trips) {
      final id = t['id'] as int;
      final ex = await DB.list('expenses', 'trip_id', id, 'id');
      for (final x in ex) {
        final k = '${x['category']}';
        cat[k] = (cat[k] ?? 0) + (x['amount'] as num).toDouble();
      }
      final a = await DB.list('activities', 'trip_id', id, 'id');
      acts += a.length;
      food += a.where((x) => x['category'] == 'Food').length;
      photos += (await DB.list('photos', 'trip_id', id, 'id')).length;
      journal += (await DB.list('journal', 'trip_id', id, 'id')).length;
      final pk = await DB.list('packing', 'trip_id', id, 'id');
      if (pk.isNotEmpty && pk.every((p) => p['done'] == 1)) packed = true;

      final spent = ex.fold<double>(0, (s, e) => s + (e['amount'] as num));
      if (ex.isNotEmpty && spent <= (t['budget'] as num)) budgetMaster = true;

      places.add('${t['destination']}'.split(',').first.trim());
      days += DateTime.parse('${t['end_date']}')
              .difference(DateTime.parse('${t['start_date']}'))
              .inDays +
          1;
    }
    if (mounted) setState(() => loading = false);
  }

  String personality() {
    if (cat.isEmpty)
      return 'Rookie Traveller 🌱|Log some expenses and activities to discover your travel style.';
    final top = cat.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    const map = {
      'Food':
          'The Foodie 🍜|You travel with your stomach. Local cuisine is your top priority.',
      'Sightseeing':
          'The Explorer 🧭|You chase landmarks, views and unforgettable experiences.',
      'Transport':
          'The Road Warrior 🚆|You love the journey as much as the destination.',
      'Stay':
          'The Comfort Seeker 🏨|A great bed and a great view matter most to you.',
      'Shopping':
          'The Collector 🛍️|You never come home without a bag full of treasures.',
      'Other':
          'The Free Spirit 🌈|Your spending is as unpredictable as your adventures.',
    };
    return map[top] ?? map['Other']!;
  }

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    final totalSpent = cat.values.fold<double>(0, (a, b) => a + b);
    final keys = catIcons.keys.toList();
    final badges = [
      _Badge('First Steps', 'Create your first trip', Icons.flag,
          widget.trips.isNotEmpty),
      _Badge('Globetrotter', 'Plan 3 or more trips', Icons.public,
          widget.trips.length >= 3),
      _Badge('Master Planner', 'Add 10 activities', Icons.event_available,
          acts >= 10),
      _Badge('Photographer', 'Save 5 photos', Icons.photo_camera, photos >= 5),
      _Badge('Storyteller', 'Write 3 journal entries', Icons.auto_stories,
          journal >= 3),
      _Badge('Budget Master', 'Finish a trip within budget', Icons.savings,
          budgetMaster),
      _Badge('Packed & Ready', 'Tick off a full packing list', Icons.luggage,
          packed),
      _Badge('Foodie', 'Plan 3 food activities', Icons.restaurant, food >= 3),
    ];
    final unlocked = badges.where((b) => b.ok).length;
    final pers = personality().split('|');
    final w = (MediaQuery.of(context).size.width - 32 - 12) / 2;
    Widget tile(IconData i, String v, String l) => Expanded(
          child: card16(Column(children: [
            Icon(i, color: Theme.of(context).colorScheme.primary),
            Text(v,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(l, style: TextStyle(color: hint, fontSize: 12)),
          ])),
        );
    return SafeArea(
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Row(children: [
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Insights',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.bold)),
                              const Text('Your travel life in numbers'),
                            ]),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: load,
                        icon: const Icon(Icons.refresh),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: const LinearGradient(
                            colors: [Color(0xFF3E5C3F), Color(0xFF7FA37B)]),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('YOUR TRAVEL PERSONALITY',
                                style: TextStyle(
                                    color: Colors.white70,
                                    letterSpacing: 2,
                                    fontSize: 11)),
                            const SizedBox(height: 6),
                            Text(pers[0],
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800)),
                            Text(pers.length > 1 ? pers[1] : '',
                                style: const TextStyle(color: Colors.white70)),
                          ]),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      tile(Icons.luggage, '${widget.trips.length}', 'Trips'),
                      const SizedBox(width: 8),
                      tile(Icons.calendar_month, '$days', 'Travel days'),
                      const SizedBox(width: 8),
                      tile(Icons.place, '${places.length}', 'Places'),
                    ]),
                    Row(children: [
                      tile(Icons.event_note, '$acts', 'Activities'),
                      const SizedBox(width: 8),
                      tile(Icons.photo_library, '$photos', 'Photos'),
                      const SizedBox(width: 8),
                      tile(Icons.edit_note, '$journal', 'Journal'),
                    ]),
                    card16(Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Where your money goes',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Row(children: [
                            DonutChart(
                                values: [for (final k in keys) cat[k] ?? 0],
                                colors: [for (final k in keys) catColors[k]!],
                                center: totalSpent.toStringAsFixed(0),
                                caption: 'total spent'),
                            const SizedBox(width: 16),
                            Expanded(
                              child: totalSpent == 0
                                  ? Text('No expenses yet',
                                      style: TextStyle(color: hint))
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                          for (final k in keys)
                                            if ((cat[k] ?? 0) > 0)
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 3),
                                                child: Row(children: [
                                                  Icon(Icons.circle,
                                                      size: 10,
                                                      color: catColors[k]),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                      child: Text(
                                                          '$k  ${((cat[k]! / totalSpent) * 100).round()}%')),
                                                ]),
                                              ),
                                        ]),
                            ),
                          ]),
                        ])),
                    card16(Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Budget vs spending',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (widget.trips.isEmpty)
                            Text('No trips yet', style: TextStyle(color: hint)),
                          for (final t in widget.trips)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Expanded(
                                          child: Text('${t['title']}',
                                              overflow: TextOverflow.ellipsis)),
                                      Text(
                                          '${(t['spent'] as num).toStringAsFixed(0)} / ${(t['budget'] as num).toStringAsFixed(0)}',
                                          style: TextStyle(
                                              color: hint, fontSize: 12)),
                                    ]),
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: (t['budget'] as num) == 0
                                          ? 0
                                          : ((t['spent'] as num) /
                                                  (t['budget'] as num))
                                              .clamp(0, 1)
                                              .toDouble(),
                                      minHeight: 8,
                                      borderRadius: BorderRadius.circular(8),
                                      color: (t['spent'] as num) >
                                              (t['budget'] as num)
                                          ? Colors.red
                                          : null,
                                    ),
                                  ]),
                            ),
                        ])),
                    Row(children: [
                      const Text('🏆 Achievements',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Chip(
                          label: Text('$unlocked / ${badges.length}'),
                          visualDensity: VisualDensity.compact),
                    ]),
                    const SizedBox(height: 8),
                    Wrap(spacing: 12, runSpacing: 12, children: [
                      for (final b in badges)
                        Container(
                          width: w,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: b.ok
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withOpacity(.5),
                          ),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(b.ok ? b.icon : Icons.lock_outline,
                                    size: 30,
                                    color: b.ok ? Colors.amber.shade800 : hint),
                                const SizedBox(height: 6),
                                Text(b.title,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: b.ok ? null : hint)),
                                Text(b.desc,
                                    style:
                                        TextStyle(fontSize: 12, color: hint)),
                              ]),
                        ),
                    ]),
                    const SizedBox(height: 30),
                  ]),
            ),
    );
  }
}
