import 'package:flutter_test/flutter_test.dart';
import 'package:hub_reader/sources/cookie_store.dart';

void main() {
  test('cookies apply to the host and its subdomains, merge, and persist', () {
    String? persisted;
    final store = SourceCookieStore(onChanged: (json) => persisted = json);
    store.save(Uri.parse('https://kuromanga.id/'), 'cf_clearance=abc; _ga=1');
    store.save(Uri.parse('https://kuromanga.id/manga/x/'), 'cf_clearance=def');

    expect(store.cookieHeaderFor(Uri.parse('https://kuromanga.id/manga/')), 'cf_clearance=def; _ga=1');
    expect(store.cookieHeaderFor(Uri.parse('https://cdn.kuromanga.id/a.jpg')), contains('cf_clearance=def'));
    expect(store.cookieHeaderFor(Uri.parse('https://otherkuromanga.id/')), isNull);
    expect(store.hasCookie(Uri.parse('https://kuromanga.id/'), 'cf_clearance'), isTrue);

    final restored = SourceCookieStore.fromJson(persisted);
    expect(restored.cookieHeaderFor(Uri.parse('https://kuromanga.id/')), 'cf_clearance=def; _ga=1');
  });
}
