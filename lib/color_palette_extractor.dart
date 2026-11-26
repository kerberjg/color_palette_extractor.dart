library;

import 'dart:math';

import 'package:image/image.dart' as img;
import 'package:oklch_dart/oklch_dart.dart';

/// Axis size for the 3D bucket grid of colors.
/// This determines how finely the color space is divided into discrete buckets.
/// It MUST be an odd number to ensure a center for each axis.
const int kColorBucketsAxisSize = 7;

/// The factor by which to exaggerate the chroma of palette colors when [exaggerateChroma] is true.
const double kChromaExaggerationFactor = 1.33;

/// Given an [img.Image] file, extracts the palette of themost dominant colors.
///
/// Returns a [List] of length [paletteSize] containing the most dominant colors extracted from the image.
List<OKLCHColor> extractPalette(
  /// The image file to extract the palette from.
  img.Image file, {

  /// The number of colors to extract for the palette.
  int paletteSize = 6,

  /// Whether to exaggerate the palette colors.
  bool exaggerateChroma = false,

  /// Whether to sort the resulting palette by frequency.
  /// If false, will sort by visual similarity.
  bool sortByFrequency = false,
}) {
  final Map<OKLCHColor, int> frequencies = extractPaletteWithFrequencies(
    file,
    paletteSize: paletteSize,
    exaggerateChroma: exaggerateChroma,
  );

  if (sortByFrequency) {
    // dart format off
    return ( //
      frequencies.entries.toList() //
      ..sort((a, b) => b.value.compareTo(a.value)) //
    ).map((e) => e.key).toList();
    // dart format on
  } else {
    return frequencies.keys.toList();
  }
}

/// Given an [img.Image] file, extracts the palette of themost dominant colors.
///
/// Returns a [Map] where the keys are the palette colors and the values are their frequencies.
Map<OKLCHColor, int> extractPaletteWithFrequencies(
  /// The image file to extract the palette from.
  img.Image file, {

  /// The number of colors to extract for the palette.
  int paletteSize = 6,

  /// Whether to exaggerate the palette colors.
  bool exaggerateChroma = false,
}) {
  final int maxAxisIndex = kColorBucketsAxisSize - 1;

  // Discrete 3D array of color buckets.
  // Each axis corresponds to one of the 3 color components.
  List<List<OKLCHColor>> lchBuckets = List.generate(
    kColorBucketsAxisSize * kColorBucketsAxisSize * kColorBucketsAxisSize, //
    (_) => List.empty(growable: true),
    growable: false,
  );

  // Number of pre-palette samples
  final int sampleCount = paletteSize - 2;

  // Handle animated images
  for (img.Image frame in file.frames) {
    // Get image pixels and distribute in discrete buckets
    for (img.Pixel px in frame) {
      // discard sub-alpha pixels
      if (px.a < 255) continue;

      OKLCHColor lch = OKLCHColor.fromColorData(
        ColorData(px.r / 255, px.g / 255, px.b / 255, 1),
      );

      int x = (lch.l * maxAxisIndex).round();
      int y = (lch.c * maxAxisIndex).round();
      int z = (lch.h * maxAxisIndex).round();

      lchBuckets.at3D(x, y, z).add(lch);
    }
  }

  // Sort by occupancy (descending)
  lchBuckets.sort((a, b) => b.length.compareTo(a.length));

  // Sample mean color for all non-empty buckets
  // Map<int, int> modeCounts = {}; // max size: lchBuckets.length
  List<_OKLCHColorX> bucketMeans = [];
  for (List<OKLCHColor> bucket in lchBuckets) {
    if (bucket.isNotEmpty) {
      OKLCHColor mode = _groupedMeanColor(bucket);
      bucketMeans.add(mode.withFrequency(bucket.length));
      // modeCounts[mode.hashCode] = max(
      //   modeCounts[mode.hashCode] ?? 0,
      //   bucket.length,
      // );
    }
  }

  _OKLCHColorX averageColor = _groupedMeanColor(bucketMeans);

  // Sample top 2x candidates from all buckets
  // This is done to ensure we have varied-enough candidates for diversity selection.
  // Sampling just `sampleCount` failed manual testing.
  List<_OKLCHColorX> candidates = bucketMeans.take(sampleCount * 2).toList();

  // Sort candidates by distance from each other (maximize diversity)
  // candidates.sort((a, b) {
  //   double distance(OKLCHColor c1, OKLCHColor c2) {
  //     double dl = c1.lightness - c2.lightness;
  //     double dc = c1.chroma - c2.chroma;
  //     double dh = c1.hue - c2.hue;
  //     return sqrt(dl * dl + dc * dc + dh * dh);
  //   }

  //   double distA = candidates.fold(0.0, (sum, c) => sum + distance(a, c));
  //   double distB = candidates.fold(0.0, (sum, c) => sum + distance(b, c));
  //   return distB.compareTo(distA);
  // });

  // Sort candidates by distance from the global average color (maximize diversity)
  candidates.sort((a, b) {
    double distance(OKLCHColor c1, OKLCHColor c2) {
      double dl = c1.lightness - c2.lightness;
      double dc = c1.chroma - c2.chroma;
      double dh = c1.hue - c2.hue;
      return sqrt(dl * dl + dc * dc + dh * dh);
    }

    double distA = distance(a, averageColor);
    double distB = distance(b, averageColor);
    return distB.compareTo(distA); // descending order
  });

  // Invert order to match the original frequency order
  List<_OKLCHColorX> palette = candidates.take(sampleCount).toList();
  palette.add(bucketMeans.first); //
  palette.add(candidates[sampleCount]);
  palette.add(candidates.last);

  // _OKLCHColorX newMode = _groupedMeanColor(palette);
  // // Sort by distance from each other (doubles close)
  // palette.sort((a, b) {
  //   return modeCounts[b.hashCode]!.compareTo(modeCounts[a.hashCode]!);
  // });

  // Sort by frequency (descending)
  palette.sort((a, b) => b.frequency.compareTo(a.frequency));

  // Remove top (likely duplicate)
  palette.removeAt(0);

  // Stacked sort: the intent is to sort the colors by visual similarity.
  // This sort order was determined by experimentation.

  // sort by chroma
  palette.sort((a, b) => a.chroma.compareTo(b.chroma));
  // sort by lightness
  palette.sort((a, b) => a.lightness.compareTo(b.lightness));
  // sort by hue
  palette.sort((a, b) => a.hue.compareTo(b.hue));

  // Exaggerate the chromas
  for (int i = 0; i < palette.length; i++) {
    palette[i] = _OKLCHColorX(
      palette[i].lightness,
      palette[i].chroma * (exaggerateChroma ? kChromaExaggerationFactor : 1),
      palette[i].hue,
      palette[i].frequency,
    );
  }

  return Map.fromEntries(
    palette.map((color) => MapEntry(color, color.frequency)),
  );
}

