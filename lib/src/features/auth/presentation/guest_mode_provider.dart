import 'package:flutter_riverpod/legacy.dart';

// StateProvider sederhana untuk melacak status mode tamu
// true = mode tamu aktif, false = user harus login
final guestModeProvider = StateProvider<bool>((ref) => false);
