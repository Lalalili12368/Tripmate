import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Sage-green palette taken from the design mock-ups.
const kSage = Color(0xFF5A7D5A);
const kSageDark = Color(0xFF3E5C3F);
const kSageSoft = Color(0xFFDCE8D6);
const kPaper = Color(0xFFF1F5ED);

/// Serif display style used for headings (matches the mock-ups).
TextStyle serif(double size, {Color? color, FontWeight? w}) => TextStyle(
      fontFamily: 'serif',
      fontFamilyFallback: const ['Georgia', 'Times New Roman', 'Noto Serif'],
      fontSize: size,
      height: 1.15,
      color: color,
      fontWeight: w ?? FontWeight.w500,
    );

class Rx {
  static final email = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]{2,}$');
  static final pass = RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[^\w\s]).{8,}$');
  static final name = RegExp(r"^[A-Za-z][A-Za-z .'-]{2,}$");
  static final phone = RegExp(r'^\+?\d{10,14}$');
  static final amount = RegExp(r'^\d+(\.\d{1,2})?$');
}

const catIcons = <String, IconData>{
  'Food': Icons.restaurant,
  'Sightseeing': Icons.photo_camera,
  'Transport': Icons.directions_bus,
  'Stay': Icons.hotel,
  'Shopping': Icons.shopping_bag,
  'Other': Icons.more_horiz,
};

class F {
  final String k, l, t; // key, label, type: text|opt|number|date|time|choice
  final List<String> o;
  const F(this.k, this.l, {this.t = 'text', this.o = const []});
}

Future<bool> confirm(BuildContext c, String msg) async =>
    await showDialog<bool>(
      context: c,
      builder: (_) => AlertDialog(
        title: const Text('Are you sure?'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;

void toast(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

/// Generic validated form used for every Create / Update action.
Future<Map<String, String>?> formSheet(BuildContext c, String title, List<F> fs,
    [Map<String, Object?> init = const {}]) {
  final key = GlobalKey<FormState>();
  final ctl = {
    for (final f in fs)
      f.k: TextEditingController(text: '${init[f.k] ?? (f.t == 'choice' ? f.o.first : '')}')
  };
  return showModalBottomSheet<Map<String, String>>(
    context: c,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Form(
          key: key,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 14),
            for (final f in fs)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: f.t == 'choice'
                    ? DropdownButtonFormField<String>(
                        value: ctl[f.k]!.text,
                        decoration: InputDecoration(labelText: f.l),
                        items: [for (final o in f.o) DropdownMenuItem(value: o, child: Text(o))],
                        onChanged: (v) => ctl[f.k]!.text = v!,
                      )
                    : TextFormField(
                        controller: ctl[f.k],
                        readOnly: f.t == 'date' || f.t == 'time',
                        obscureText: f.t == 'pass',
                        keyboardType: f.t == 'number' ? TextInputType.number : null,
                        decoration: InputDecoration(labelText: f.l),
                        validator: (v) {
                          v = v?.trim() ?? '';
                          if (f.t == 'opt') return null;
                          if (v.isEmpty) return 'Required';
                          if (f.t == 'number' && !Rx.amount.hasMatch(v)) return 'Enter a valid amount';
                          return null;
                        },
                        onTap: () async {
                          if (f.t == 'date') {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: DateTime.tryParse(ctl[f.k]!.text) ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (d != null) ctl[f.k]!.text = d.toIso8601String().substring(0, 10);
                          } else if (f.t == 'time') {
                            final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                            if (t != null) {
                              ctl[f.k]!.text =
                                  '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                            }
                          }
                        },
                      ),
              ),
            FilledButton(
              onPressed: () {
                if (key.currentState!.validate()) {
                  Navigator.pop(ctx, {for (final f in fs) f.k: ctl[f.k]!.text.trim()});
                }
              },
              child: const Text('Save'),
            ),
          ]),
        ),
      ),
    ),
  );
}

final Map<String, Uint8List> _imgCache = {};

/// A photo is either an http(s) URL or a base64 string saved by the image picker.
ImageProvider imgOf(String s) {
  if (s.startsWith('http')) return NetworkImage(s);
  return MemoryImage(_imgCache.putIfAbsent(s, () => base64Decode(s)));
}

Widget coverBox(String cover, {double? height, Widget? child}) => Container(
      height: height,
      decoration: BoxDecoration(
        gradient: cover.isEmpty
            ? const LinearGradient(colors: [Color(0xFF5A7D5A), Color(0xFF9BB895)])
            : null,
        image: cover.isEmpty
            ? null
            : DecorationImage(image: imgOf(cover), fit: BoxFit.cover, filterQuality: FilterQuality.high, onError: (_, __) {}),
      ),
      child: child,
    );