/// Calculates the mean color of a given bucket, weighted by frequency.
_OKLCHColorX _groupedMeanColor(List<OKLCHColor> bucket) {
  double accL = 0;
  double accC = 0;
  double accH = 0;
  double count = 0;

  int frequency = 0;

  for (int i = 0; i < bucket.length; i++) {
    frequency =
        bucket[i]
                is _OKLCHColorX //
            ? (bucket[i] as _OKLCHColorX).frequency
            : 1;

    // NOTE: also previously tried:
    // - weighted by extreme chromas
    // - weighted by frequency
    double weight = 1;

    accL += bucket[i].lightness * weight;
    accC += bucket[i].chroma * weight;
    accH += bucket[i].hue * weight;
    count += weight;
  }

  return _OKLCHColorX(
    accL / count,
    accC / count,
    accH / count, //
    frequency,
  );
}

/// Extension on [List] to provide 3D indexing.
/// Assumes the list represents a cube with equal dimensions along each axis.
extension _List3D<T> on List<T> {
  /// Access element at 3D index (x, y, z).
  T at3D(int x, int y, int z) {
    // print('accessing 3D index: ($x, $y, $z)');
    // axis size (assuming cube)
    int axis = pow(length, 1 / 3).round();
    // print('axis size: $axis');

    int index = //
        z + axis * (y + axis * x);

    return this[index];
  }
}

/// Extended [OKLCHColor] with frequency information.
/// To be used with [_groupedMeanColor].
class _OKLCHColorX extends OKLCHColor {
  /// Frequency of occurrence of the color in its given set.
  final int frequency;

  _OKLCHColorX(super.lightness, super.chroma, super.hue, this.frequency)
    : super();
}

/// Extension on [OKLCHColor] to provide axis-normalized values and frequency handling.
extension _OKLCHColorExtension on OKLCHColor {
  /// Axis-normalized lightness.
  double get l => lightness;

  /// Axis-normalized chroma.
  double get h => hue / 360.0;

  /// Axis-normalized hue.
  double get c => chroma * 2.0;

  _OKLCHColorX withFrequency(int frequency) {
    return _OKLCHColorX(lightness, chroma, hue, frequency);
  }
}
