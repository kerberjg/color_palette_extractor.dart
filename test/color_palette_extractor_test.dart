import 'dart:ui' show Color;

import 'package:color_palette_extractor/color_palette_extractor.dart';
import 'package:image/image.dart' as img;
import 'package:oklch/oklch.dart';
import 'package:test/test.dart';

bool _isTransparentBlack(OKLCHColor color) {
  final Color rgba = color.toColor();
  return color.lightness == 0 &&
      color.chroma == 0 &&
      color.hue == 0 &&
      color.alpha == 0 &&
      rgba.r == 0 &&
      rgba.g == 0 &&
      rgba.b == 0 &&
      rgba.a == 0;
}

void main() {
  group('extractPalette', () {
    test('pads 1-color image with RGBA(0, 0, 0, 0) up to paletteSize', () {
      final img.Image image = img.Image(width: 10, height: 10);
      img.fill(image, color: img.ColorRgba8(255, 0, 0, 255));

      final List<OKLCHColor> palette = extractPalette(image, paletteSize: 6);
      expect(palette, hasLength(6));
      expect(palette.first.alpha, equals(1.0));
      expect(palette.skip(1).every(_isTransparentBlack), isTrue);
    });

    test('pads 2-color image with RGBA(0, 0, 0, 0) up to paletteSize', () {
      final img.Image image = img.Image(width: 10, height: 10);
      img.fill(image, color: img.ColorRgba8(255, 0, 0, 255));
      for (int y = 0; y < 10; y++) {
        for (int x = 0; x < 5; x++) {
          image.setPixelRgba(x, y, 0, 0, 255, 255);
        }
      }

      final List<OKLCHColor> palette = extractPalette(image, paletteSize: 6);
      expect(palette, hasLength(6));
      expect(palette.take(2).every((c) => c.alpha == 1.0), isTrue);
      expect(palette.skip(2).every(_isTransparentBlack), isTrue);
    });

    test(
      'pads image with paletteSize - 1 distinct colors instead of duplicating',
      () {
        final img.Image image = img.Image(width: 5, height: 1);
        image.setPixelRgba(0, 0, 255, 0, 0, 255);
        image.setPixelRgba(1, 0, 0, 255, 0, 255);
        image.setPixelRgba(2, 0, 0, 0, 255, 255);
        image.setPixelRgba(3, 0, 255, 255, 0, 255);
        image.setPixelRgba(4, 0, 255, 0, 255, 255);

        final Map<OKLCHColor, int> frequencies = extractPaletteWithFrequencies(
          image,
          paletteSize: 6,
        );
        expect(frequencies, hasLength(6));
        expect(
          frequencies.entries
              .where((e) => e.value > 0 && e.key.alpha == 1.0)
              .length,
          equals(5),
        );
        expect(_isTransparentBlack(frequencies.keys.last), isTrue);
        expect(frequencies.values.last, equals(0));
      },
    );

    test(
      'returns paletteSize transparent black entries for transparent image',
      () {
        final img.Image image = img.Image(width: 5, height: 5, numChannels: 4);
        img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));

        final Map<OKLCHColor, int> frequencies = extractPaletteWithFrequencies(
          image,
          paletteSize: 6,
        );
        expect(frequencies, hasLength(6));
        expect(frequencies.keys.every(_isTransparentBlack), isTrue);
        expect(frequencies.values.every((f) => f == 0), isTrue);

        final List<OKLCHColor> palette = extractPalette(image, paletteSize: 6);
        expect(palette, hasLength(6));
        expect(palette.every(_isTransparentBlack), isTrue);
      },
    );

    test(
      'supports sortByFrequency and exaggerateChroma with padded entries',
      () {
        final img.Image image = img.Image(width: 10, height: 10);
        img.fill(image, color: img.ColorRgba8(255, 0, 0, 255));
        for (int y = 0; y < 10; y++) {
          for (int x = 0; x < 3; x++) {
            image.setPixelRgba(x, y, 0, 0, 255, 255);
          }
        }

        final List<OKLCHColor> palette = extractPalette(
          image,
          paletteSize: 6,
          exaggerateChroma: true,
          sortByFrequency: true,
        );
        expect(palette, hasLength(6));
        expect(palette.take(2).every((c) => c.alpha == 1.0), isTrue);
        expect(palette.skip(2).every(_isTransparentBlack), isTrue);
      },
    );

    test(
      'extracts exact paletteSize when enough distinct colors are present',
      () {
        final img.Image image = img.Image(width: 20, height: 20);
        for (int y = 0; y < 20; y++) {
          for (int x = 0; x < 20; x++) {
            image.setPixelRgba(
              x,
              y,
              (x * 12) % 256,
              (y * 12) % 256,
              ((x + y) * 6) % 256,
              255,
            );
          }
        }

        final Map<OKLCHColor, int> frequencies = extractPaletteWithFrequencies(
          image,
          paletteSize: 6,
        );
        expect(frequencies, hasLength(6));
        expect(frequencies.keys.every((c) => c.alpha == 1.0), isTrue);
        expect(frequencies.values.every((f) => f > 0), isTrue);
      },
    );

    test('handles small paletteSize values (1, 2, 3) without crashing', () {
      final img.Image diverse = img.Image(width: 20, height: 20);
      for (int y = 0; y < 20; y++) {
        for (int x = 0; x < 20; x++) {
          diverse.setPixelRgba(
            x,
            y,
            (x * 12) % 256,
            (y * 12) % 256,
            ((x + y) * 6) % 256,
            255,
          );
        }
      }

      final img.Image single = img.Image(width: 4, height: 4);
      img.fill(single, color: img.ColorRgba8(0, 128, 255, 255));

      for (final int size in [1, 2, 3]) {
        expect(extractPalette(diverse, paletteSize: size), hasLength(size));

        final List<OKLCHColor> padded = extractPalette(
          single,
          paletteSize: size,
        );
        expect(padded, hasLength(size));
        expect(padded.first.alpha, equals(1.0));
        expect(padded.skip(1).every(_isTransparentBlack), isTrue);
      }
    });

    test(
      'returns empty for paletteSize 0 and throws RangeError for negative',
      () {
        final img.Image image = img.Image(width: 4, height: 4);
        img.fill(image, color: img.ColorRgba8(255, 0, 0, 255));

        expect(extractPalette(image, paletteSize: 0), isEmpty);
        expect(extractPaletteWithFrequencies(image, paletteSize: 0), isEmpty);
        expect(
          () => extractPalette(image, paletteSize: -1),
          throwsA(isA<RangeError>()),
        );
        expect(
          () => extractPaletteWithFrequencies(image, paletteSize: -1),
          throwsA(isA<RangeError>()),
        );
      },
    );
  });
}
