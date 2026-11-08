import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db.dart';
import '../main.dart';
import '../widgets.dart';

class ProfileTab extends StatefulWidget {
  final List<Rec> trips;
  final VoidCallback onLogout, onChanged;
  const ProfileTab(
      {super.key,
      required this.trips,
      required this.onLogout,
      required this.onChanged});
  @override
  State<ProfileTab> createState() => _ProfileState();
}

class _ProfileState extends State<ProfileTab> {
  Rec? user;
  int uid = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    uid = (await SharedPreferences.getInstance()).getInt('uid')!;
    user = await DB.user(uid);
    if (mounted) setState(() {});
  }

  Future<void> editProfile() async {
    final r = await formSheet(context, 'Edit profile',
        const [F('name', 'Full name'), F('phone', 'Phone')], user ?? {});
    if (r == null) return;
    if (!Rx.name.hasMatch(r['name']!) || !Rx.phone.hasMatch(r['phone']!)) {
      if (mounted) toast(context, 'Enter a valid name and phone number');
      return;
    }
    await DB.update('users', {'name': r['name'], 'phone': r['phone']}, uid);
    (await SharedPreferences.getInstance()).setString('name', r['name']!);
    await load();
    widget.onChanged();
  }

  Future<void> changePass() async {
    final oldC = TextEditingController();
    final newC = TextEditingController();
    var hideOld = true, hideNew = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Change password'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: oldC,
                obscureText: hideOld,
                decoration: InputDecoration(
                  labelText: 'Current password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon:
                        Icon(hideOld ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setS(() => hideOld = !hideOld),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newC,
                obscureText: hideNew,
                onChanged: (_) => setS(() {}),
                decoration: InputDecoration(
                  labelText: 'New password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon:
                        Icon(hideNew ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setS(() => hideNew = !hideNew),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              PassRules(newC.text),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;
    final email = '${user!['email']}';
    if (await DB.login(email, oldC.text) == null) {
      if (mounted) toast(context, 'Current password is wrong');
      return;
    }
    if (!Rx.pass.hasMatch(newC.text)) {
      if (mounted)
        toast(context,
            'New password needs 8+ chars with upper, lower, digit & symbol');
      return;
    }
    await DB.update('users', {'pass': DB.hash(email, newC.text)}, uid);
    if (mounted) toast(context, 'Password updated');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = '${user?['name'] ?? ''}';
    final budget =
        widget.trips.fold<double>(0, (s, t) => s + (t['budget'] as num));
    final spent =
        widget.trips.fold<double>(0, (s, t) => s + (t['spent'] as num));
    Widget stat(String v, String l) => Column(children: [
          Text(v,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          Text(l, style: const TextStyle(color: Colors.white70)),
        ]);
    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient:
                LinearGradient(colors: [cs.primary, const Color(0xFF9BB895)]),
          ),
          child: Column(children: [
            CircleAvatar(
              radius: 38,
              backgroundColor: Colors.white,
              child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                  style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: cs.primary)),
            ),
            const SizedBox(height: 10),
            Text(name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            Text('${user?['email'] ?? ''}',
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              stat('${widget.trips.length}', 'Trips'),
              stat(budget.toStringAsFixed(0), 'Budgeted'),
              stat(spent.toStringAsFixed(0), 'Spent'),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: Column(children: [
            ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Edit profile'),
                subtitle: Text('${user?['phone'] ?? ''}'),
                onTap: editProfile),
            ListTile(
                leading: const Icon(Icons.lock),
                title: const Text('Change password'),
                onTap: changePass),
            SwitchListTile(
              secondary: const Icon(Icons.dark_mode),
              title: const Text('Dark mode'),
              value: themeMode.value == ThemeMode.dark,
              onChanged: (v) async {
                themeMode.value = v ? ThemeMode.dark : ThemeMode.light;
                (await SharedPreferences.getInstance()).setBool('dark', v);
                setState(() {});
              },
            ),
            ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout'),
                onTap: widget.onLogout),
          ]),
        ),
      ]),
    );
  }
}
