import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/services/firebase_service.dart';

final firebaseServiceProvider = Provider<FirebaseService>((ref) => FirebaseService());

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences non inizializzato');
});

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final authNotifierProvider = StateNotifierProvider<AuthNotifier, User?>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<User?> {
  AuthNotifier() : super(null);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> signInAnonymously() async {
    _isLoading = true;
    state = state;
    try {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      state = cred.user;
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      state = state;
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }
}
