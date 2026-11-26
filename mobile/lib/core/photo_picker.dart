/// Chooses a card photo: the camera or an existing picture.
/// The browser build uses a file input, and the phone build uses the image plugin. The right one is picked at compile time.
library;

export 'photo_picker_web.dart' if (dart.library.io) 'photo_picker_mobile.dart';
export 'photo_types.dart';

