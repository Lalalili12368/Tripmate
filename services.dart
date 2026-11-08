import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

/// Free public APIs (no keys): OpenStreetMap Nominatim, Wikipedia, Open-Meteo.
class Net {
  static const _h = {'User-Agent': 'TripMateStudentApp/1.0'};
  static final Map<String, Map<String, dynamic>?> _wikiCache = {};

  static Future<LatLng?> geocode(String q) async {
    try {
      final r = await http
          .get(Uri.https('nominatim.openstreetmap.org', '/search', {'q': q, 'format': 'json', 'limit': '1'}), headers: _h)
          .timeout(const Duration(seconds: 8));
      final l = jsonDecode(r.body) as List;
      if (l.isEmpty) return null;
      return LatLng(double.parse('${l[0]['lat']}'), double.parse('${l[0]['lon']}'));
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _wikiOne(String q) async {
    try {
      final r = await http
          .get(Uri.https('en.wikipedia.org', '/api/rest_v1/page/summary/${q.trim()}'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      String? thumb;
      final o = j['originalimage'], t = j['thumbnail'];
      if (o is Map && ((o['width'] ?? 9999) as num) <= 2200) {
        thumb = o['source'] as String?;
      } else if (t is Map) {
        thumb = t['source'] as String?;
      }
      thumb = await _hiRes('${j['title']}') ?? thumb;
      return {'title': j['title'], 'extract': j['extract'] ?? '', 'thumb': thumb};
    } catch (_) {
      return null;
    }
  }

  /// Sharp 1280px lead image (the summary API only gives a 320px thumbnail).
  static Future<String?> _hiRes(String title) async {
    try {
      final r = await http
          .get(Uri.https('en.wikipedia.org', '/w/api.php', {'action': 'query', 'titles': title, 'prop': 'pageimages', 'pithumbsize': '1280', 'redirects': '1', 'format': 'json', 'origin': '*'}))
          .timeout(const Duration(seconds: 8));
      final pages = (jsonDecode(r.body)['query']['pages'] as Map).values;
      for (final p in pages) {
        final t = p['thumbnail'];
        if (t is Map) return t['source'] as String?;
      }
    } catch (_) {}
    return null;
  }

  static final Map<String, List<Map<String, String>>> _photoCache = {};

  /// Landscape photos of a place from Wikimedia Commons (free, no key).
  static Future<List<Map<String, String>>> photos(String q) async {
    if (_photoCache.containsKey(q)) return _photoCache[q]!;
    final out = <Map<String, String>>[];
    try {
      final r = await http
          .get(Uri.https('commons.wikimedia.org', '/w/api.php', {
            'action': 'query', 'generator': 'search', 'gsrsearch': q, 'gsrnamespace': '6', 'gsrlimit': '40',
            'prop': 'imageinfo', 'iiprop': 'url|size', 'iiurlwidth': '1200', 'format': 'json', 'origin': '*',
          }))
          .timeout(const Duration(seconds: 10));
      final pages = (jsonDecode(r.body)['query']['pages'] as Map).values.toList();
      pages.sort((a, b) => ((a['index'] ?? 0) as num).compareTo((b['index'] ?? 0) as num));
      for (final p in pages) {
        final ii = (p['imageinfo'] as List).first as Map;
        final url = '${ii['thumburl'] ?? ii['url']}';
        final low = url.toLowerCase();
        if (!(low.endsWith('.jpg') || low.endsWith('.jpeg'))) continue;
        if (((ii['width'] ?? 0) as num) < 1200 || ((ii['width'] ?? 0) as num) < ((ii['height'] ?? 0) as num)) continue;
        final title = '${p['title']}'.replaceFirst('File:', '').replaceAll(RegExp(r'\.(\w+)$'), '').replaceAll('_', ' ');
        out.add({'url': url, 'title': title});
        if (out.length >= 16) break;
      }
    } catch (_) {}
    return _photoCache[q] = out;
  }

  static Future<Map<String, dynamic>?> forecast(double lat, double lng) async {
    try {
      final r = await http
          .get(Uri.https('api.open-meteo.com', '/v1/forecast', {
            'latitude': '$lat', 'longitude': '$lng', 'current_weather': 'true', 'timezone': 'auto',
            'daily': 'weathercode,temperature_2m_max,temperature_2m_min,sunrise,sunset',
          }))
          .timeout(const Duration(seconds: 8));
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> rates(String base) async {
    try {
      final r = await http.get(Uri.https('open.er-api.com', '/v6/latest/$base')).timeout(const Duration(seconds: 8));
      return (jsonDecode(r.body)['rates'] as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> wiki(String q) async {
    if (_wikiCache.containsKey(q)) return _wikiCache[q];
    var r = await _wikiOne(q);
    if (r == null && q.contains(',')) r = await _wikiOne(q.split(',').first);
    return _wikiCache[q] = r;
  }

  static Future<Map<String, dynamic>?> weather(double lat, double lng) async {
    try {
      final r = await http
          .get(Uri.https('api.open-meteo.com', '/v1/forecast', {'latitude': '$lat', 'longitude': '$lng', 'current_weather': 'true'}))
          .timeout(const Duration(seconds: 8));
      return (jsonDecode(r.body)['current_weather'] as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  static String wxLabel(num c) {
    if (c == 0) return '☀️ Clear sky';
    if (c <= 3) return '⛅ Partly cloudy';
    if (c <= 48) return '🌫️ Foggy';
    if (c <= 67) return '🌧️ Rainy';
    if (c <= 77) return '❄️ Snow';
    if (c <= 82) return '🌦️ Showers';
    if (c >= 95) return '⛈️ Thunderstorm';
    return '☁️ Cloudy';
  }

  /// Opens the gallery and returns a compressed photo as base64 (or null).
  static Future<String?> pick() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1400, imageQuality: 80);
    if (x == null) return null;
    return base64Encode(await x.readAsBytes());
  }
}
