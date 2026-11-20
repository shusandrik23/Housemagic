import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Фото «После» для детских квестов: съёмка/выбор и загрузка в Storage.
class PhotoService {
  PhotoService({FirebaseStorage? storage, ImagePicker? picker})
    : _storageOverride = storage,
      _pickerOverride = picker;

  final FirebaseStorage? _storageOverride;
  final ImagePicker? _pickerOverride;
  FirebaseStorage get _storage => _storageOverride ?? FirebaseStorage.instance;
  ImagePicker get _picker => _pickerOverride ?? ImagePicker();

  /// Возвращает URL загруженного фото или `null`, если съёмку отменили.
  Future<String?> captureAndUpload({
    required String householdId,
    required String questId,
    ImageSource source = ImageSource.camera,
  }) async {
    final file = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 80);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final ref = _storage.ref(
      'households/$householdId/quests/$questId/after_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
