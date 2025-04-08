// lib/providers/settings_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  List<String> _tags = ['General'];
  String _defaultTag = 'General';
  SharedPreferences? _prefs;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    _tags = _prefs?.getStringList('tags') ?? ['General'];
    _defaultTag = _prefs?.getString('defaultTag') ?? _tags.first;
    notifyListeners();
  }

  List<String> get tags => _tags;
  String get defaultTag => _defaultTag;

  Future<void> addTag(String tag) async {
    if (!_tags.contains(tag)) {
      _tags.add(tag);
      await _prefs?.setStringList('tags', _tags);
      notifyListeners();
    }
  }

  Future<void> removeTag(String tag) async {
    if (_tags.contains(tag) && tag != 'General') {
      _tags.remove(tag);
      if (_defaultTag == tag) {
        _defaultTag = _tags.first;
        await _prefs?.setString('defaultTag', _defaultTag);
      }
      await _prefs?.setStringList('tags', _tags);
      notifyListeners();
    }
  }

  Future<void> setDefaultTag(String tag) async {
    if (_tags.contains(tag)) {
      _defaultTag = tag;
      await _prefs?.setString('defaultTag', _defaultTag);
      notifyListeners();
    }
  }
}
