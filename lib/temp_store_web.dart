import 'package:web/web.dart' as web;

// Web has no filesystem path; persist to localStorage under a fixed key.
const _key = 'temp.json';

Future<String> saveTemp(String json) async {
  web.window.localStorage.setItem(_key, json);
  return 'localStorage["$_key"]';
}

Future<String?> loadTemp() async => web.window.localStorage.getItem(_key);
