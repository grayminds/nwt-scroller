import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/bible_data.dart';

class BibleRepository {
  List<BibleBook>? _books;
  final Map<String, List<BibleBook>> _booksByLanguage = {};

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

  Future<List<BibleBook>> loadBooksForLanguage(String language) async {
    if (language == 'English') return loadBooks();
    if (_booksByLanguage.containsKey(language)) return _booksByLanguage[language]!;

    final baseBooks = await loadBooks();
    final langFile = _languageFile(language);
    if (langFile == null) return baseBooks;

    try {
      final jsonStr = await rootBundle.loadString(langFile);
      final List<dynamic> jsonList = json.decode(jsonStr) as List<dynamic>;
      final nameMap = <int, Map<String, dynamic>>{};
      for (final item in jsonList) {
        final map = item as Map<String, dynamic>;
        nameMap[map['number'] as int] = map;
      }

      final translated = baseBooks.map((book) {
        final names = nameMap[book.number];
        if (names == null) return book;
        return book.copyWithNames(
          name: names['name'] as String?,
          abbr: names['abbr'] as String?,
          abbrMed: names['abbrMed'] as String?,
        );
      }).toList();

      _booksByLanguage[language] = translated;
      return translated;
    } catch (e) {
      debugPrint('Failed to load $language bible names: $e');
      return baseBooks;
    }
  }

  String? _languageFile(String language) {
    switch (language) {
      case 'Spanish':
        return 'assets/data/bible_es.json';
      case 'Russian':
        return 'assets/data/bible_ru.json';
      case 'French':
        return 'assets/data/bible_fr.json';
      case 'Italian':
        return 'assets/data/bible_it.json';
      default:
        return null;
    }
  }

  List<BibleBook> get books => _books ?? [];
}
