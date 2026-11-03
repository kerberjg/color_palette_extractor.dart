import 'dart:io';

import 'package:color_palette_extractor/color_palette_extractor.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Color Palette',
      home: const PaletteScreen(),
    );
  }
}

class PaletteScreen extends StatefulWidget {
  const PaletteScreen({super.key});

  @override
  State<PaletteScreen> createState() => _PaletteScreenState();
}

ValueNotifier<List<OKLCHColorX>> palette = ValueNotifier<List<OKLCHColorX>>([]);

class _PaletteScreenState extends State<PaletteScreen> {
  final ImagePicker _picker = ImagePicker();

  File? _image;
  bool _picking = false;

  Future<void> _pickImage() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final XFile? picked =
          await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() => _image = File(picked.path));
        final img.Image? decoded =
            img.decodeImage(await File(picked.path).readAsBytes());
        if (decoded != null) {
          DateTime start = DateTime.now();
          final List<OKLCHColorX> extracted = extractPalette(decoded);
          palette.value = extracted;
          DateTime end = DateTime.now();
          print(
              'Palette extraction took: ${end.difference(start).inMilliseconds} ms');
        }
      }
    } on Exception catch (error) {
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: const Text('Could not open the image'),
          content: Text('$error'),
          actions: <CupertinoDialogAction>[
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final File? image = _image;
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Color Palette'),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: _pickImage,
                  child: image == null
                      ? _ImagePickerButton(
                          onPressed: _pickImage,
                          busy: _picking,
                        )
                      : ImagePreview(file: image),
                ),
              ),
            ),
            const Divider(height: 1),
            ListenableBuilder(
                listenable: palette,
                builder: (context, _) {
                  final int totalFrequency = palette.value.fold<int>(
                    0,
                    (sum, color) => sum + color.frequency,
                  );

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: <Widget>[
                          for (final OKLCHColorX color
                              in palette.value) ...<Widget>[
                            Expanded(
                                child: ColorSwatch(
                                    color: color,
                                    totalFrequency: totalFrequency)),
                            if (color != palette.value.last)
                              const SizedBox(width: 12),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
          ],
        ),
      ),
    );
  }
}

/// The tappable placeholder shown in the image area while nothing is selected.
class _ImagePickerButton extends StatelessWidget {
  const _ImagePickerButton({
    required this.onPressed,
    required this.busy,
  });

  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: CupertinoColors.systemGrey4),
        borderRadius: BorderRadius.circular(12),
        color: CupertinoColors.systemGrey6,
      ),
      child: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (busy)
              const CupertinoActivityIndicator()
            else
              Icon(
                CupertinoIcons.photo,
                size: 42,
                color: CupertinoColors.systemGrey,
              ),
            const SizedBox(height: 12),
            Text(
              busy ? 'Opening…' : 'Choose an image',
              style: const TextStyle(
                fontSize: 17,
                color: CupertinoColors.label,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the selected image, scaled to fit the available space.
class ImagePreview extends StatelessWidget {
  const ImagePreview({super.key, required this.file});

  final File file;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        file,
        fit: BoxFit.contain,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) =>
            Center(
          child: Text(
            'Could not display this image.',
            style: CupertinoTheme.of(context).textTheme.textStyle,
          ),
        ),
      ),
    );
  }
}

/// A square filled with [color], labelled with its selectabke hex code.
class ColorSwatch extends StatelessWidget {
  const ColorSwatch(
      {super.key, required this.color, required this.totalFrequency});

  final OKLCHColorX color;
  final int totalFrequency;

  @override
  Widget build(BuildContext context) {
    final Color rgb = color.toColor();
    // Light text on dark swatches, dark text on light ones.
    final bool onLight = rgb.computeLuminance() > 0.6;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: rgb,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: SelectableText(
          '${hexCode(rgb)}\n'
          '${color.toString()}\n'
          '${(color.frequency / totalFrequency * 100).toStringAsFixed(0)}%',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            color: onLight ? CupertinoColors.label : CupertinoColors.white,
          ),
        ),
      ),
    );
  }
}

/// Returns [color] as an upper-case `#RRGGBB` string.
String hexCode(Color color) {
  String channel(double value) =>
      (value * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  final String hex = channel(color.r) + channel(color.g) + channel(color.b);
  return '#${hex.toUpperCase()}';
}
