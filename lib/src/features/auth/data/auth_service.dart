import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart'; // Untuk debugPrint

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // API v6.2.1 (terbaru) menggunakan constructor default (tanpa scopes)
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Stream untuk memantau status login
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Fungsi Login dengan Google
  Future<User?> signInWithGoogle() async {
    try {
      // 1. Memulai alur Google Sign-In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null; // Pengguna membatalkan
      }

      // 2. Mendapatkan detail autentikasi (INI ADALAH FUTURE, BUTUH AWAIT)
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 3. Membuat kredensial Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Login ke Firebase
      final userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      debugPrint("Error Google Sign-In: $e");
      return null;
    }
  }

  // Fungsi Logout
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}

// --- Provider untuk AuthService ---
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// --- Provider untuk Stream Status Login ---
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});
