/// Chooses a card photo: the camera or an existing picture. The platform-specific part is picked at compile time.
library;

export 'photo_picker_stub.dart' if (dart.library.js_interop) 'photo_picker_web.dart';
export 'photo_types.dart';
