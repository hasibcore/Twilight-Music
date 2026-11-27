import 'dart:convert';
import '../../core/services/firebase_service.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/services/user_database_service.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  static const String _sessionKey = 'twilight_user_session';
  final FirebaseService _firebaseService = FirebaseService();

  UserProfile? _currentUser;

  AuthRepositoryImpl() {
    _loadSavedSession();
  }

  void _loadSavedSession() {
    try {
      final jsonStr = LocalStorageService.getString(_sessionKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        final name = map['name'] as String? ?? '';
        final email = map['email'] as String? ?? '';
        final isGuest = map['isGuest'] as bool? ?? false;

        // Only restore if it was a non-guest custom verified session
        if (!isGuest &&
            name.isNotEmpty &&
            !name.toLowerCase().contains('guest') &&
            email.isNotEmpty &&
            !email.toLowerCase().contains('guest@')) {
          _currentUser = UserProfile(
            uid: map['uid'] as String? ?? 'usr_${email.hashCode.abs()}',
            name: name,
            email: email,
            avatarUrl: map['avatarUrl'] as String? ?? '',
            isGuest: false,
          );
          AppLogger.info('Restored user session: ${_currentUser?.email}');
          return;
        }
      }
    } catch (e) {
      AppLogger.error('Failed to load user session: $e');
    }

    // Default to clean Guest Listener session until user explicitly signs in
    _currentUser = const UserProfile(
      uid: 'guest_local_user',
      name: 'Guest Listener',
      email: '',
      avatarUrl: '',
      isGuest: true,
    );
  }

  Future<void> _persistSession(UserProfile user) async {
    try {
      final map = {
        'uid': user.uid,
        'name': user.name,
        'email': user.email,
        'avatarUrl': user.avatarUrl,
        'isGuest': user.isGuest,
      };
      await LocalStorageService.setString(_sessionKey, jsonEncode(map));
    } catch (e) {
      AppLogger.error('Failed to persist user session: $e');
    }
  }

  @override
  Future<UserProfile> signInAsGuest() async {
    _currentUser = const UserProfile(
      uid: 'guest_local_user',
      name: 'Guest Listener',
      email: '',
      avatarUrl: '',
      isGuest: true,
    );
    await _persistSession(_currentUser!);
    return _currentUser!;
  }

  @override
  Future<UserProfile> signInWithGoogle() async {
    // In production with Firebase Google Auth or fast-link
    _currentUser = const UserProfile(
      uid: 'google_user_active',
      name: 'Google User',
      email: 'user@gmail.com',
      avatarUrl: '',
      isGuest: false,
    );
    await _persistSession(_currentUser!);
    return _currentUser!;
  }

  @override
  Future<UserProfile> signInWithEmail(String email, String password) async {
    // 1. Authenticate against user database table — typed credentials must match stored database records
    final dbUser = await UserDatabaseService.authenticateUser(
      email: email,
      password: password,
    );

    // 2. Also sync with Firebase REST if configured
    try {
      await _firebaseService.signIn(email: email, password: password);
    } catch (_) {}

    _currentUser = UserProfile(
      uid: dbUser['uid'] as String? ?? 'usr_${email.hashCode.abs()}',
      name: (dbUser['displayName'] as String?)?.isNotEmpty == true
          ? dbUser['displayName'] as String
          : email.split('@').first,
      email: dbUser['email'] as String? ?? email,
      avatarUrl: dbUser['avatarUrl'] as String? ?? '',
      isGuest: false,
    );

    await _persistSession(_currentUser!);
    return _currentUser!;
  }

  @override
  Future<UserProfile> registerWithEmail(String email, String password, String name) async {
    // 1. Register into persistent user database table (enforces unique email)
    final dbUser = await UserDatabaseService.registerUser(
      email: email,
      password: password,
      displayName: name,
    );

    // 2. Also register into Firebase REST if configured
    try {
      await _firebaseService.signUp(
        email: email,
        password: password,
        displayName: name,
      );
    } catch (_) {}

    _currentUser = UserProfile(
      uid: dbUser['uid'] as String,
      name: dbUser['displayName'] as String,
      email: dbUser['email'] as String,
      avatarUrl: dbUser['avatarUrl'] as String? ?? '',
      isGuest: false,
    );

    await _persistSession(_currentUser!);
    return _currentUser!;
  }

  @override
  Future<void> signOut() async {
    await LocalStorageService.remove(_sessionKey);
    _currentUser = const UserProfile(
      uid: 'guest_local_user',
      name: 'Guest Listener',
      email: '',
      avatarUrl: '',
      isGuest: true,
    );
  }

  @override
  Future<UserProfile?> getCurrentUser() async {
    return _currentUser;
  }
}
