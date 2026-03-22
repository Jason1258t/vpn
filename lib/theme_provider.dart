import 'package:flutter/cupertino.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_provider.g.dart';

@riverpod
class AppTheme extends _$AppTheme {
  @override
  Brightness build() {
    // Начальное состояние — темная тема
    return Brightness.dark;
  }

  void toggle() {
    state = (state == Brightness.light) ? Brightness.dark : Brightness.light;
  }
}