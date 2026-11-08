import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db.dart';
import '../services.dart';
import '../widgets.dart';

class ExploreTab extends StatefulWidget {
  final void Function(String) onPlan;
  const ExploreTab({super.key, required this.onPlan});
  @override
  State<ExploreTab> createState() => _ExploreState();
}

class _ExploreState extends State<ExploreTab> {
  static const spots = [
    'Bali', 'Paris', 'Tokyo', 'Santorini', "Cox's Bazar", 'Maldives', 'Istanbul', 'Kyoto', 'Venice', 'Sundarbans',
    'Dubai', 'Swiss Alps', 'New York City', 'Machu Picchu', 'Cappadocia', 'Phuket',
  ];
  final c = TextEditingController();
  List<Rec> wish = [];
  int uid = 0;

  @override
  void initState() {
    super.initState();
    loadWish();
  }

  Future<void> loadWish() async {
    uid = (await SharedPreferences.getInstance()).getInt('uid') ?? 0;
    wish = await DB.list('wishlist', 'user_id', uid, 'id DESC');
    if (mounted) setState(() {});
  }

  Future<String> _wx(String name) async {
    final ll = await Net.geocode(name);
    if (ll == null) return 'Weather unavailable';
    final w = await Net.weather(ll.latitude, ll.longitude);
    if (w == null) return 'Weather unavailable';
    return '${Net.wxLabel(w['weathercode'] as num)}  •  ${(w['temperature'] as num).round()}°C now';
  }

  void _open(String name) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: SingleChildScrollView(
          child: FutureBuilder<Map<String, dynamic>?>(
            future: Net.wiki(name),
            builder: (_, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
              }
              final w = snap.data;
              final saved = wish.any((x) => x['name'] == name);
              return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (w != null && w['thumb'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network('${w['thumb']}', height: 230, width: double.infinity, fit: BoxFit.cover, filterQuality: FilterQuality.high,
                        errorBuilder: (_, __, ___) => const SizedBox(height: 60)),
                  ),
                const SizedBox(height: 12),
                Text('${w?['title'] ?? name}', style: Theme.of(ctx).textTheme.headlineSmall),
                const SizedBox(height: 6),
                FutureBuilder<String>(future: _wx(name), builder: (_, s) => Chip(label: Text(s.data ?? 'Checking weather...'))),
                const SizedBox(height: 6),
                Text(w == null ? 'No description found, but you can still plan a trip here.' : '${w['extract']}', maxLines: 9, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, String>>>(
                  future: Net.photos(name.split(',').first),
                  builder: (_, ps) {
                    final l = ps.data ?? [];
                    if (l.isEmpty) return const SizedBox.shrink();
                    return SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: l.length > 10 ? 10 : l.length,
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => GalleryPage(imgs: l, start: i))),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(l[i]['url']!, width: 170, height: 120, fit: BoxFit.cover, filterQuality: FilterQuality.high, errorBuilder: (_, __, ___) => const SizedBox(width: 170)),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.flight_takeoff),
                  label: const Text('Plan a trip here'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    widget.onPlan(name);
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  icon: Icon(saved ? Icons.favorite : Icons.favorite_border, color: Colors.red),
                  label: Text(saved ? 'Remove from wishlist' : 'Save to wishlist'),
                  onPressed: () async {
                    if (saved) {
                      for (final x in wish.where((x) => x['name'] == name)) {
                        await DB.delete('wishlist', x['id'] as int);
                      }
                    } else {
                      await DB.insert('wishlist', {'user_id': uid, 'name': name});
                    }
                    await loadWish();
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ]);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text('Explore', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          const Text('Find your next adventure'),
          const SizedBox(height: 14),
          TextField(
            controller: c,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search any place in the world',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => c.text.trim().isEmpty ? null : _open(c.text.trim())),
            ),
            onSubmitted: (v) => v.trim().isEmpty ? null : _open(v.trim()),
          ),
          if (wish.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('❤️ My wishlist', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final w in wish)
                InputChip(
                  label: Text('${w['name']}'),
                  onPressed: () => _open('${w['name']}'),
                  onDeleted: () async {
                    await DB.delete('wishlist', w['id'] as int);
                    loadWish();
                  },
                ),
            ]),
          ],
          const SizedBox(height: 16),
          Text('Popular destinations', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: .85,
            children: [
              for (final s in spots)
                GestureDetector(
                  onTap: () => _open(s),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: FutureBuilder<Map<String, dynamic>?>(
                      future: Net.wiki(s),
                      builder: (_, snap) {
                        final thumb = snap.data?['thumb'] as String?;
                        return Stack(fit: StackFit.expand, children: [
                          Container(color: Theme.of(context).colorScheme.primaryContainer),
                          if (thumb != null) Image.network(thumb, fit: BoxFit.cover, filterQuality: FilterQuality.high, errorBuilder: (_, __, ___) => const SizedBox()),
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(begin: Alignment.center, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87]),
                            ),
                          ),
                          Positioned(left: 12, bottom: 12, right: 12, child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
                        ]);
                      },
                    ),
                  ),
                ),
            ],
          ),
        ]),
      );
}
