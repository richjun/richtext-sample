import 'package:flutter_test/flutter_test.dart';
import 'package:richtext/temp_store.dart';

// On the Dart VM the conditional import resolves to temp_store_io.dart, so this
// exercises the real desktop storage path (system temp dir).
void main() {
  test('saveTemp then loadTemp returns the same payload', () async {
    const payload = '{"objectId":"box-1","paragraphs":[]}';
    final where = await saveTemp(payload);
    expect(where, isNotEmpty);
    final back = await loadTemp();
    expect(back, payload);
  });
}
