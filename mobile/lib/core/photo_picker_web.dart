import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'photo_types.dart';

/// Longest side of a saved card photo, in pixels. Keeps the picture readable and well under the size limit.
const _maxSide = 1200;

/// Opens the browser's file picker. On phone browsers, camera mode asks for the back camera.
/// The picture is scaled down and saved as JPEG, so a large photo from the gallery still fits the limit.
Future<PickedPhoto?> pickPhoto({required bool camera}) {
  final completer = Completer<PickedPhoto?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/png,image/jpeg';
  if (camera) input.setAttribute('capture', 'environment');

  input.onchange = (web.Event _) {
    final files = input.files;
    if (files == null || files.length == 0) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final file = files.item(0)!;
    _shrink(file)
        .then((photo) {
          if (!completer.isCompleted) completer.complete(photo);
        })
        .catchError((Object e) {
          if (!completer.isCompleted) completer.completeError(e);
        });
  }.toJS;

  input.click();
  return completer.future;
}

/// Draws the picture on a canvas no larger than [_maxSide] on its longest side, and returns it as JPEG.
Future<PickedPhoto> _shrink(web.File file) async {
  final url = web.URL.createObjectURL(file);
  try {
    final img = web.HTMLImageElement();
    final loaded = Completer<void>();
    img.onload = (web.Event _) {
      if (!loaded.isCompleted) loaded.complete();
    }.toJS;
    img.onerror = (web.Event _) {
      if (!loaded.isCompleted)
        loaded.completeError(
          StateError('The picture could not be read. Try a different file.'),
        );
    }.toJS;
    img.src = url;
    await loaded.future;

    final w = img.naturalWidth;
    final h = img.naturalHeight;
    final longest = w > h ? w : h;
    final scale = longest > _maxSide ? _maxSide / longest : 1.0;
    final cw = (w * scale).round();
    final ch = (h * scale).round();

    final canvas =
        web.document.createElement('canvas') as web.HTMLCanvasElement;
    canvas.width = cw;
    canvas.height = ch;
    final ctx = canvas.getContext('2d')! as web.CanvasRenderingContext2D;
    ctx.drawImage(img, 0, 0, cw, ch);

    final dataUrl = canvas.toDataURL('image/jpeg', 0.85.toJS);
    final bytes = base64Decode(dataUrl.substring(dataUrl.indexOf(',') + 1));
    return PickedPhoto(bytes, 'image/jpeg');
  } finally {
    web.URL.revokeObjectURL(url);
  }
}
