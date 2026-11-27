/// A picture chosen by the user, ready to be stored.
class PickedPhoto {
  const PickedPhoto(this.bytes, this.mimeType);

  final List<int> bytes;
  final String mimeType;
}

class PhotoPickException implements Exception {
  const PhotoPickException(this.message);

  final String message;

  @override
  String toString() => message;
}
