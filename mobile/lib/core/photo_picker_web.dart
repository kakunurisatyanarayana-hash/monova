import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'photo_types.dart';

/// Opens the browser's file picker. On phone browsers, camera mode asks for the back camera.
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
    final reader = web.FileReader();
    reader.onload = (web.Event _) {
      final buffer = (reader.result as JSArrayBuffer).toDart;
      final bytes = Uint8List.view(buffer);
      if (!completer.isCompleted) completer.complete(PickedPhoto(bytes, file.type));
    }.toJS;
    reader.readAsArrayBuffer(file);
  }.toJS;

  input.click();
  return completer.future;
}
