import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db.dart';
import '../widgets.dart';
import 'home.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthState();
}

class _AuthState extends State<AuthPage> {
  final _k = GlobalKey<FormState>();
  final n = TextEditingController(), e = TextEditingController(), ph = TextEditingController(),
      p = TextEditingController(), c = TextEditingController();
  bool reg = false, hide = true, hide2 = true, busy = false;
  int fails = 0;
  DateTime? lockUntil;

  Future<void> submit() async {
    if (!_k.currentState!.validate()) return;
    if (!reg && lockUntil != null && DateTime.now().isBefore(lockUntil!)) {
      toast(context, 'Too many failed attempts. Try again in ${lockUntil!.difference(DateTime.now()).inSeconds + 1}s');
      return;
    }
    setState(() => busy = true);
    final email = e.text.trim().toLowerCase();
    try {
      int uid;
      String name;
      if (reg) {
        if (await DB.byEmail(email) != null) {
          if (mounted) toast(context, 'This email is already registered');
          return;
        }
        name = n.text.trim();
        uid = await DB.insert('users', {'name': name, 'email': email, 'phone': ph.text.trim(), 'pass': DB.hash(email, p.text)});
      } else {
        final r = await DB.login(email, p.text);
        if (r == null) {
          fails++;
          if (fails >= 5) {
            fails = 0;
            lockUntil = DateTime.now().add(const Duration(seconds: 30));
            if (mounted) toast(context, 'Too many failed attempts. Locked for 30 seconds');
          } else if (mounted) {
            toast(context, 'Invalid email or password ($fails/5 attempts)');
          }
          return;
        }
        fails = 0;
        uid = r['id'] as int;
        name = r['name'] as String;
      }
      final sp = await SharedPreferences.getInstance();
      await sp.setInt('uid', uid);
      await sp.setString('name', name);
      await sp.setString('email', email);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Home()));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> forgot() async {
    final r = await formSheet(context, 'Reset password', const [
      F('email', 'Registered email'),
      F('phone', 'Registered phone number'),
      F('neu', 'New password', t: 'pass'),
    ]);
    if (r == null || !mounted) return;
    final email = r['email']!.toLowerCase();
    final u = await DB.byEmail(email);
    if (u == null || u['phone'] != r['phone']) {
      if (mounted) toast(context, 'Email and phone number do not match any account');
      return;
    }
    if (!Rx.pass.hasMatch(r['neu']!)) {
      if (mounted) toast(context, 'New password must meet all the password requirements');
      return;
    }
    await DB.update('users', {'pass': DB.hash(email, r['neu']!)}, u['id'] as int);
    if (mounted) toast(context, 'Password reset. You can log in now.');
  }

  Widget eye(bool h, VoidCallback f) => IconButton(icon: Icon(h ? Icons.visibility : Icons.visibility_off), onPressed: f);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0xFF3E5C3F), cs.primary, const Color(0xFF9BB895)]),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                const Icon(Icons.flight_takeoff, size: 58, color: Colors.white),
                const Text('TripMate', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
                const Text('Plan smarter. Travel better.', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 22),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _k,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        alignment: Alignment.topCenter,
                        child: Column(children: [
                          Text(reg ? 'Create account' : 'Welcome back', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          if (reg) ...[
                            TextFormField(
                              controller: n,
                              decoration: const InputDecoration(labelText: 'Full name', helperText: 'Letters only, at least 3 characters', prefixIcon: Icon(Icons.person)),
                              validator: (v) => Rx.name.hasMatch(v?.trim() ?? '') ? null : 'Enter a valid name (letters only, min 3)',
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: ph,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(labelText: 'Phone', helperText: '10-14 digits, optional + at the start', prefixIcon: Icon(Icons.phone)),
                              validator: (v) => Rx.phone.hasMatch(v?.trim() ?? '') ? null : 'Enter 10-14 digits (optional +)',
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextFormField(
                            controller: e,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(labelText: 'Email', helperText: reg ? 'Example: name@example.com' : null, prefixIcon: const Icon(Icons.email)),
                            validator: (v) => Rx.email.hasMatch(v?.trim() ?? '') ? null : 'Enter a valid email address',
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: p,
                            obscureText: hide,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock), suffixIcon: eye(hide, () => setState(() => hide = !hide))),
                            validator: (v) {
                              if (!reg) return (v ?? '').isEmpty ? 'Enter your password' : null;
                              return Rx.pass.hasMatch(v ?? '') ? null : 'Password does not meet all the requirements';
                            },
                          ),
                          if (reg) ...[
                            const SizedBox(height: 10),
                            PassRules(p.text),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: c,
                              obscureText: hide2,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: 'Confirm password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: eye(hide2, () => setState(() => hide2 = !hide2)),
                                helperText: c.text.isEmpty ? null : (c.text == p.text ? '✓ Passwords match' : null),
                                helperStyle: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                              ),
                              validator: (v) => v == p.text ? null : 'Passwords do not match',
                            ),
                          ],
                          if (!reg)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(onPressed: forgot, child: const Text('Forgot password?')),
                            ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: busy ? null : submit,
                            child: busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(reg ? 'Register' : 'Login'),
                          ),
                          TextButton(
                            onPressed: () => setState(() => reg = !reg),
                            child: Text(reg ? 'Already have an account? Login' : 'New here? Create an account'),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
