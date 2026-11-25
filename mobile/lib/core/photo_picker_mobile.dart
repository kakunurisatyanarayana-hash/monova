import 'package:image_picker/image_picker.dart';

import 'photo_types.dart';

/// Phone camera or photo library, through the image_picker plugin.
Future<PickedPhoto?> pickPhoto({required bool camera}) async {
  final XFile? file;
  try {
    file = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1400,
      maxHeight: 1400,
      imageQuality: 85,
    );
  } catch (_) {
    throw const PhotoPickException(
      'The camera or photo library could not be opened. Check that MONOVA is allowed to use them in phone settings.',
    );
  }
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  return PickedPhoto(bytes, file.mimeType ?? _mimeFromName(file.name));
}

String _mimeFromName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  return 'application/octet-stream';
}
