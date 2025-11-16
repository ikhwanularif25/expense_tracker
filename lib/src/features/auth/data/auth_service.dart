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
  Future<(User? user, bool isNewUser)> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return (null, false); // Batal
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // Ambil status 'isNewUser' dari hasil login
      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      return (userCredential.user, isNewUser); // Kembalikan tuple
    } catch (e) {
      debugPrint("Error Google Sign-In: $e");
      return (null, false);
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
