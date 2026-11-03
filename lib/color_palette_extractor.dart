library;

import 'dart:math';
import 'dart:ui' show Color;

import 'package:image/image.dart' as img;
import 'package:oklch/oklch.dart';

List<OKLCHColorX> extractPalette(img.Image file, {int paletteSize = 6}) {
  const int COLOR_AXIS_BUCKETS = 7; // NOTE: this HAS to be an odd number
  const int MAX_INDEX = COLOR_AXIS_BUCKETS - 1;
  List<List<OKLCHColor>> lchBuckets = List.generate(
    COLOR_AXIS_BUCKETS * COLOR_AXIS_BUCKETS * COLOR_AXIS_BUCKETS, //
    (_) => List.empty(growable: true),
    growable: false,
  );

  final int sampleWidth = paletteSize - 2;

  // print(lchBuckets);

  // (handle gifs)
  for (img.Image frame in file.frames) {
    // Get image pixels and distribute in discrete buckets
    for (img.Pixel px in frame) {
      // discard sub-alpha pixels
      if (px.a < 255) continue;

      OKLCHColor lch = OKLCHColor.fromColor(Color.from(
        alpha: 1,
        red: px.r / 255,
        green: px.g / 255,
        blue: px.b / 255,
      ));

      int x = (lch.l * MAX_INDEX).round();
      int y = (lch.c * MAX_INDEX).round();
      int z = (lch.h * MAX_INDEX).round();

      lchBuckets.at3D(x, y, z).add(lch);
    }
  }

  // Sort by frequency (descending)
  lchBuckets.sort((a, b) => b.length.compareTo(a.length));

  // Calculate mode for all non-empty buckets
  Map<int, int> modeCounts = {};
  List<OKLCHColorX> modes = [];
  for (List<OKLCHColor> bucket in lchBuckets) {
    if (bucket.isNotEmpty) {
      OKLCHColor mode = modeColor(bucket);
      modes.add(mode.withFrequency(bucket.length));
      modeCounts[mode.hashCode] = max(
        modeCounts[mode.hashCode] ?? 0,
        bucket.length,
      );
    }
  }

  OKLCHColorX totalMode = modeColor(modes);

  // Get top 2x candidates
  List<OKLCHColorX> candidates = modes.take(sampleWidth * 2).toList();

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

  // Sort candidates by distance from the total mode (maximize diversity)
  candidates.sort((a, b) {
    double distance(OKLCHColor c1, OKLCHColor c2) {
      double dl = c1.lightness - c2.lightness;
      double dc = c1.chroma - c2.chroma;
      double dh = c1.hue - c2.hue;
      return sqrt(dl * dl + dc * dc + dh * dh);
    }

    double distA = distance(a, totalMode);
    double distB = distance(b, totalMode);
    return distB.compareTo(distA); // descending order
  });

  // Invert order to match the original frequency order
  List<OKLCHColorX> palette = candidates.take(sampleWidth).toList();
  palette.add(modes.first);
  palette.add(candidates[sampleWidth]);
  palette.add(candidates.last);
  // palette.add(candidates[candidates.length - 2]);

  // OKLCHColorX newMode = modeColor(palette);
  // // Sort by distance from each other (doubles close)
  // palette.sort((a, b) {
  //   return modeCounts[b.hashCode]!.compareTo(modeCounts[a.hashCode]!);
  // });

  // Sort by frequency (descending)
  palette.sort((a, b) => b.frequency.compareTo(a.frequency));

  // Remove top (likely duplicate)
  palette.removeAt(0);

  // sort by chroma
  palette.sort((a, b) => a.chroma.compareTo(b.chroma));
  // sort by lightness
  palette.sort((a, b) => a.lightness.compareTo(b.lightness));
  // sort by hue
  palette.sort((a, b) => a.hue.compareTo(b.hue));

  // Exaggerate the chromas
  for (int i = 0; i < palette.length; i++) {
    palette[i] = OKLCHColorX(
      palette[i].lightness,
      palette[i].chroma * 1.33,
      palette[i].hue,
      palette[i].frequency,
    );
  }

  return palette;
}

OKLCHColorX modeColor(List<OKLCHColor> bucket) {
  // just kidding, do a mean
  double accL = 0;
  double accC = 0;
  double accH = 0;
  double count = 0;

  int frequency = 0;

  for (int i = 0; i < bucket.length; i++) {
    frequency = bucket[i] is OKLCHColorX //
        ? (bucket[i] as OKLCHColorX).frequency
        : 1;
    // double weight = (1 + bucket[i].chroma * 4);
    // double weight = frequency.toDouble();
    double weight = 1;

    accL += bucket[i].lightness * weight;
    accC += bucket[i].chroma * weight;
    accH += bucket[i].hue * weight;
    // importance: weighted by extreme chromas
    count += weight;
  }

  return OKLCHColorX(
    accL / count,
    accC / count,
    accH / count, //
    frequency,
  );
}

const int MAX_INT = 0x7FFFFFFFFFFFFFFF;

extension List3D<T> on List<T> {
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

class OKLCHColorX extends OKLCHColor {
  final int frequency;

  OKLCHColorX(
    super.lightness,
    super.chroma,
    super.hue,
    this.frequency,
  ) : super();
}

extension OKLCHColorExtension on OKLCHColor {
  double get l => lightness;
  double get h => hue / 360.0;
  double get c => chroma * 2.0;

  OKLCHColorX withFrequency(int frequency) {
    return OKLCHColorX(lightness, chroma, hue, frequency);
  }
}
