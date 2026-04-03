import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter/material.dart';

class ThemeController extends GetxController {
  static const _key = 'isDarkMode';
  final _storage = GetStorage();

  final RxBool _isDarkMode = true.obs;

  bool get isDarkMode => _isDarkMode.value;
  ThemeMode get themeMode => _isDarkMode.value ? ThemeMode.dark : ThemeMode.light;

  @override
  void onInit() {
    super.onInit();
    // Cargar valor persistido, con fallback a true (oscuro) para evitar estados nulos.
    _isDarkMode.value = _storage.read<bool>(_key) ?? true;
  }

  void toggleTheme() {
    _isDarkMode.value = !_isDarkMode.value;
    _storage.write(_key, _isDarkMode.value);
  }

  void setDarkMode(bool value) {
    _isDarkMode.value = value;
    _storage.write(_key, value);
  }
}
