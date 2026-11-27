import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_store.dart';

const profileKey = 'monova.profile';

/// The person using this phone. Asked for on the first open; used as "you" in splits, groups and the home page.
class LocalProfile {
  const LocalProfile({required this.name, this.phone = '', this.email = ''});

  final String name;
  final String phone;
  final String email;

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone, 'email': email};

  factory LocalProfile.fromJson(Map<String, dynamic> j) => LocalProfile(
        name: '${j['name'] ?? ''}',
        phone: '${j['phone'] ?? ''}',
        email: '${j['email'] ?? ''}',
      );
}

/// Reads the saved profile, or null if none has been set.
Future<LocalProfile?> loadProfile() async {
  final store = await LocalStore.open();
  final rows = store.readList(profileKey);
  if (rows.isEmpty) return null;
  final profile = LocalProfile.fromJson(rows.first);
  return profile.name.isEmpty ? null : profile;
}

Future<void> saveProfile(LocalProfile profile) async {
  final store = await LocalStore.open();
  await store.writeList(profileKey, [profile.toJson()]);
}

class ProfileState {
  const ProfileState({this.loaded = false, this.profile});

  /// False until the saved profile has been read, so the app does not ask for it twice.
  final bool loaded;
  final LocalProfile? profile;
}

class ProfileController extends Notifier<ProfileState> {
  @override
  ProfileState build() {
    _load();
    return const ProfileState();
  }

  Future<void> _load() async {
    final p = await loadProfile();
    state = ProfileState(loaded: true, profile: p);
  }

  Future<void> set(LocalProfile profile) async {
    await saveProfile(profile);
    state = ProfileState(loaded: true, profile: profile);
  }
}

final profileProvider = NotifierProvider<ProfileController, ProfileState>(ProfileController.new);
