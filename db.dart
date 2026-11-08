import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef Rec = Map<String, Object?>;

class DupEmail implements Exception {}

/// Lightweight local database (JSON tables stored with shared_preferences).
/// Works on Android, iOS, Windows and Chrome (web).
class DB {
  static Future<List<Rec>> _all(String t) async {
    final s = (await SharedPreferences.getInstance()).getString('tbl_$t');
    if (s == null) return [];
    return (jsonDecode(s) as List).map((e) => Map<String, Object?>.from(e as Map)).toList();
  }

  static Future<void> _save(String t, List<Rec> rows) async =>
      (await SharedPreferences.getInstance()).setString('tbl_$t', jsonEncode(rows));

  // Salted SHA-256 (salt = email) - passwords are never stored in plain text.
  static String hash(String email, String pass) =>
      sha256.convert(utf8.encode('$email::$pass')).toString();

  static Future<Rec?> login(String email, String pass) async {
    final h = hash(email, pass);
    for (final u in await _all('users')) {
      if (u['email'] == email && u['pass'] == h) return u;
    }
    return null;
  }

  static Future<Rec?> byEmail(String email) async {
    for (final u in await _all('users')) {
      if (u['email'] == email) return u;
    }
    return null;
  }

  static Future<Rec?> user(int id) async {
    for (final u in await _all('users')) {
      if (u['id'] == id) return u;
    }
    return null;
  }

  static Future<int> insert(String t, Rec v) async {
    final rows = await _all(t);
    if (t == 'users' && rows.any((r) => r['email'] == v['email'])) throw DupEmail();
    final id = rows.fold<int>(0, (m, r) => (r['id'] as int) > m ? r['id'] as int : m) + 1;
    rows.add({...v, 'id': id});
    await _save(t, rows);
    return id;
  }

  static Future<void> update(String t, Rec v, int id) async {
    final rows = await _all(t);
    await _save(t, [for (final r in rows) r['id'] == id ? {...r, ...v, 'id': id} : r]);
  }

  static Future<void> delete(String t, int id) async {
    final rows = await _all(t)..removeWhere((r) => r['id'] == id);
    await _save(t, rows);
  }

  static Future<List<Rec>> list(String t, String col, int id, String order) async {
    final rows = (await _all(t)).where((r) => r[col] == id).toList();
    final keys = order.split(',').map((s) => s.trim().split(' ')).toList();
    rows.sort((a, b) {
      for (final k in keys) {
        final c = ('${a[k[0]]}').compareTo('${b[k[0]]}');
        if (c != 0) return k.length > 1 ? -c : c;
      }
      return 0;
    });
    // numeric ids sort correctly as numbers
    if (order.startsWith('id')) rows.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
    return rows;
  }

  static Future<List<Rec>> trips(int uid) async {
    final ex = await _all('expenses');
    final rows = (await _all('trips')).where((t) => t['user_id'] == uid).map((t) {
      final spent = ex.where((e) => e['trip_id'] == t['id']).fold<double>(0, (s, e) => s + (e['amount'] as num));
      return {...t, 'spent': spent};
    }).toList();
    rows.sort((a, b) => '${a['start_date']}'.compareTo('${b['start_date']}'));
    return rows;
  }

  static Future<void> deleteTrip(int id) async {
    for (final t in ['activities', 'expenses', 'packing', 'photos', 'bookings', 'journal']) {
      await _save(t, (await _all(t))..removeWhere((r) => r['trip_id'] == id));
    }
    await delete('trips', id);
  }
}