Widget card16(Widget child) => Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );

/// Full-screen swipeable, pinch-to-zoom photo viewer.
class GalleryPage extends StatefulWidget {
  final List<Map<String, String>> imgs;
  final int start;
  final Future<void> Function(Map<String, String>)? onSave;
  const GalleryPage({super.key, required this.imgs, this.start = 0, this.onSave});
  @override
  State<GalleryPage> createState() => _GalleryState();
}

class _GalleryState extends State<GalleryPage> {
  late final PageController pc = PageController(initialPage: widget.start);
  late int i = widget.start;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white, title: Text('${i + 1} / ${widget.imgs.length}')),
        body: Column(children: [
          Expanded(
            child: PageView.builder(
              controller: pc,
              itemCount: widget.imgs.length,
              onPageChanged: (v) => setState(() => i = v),
              itemBuilder: (_, k) => InteractiveViewer(
                child: Center(
                  child: Image.network(
                    widget.imgs[k]['url']!,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    loadingBuilder: (c, w, p) => p == null ? w : const Center(child: CircularProgressIndicator()),
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 64),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Text(widget.imgs[i]['title'] ?? '', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
              if (widget.onSave != null) ...[
                const SizedBox(height: 10),
                FilledButton.icon(onPressed: () => widget.onSave!(widget.imgs[i]), icon: const Icon(Icons.bookmark_add), label: const Text('Save to trip photos')),
              ],
            ]),
          ),
        ]),
      );
}

const catColors = <String, Color>{
  'Food': Color(0xFFE0953A),
  'Sightseeing': Color(0xFF8C6BB1),
  'Transport': Color(0xFF4F8FB8),
  'Stay': Color(0xFF3E8E7E),
  'Shopping': Color(0xFFD9658B),
  'Other': Color(0xFF8A9A8A),
};

/// Always-visible password requirements with live ticks + strength meter.
class PassRules extends StatelessWidget {
  final String p;
  const PassRules(this.p, {super.key});
  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    final labels = ['At least 8 characters', 'One uppercase letter (A-Z)', 'One lowercase letter (a-z)', 'One number (0-9)', 'One special symbol (! @ # \$ % ...)'];
    final ok = [p.length >= 8, RegExp(r'[A-Z]').hasMatch(p), RegExp(r'[a-z]').hasMatch(p), RegExp(r'\d').hasMatch(p), RegExp(r'[^\w\s]').hasMatch(p)];
    final score = ok.where((x) => x).length;
    final color = score <= 2 ? Colors.red : (score == 3 ? Colors.orange : (score == 4 ? Colors.lightGreen : Colors.green));
    final label = p.isEmpty ? '' : (score <= 2 ? 'Weak' : (score == 3 ? 'Fair' : (score == 4 ? 'Good' : 'Strong')));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withOpacity(.35), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Your password must contain:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Icon(ok[i] ? Icons.check_circle : Icons.radio_button_unchecked, size: 18, color: ok[i] ? Colors.green : hint),
              const SizedBox(width: 8),
              Text(labels[i], style: TextStyle(fontSize: 13, color: ok[i] ? Colors.green : hint)),
            ]),
          ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: LinearProgressIndicator(value: score / 5, minHeight: 6, color: color, borderRadius: BorderRadius.circular(6))),
          const SizedBox(width: 10),
          SizedBox(width: 52, child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12))),
        ]),
      ]),
    );
  }
}

class DonutChart extends StatelessWidget {
  final List<double> values;
  final List<Color> colors;
  final String center, caption;
  const DonutChart({super.key, required this.values, required this.colors, this.center = '', this.caption = ''});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        height: 150,
        child: CustomPaint(
          painter: _DonutPainter(values, colors, Theme.of(context).dividerColor),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (caption.isNotEmpty) Text(caption, style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
            ]),
          ),
        ),
      );
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final Color empty;
  _DonutPainter(this.values, this.colors, this.empty);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(14);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20;
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) {
      p.color = empty;
      canvas.drawArc(rect, 0, math.pi * 2, false, p);
      return;
    }
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final sweep = values[i] / total * math.pi * 2;
      p.color = colors[i];
      canvas.drawArc(rect, start, sweep > 0.04 ? sweep - 0.03 : sweep, false, p);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => true;
}
