
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('URL Extraction Logic', () {
    String? extractUrl(String text) {
      final RegExp urlRegExp = RegExp(
        r'https?://(www\.)?instagram\.com/(p|reel|tv|stories)/[\w-]+/?',
        caseSensitive: false,
      );
      final match = urlRegExp.firstMatch(text);
      return match?.group(0);
    }

    test('extracts clean URL', () {
      const text = 'https://www.instagram.com/reel/C12345/';
      expect(extractUrl(text), 'https://www.instagram.com/reel/C12345/');
    });

    test('extracts URL with prefix text', () {
      const text = 'Check out this reel: https://www.instagram.com/reel/C12345/';
      expect(extractUrl(text), 'https://www.instagram.com/reel/C12345/');
    });

    test('extracts URL with suffix text', () {
      const text = 'https://www.instagram.com/reel/C12345/ is amazing';
      expect(extractUrl(text), 'https://www.instagram.com/reel/C12345/');
    });

    test('extracts URL surrounded by text', () {
      const text = 'Yo https://www.instagram.com/reel/C12345/ look at this';
      expect(extractUrl(text), 'https://www.instagram.com/reel/C12345/');
    });

    test('returns null for no URL', () {
      const text = 'Just some random text';
      expect(extractUrl(text), null);
    });
    
    test('handles short instagram links', () {
       const text = 'https://instagram.com/p/12345';
       expect(extractUrl(text), contains('instagram.com/p/12345'));
    });
  });
}
