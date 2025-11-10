import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

// StateProvider sederhana untuk menyimpan ThemeMode
// Defaultnya mengikuti sistem (ThemeMode.system) atau bisa dipaksa ThemeMode.dark
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
