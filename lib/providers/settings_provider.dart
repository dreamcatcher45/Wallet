import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/database_helper.dart';

/// Tag model that supports allowance details.
class Tag {
  String name;
  double? allowanceLimit; // Allowance amount; if null then no allowance set.
  int duration; // Duration in days. Defaults to 30.
  DateTime? allowanceStart; // Start of the allowance period.

  Tag({
    required this.name,
    this.allowanceLimit,
    this.duration = 30,
    this.allowanceStart,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'allowanceLimit': allowanceLimit,
      'duration': duration,
      'allowanceStart': allowanceStart?.toIso8601String(),
    };
  }

  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      name: map['name'],
      allowanceLimit: map['allowanceLimit'] != null ? (map['allowanceLimit'] as num).toDouble() : null,
      duration: map['duration'] ?? 30,
      allowanceStart: map['allowanceStart'] != null ? DateTime.parse(map['allowanceStart']) : null,
    );
  }
}

class SettingsProvider with ChangeNotifier {
  List<Tag> _tags = [];
  String _defaultTag = 'General';
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  SettingsProvider() {
    loadTags();
  }

  Future<void> loadTags() async {
    _tags = await _dbHelper.getTags();
    // If no tags exist, create the default "General" tag.
    if (_tags.isEmpty) {
      await _dbHelper.insertTag(Tag(name: 'General', duration: 30));
      _tags = await _dbHelper.getTags();
    }
    _defaultTag = _tags.first.name;
    notifyListeners();
  }

  List<Tag> get tags => _tags;
  String get defaultTag => _defaultTag;

  Future<void> addTag(String tagName) async {
    if (!_tags.any((tag) => tag.name.toLowerCase() == tagName.toLowerCase())) {
      Tag newTag = Tag(name: tagName, duration: 30);
      await _dbHelper.insertTag(newTag);
      await loadTags();
    }
  }

  Future<void> removeTag(String tagName) async {
    // Disallow deleting the General tag.
    if (tagName.toLowerCase() != 'general') {
      await _dbHelper.deleteTag(tagName);
      await loadTags();
    }
  }

  Future<void> updateTag(Tag tag) async {
    await _dbHelper.updateTag(tag);
    await loadTags();
  }

  Future<void> setDefaultTag(String tagName) async {
    if (_tags.any((tag) => tag.name.toLowerCase() == tagName.toLowerCase())) {
      _defaultTag = tagName;
      notifyListeners();
    }
  }
}
