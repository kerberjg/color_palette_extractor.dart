import 'dart:async';
import 'dart:convert' show base64Decode, jsonEncode;
import 'dart:typed_data' show Uint8List;
import 'dart:io';

import 'package:color_palette_extractor/color_palette_extractor.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

const int kDefaultPort = 8080;
const String kDefaultHost = 'localhost';

void main(List<String> arguments) async {
  final int port = Platform.environment.containsKey('PORT')
      ? int.parse(Platform.environment['PORT']!)
      : kDefaultPort;

  final String host = Platform.environment.containsKey('HOST')
      ? Platform.environment['HOST']!
      : kDefaultHost;

  final bool isProduction = Platform.environment['ENV'] == 'production';

  Pipeline pipeline = const Pipeline();
  if (!isProduction) {
    pipeline = pipeline.addMiddleware(logRequests());
  }

  final server = await io.serve(
    pipeline.addHandler(handleRequest), //
    host,
    port,
  );

  // Enable content compression
  server.autoCompress = true;
  print('Listening at http://${server.address.host}:${server.port}');
}

const int kDefaultCount = 6;

FutureOr<Response> handleRequest(Request request) async {
  // Return 404 on non `/` requests
  if (request.url.path != '') {
    return Response.notFound('Not Found');
  }

  final int count =
      int.tryParse(request.url.queryParameters['count'] ?? '') ?? //
      kDefaultCount;
  final String? url = request.url.queryParameters['url'];
  final String? base64 = request.url.queryParameters['base64'];
  final String? format = request.url.queryParameters['format'];
  final String? type = request.url.queryParameters['type'];

  /*
   *  Decode image data
   */
  late final Uint8List imageData;

  if (url == null && base64 == null) {
    return Response.badRequest(
      body: 'Either "url" or "base64" query parameter must be provided.',
    );
  } else if (url != null) {
    // Fetch image from URL
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      return Response.internalServerError(
        body: 'Failed to fetch image from URL: HTTP ${res.statusCode}',
      );
    }

    imageData = res.bodyBytes;
  } else if (base64 != null) {
    // Decode image from base64 string
    imageData = base64Decode(base64);
  } else {
    return Response.badRequest(
      body: 'Only one of "url" or "base64" query parameter must be provided.',
    );
  }

  late final Image image = decodeImage(imageData)!;

  /*
   *  Extract color palette from the image
   */
  final palette = extractPalette(image, paletteSize: count);

  /*
   *  Return the extracted color palette as JSON
   */
  return Response.ok(
    jsonEncode({'palette': palette.map((c) => c.rgbHex).toList()}),
    headers: {'Content-Type': 'application/json'},
  );
}
