import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/bible_data.dart';

class BibleRepository {
  List<BibleBook>? _books;

  Future<List<BibleBook>> loadBooks() async {
    if (_books != null) return _books!;
    try {
      final jsonStr = await rootBundle.loadString('assets/data/bible.json');
      final List<dynamic> jsonList = json.decode(jsonStr) as List<dynamic>;
      _books = jsonList
          .map((e) => BibleBook.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Failed to load bible data: $e');
      _books = [];
    }
    return _books!;
  }

  List<BibleBook> get books => _books ?? [];
}
