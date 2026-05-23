import 'dart:io';

// Desktop/mobile: a real file under the system temp dir. On Windows this is
// %TEMP%\temp.json.
File _tempFile() =>
    File('${Directory.systemTemp.path}${Platform.pathSeparator}temp.json');

Future<String> saveTemp(String json) async {
  final f = _tempFile();
  await f.writeAsString(json);
  return f.path;
}

Future<String?> loadTemp() async {
  final f = _tempFile();
  if (!await f.exists()) return null;
  return f.readAsString();
}
