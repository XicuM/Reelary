import 'package:flutter_test/flutter_test.dart';
import 'package:reelary/services/media_service.dart';

void main() {
  String? extractUrl(String text) =>
      MediaService.urlPattern.firstMatch(text)?.group(0);

  group('Instagram URLs', () {
    test('extracts clean URL', () {
      const text = 'https://www.instagram.com/reel/C12345/';
      expect(extractUrl(text), 'https://www.instagram.com/reel/C12345/');
      expect(MediaService.extractPostId(text), 'C12345');
    });

    test('extracts URL with username/handle', () {
      const text = 'https://www.instagram.com/viajandoenruta_/reel/DYE2MddMz6i/';
      expect(extractUrl(text), text);
      expect(MediaService.extractPostId(text), 'DYE2MddMz6i');
    });

    test('extracts URL surrounded by text', () {
      const text = 'Yo https://www.instagram.com/reel/C12345/ look at this';
      expect(extractUrl(text), 'https://www.instagram.com/reel/C12345/');
    });

    test('handles short instagram links', () {
      const text = 'https://instagram.com/p/12345';
      expect(extractUrl(text), contains('instagram.com/p/12345'));
      expect(MediaService.extractPostId(text), '12345');
    });
  });

  group('TikTok URLs', () {
    test('extracts video URL and numeric ID', () {
      const text =
          'Check this https://www.tiktok.com/@scout2015/video/6718335390845095173?is_from_webapp=1 wow';
      expect(extractUrl(text),
          'https://www.tiktok.com/@scout2015/video/6718335390845095173');
      expect(MediaService.extractPostId(text), '6718335390845095173');
    });

    test('extracts photo slideshow URL', () {
      const text = 'https://www.tiktok.com/@user.name/photo/7300000000000000000';
      expect(MediaService.extractPostId(text), '7300000000000000000');
    });

    test('extracts vm/vt short links', () {
      expect(MediaService.extractPostId('https://vm.tiktok.com/ZMabc123/'),
          'ZMabc123');
      expect(MediaService.extractPostId('https://vt.tiktok.com/ZSxyz789/'),
          'ZSxyz789');
      expect(MediaService.extractPostId('https://www.tiktok.com/t/ZTabc123/'),
          'ZTabc123');
    });

    test('rejects TikTok profile URLs', () {
      expect(MediaService.extractPostId('https://www.tiktok.com/@scout2015'),
          null);
    });
  });

  test('returns null for no URL', () {
    expect(extractUrl('Just some random text'), null);
    expect(MediaService.extractPostId('https://youtube.com/watch?v=abc'), null);
  });
}
