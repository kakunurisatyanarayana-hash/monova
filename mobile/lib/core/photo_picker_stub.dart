import 'photo_types.dart';

/// Phones need an image plugin for the camera and gallery. Until it is installed, they get a clear message.
Future<PickedPhoto?> pickPhoto({required bool camera}) async {
  throw const PhotoPickException(
    'Taking or uploading a photo is not available on this phone build yet. It needs the image plugin, which is added in the next build.',
  );
}
