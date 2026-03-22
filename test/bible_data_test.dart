import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwt_scroller/models/bible_data.dart';
import 'package:nwt_scroller/models/bible_reference.dart';
import 'package:nwt_scroller/models/history_entry.dart';

void main() {
  late List<BibleBook> books;

  setUpAll(() {
    final file = File('assets/data/bible.json');
    final jsonStr = file.readAsStringSync();
    final List<dynamic> jsonList = json.decode(jsonStr) as List<dynamic>;
    books = jsonList
        .map((e) => BibleBook.fromJson(e as Map<String, dynamic>))
        .toList();
  });

  group('Bible data loading', () {
    test('loads 66 books', () {
      expect(books.length, 66);
    });

    test('first book is Genesis', () {
      expect(books.first.name, 'Genesis');
      expect(books.first.number, 1);
    });

    test('last book is Revelation', () {
      expect(books.last.name, 'Revelation');
      expect(books.last.number, 66);
    });

    test('Genesis has 50 chapters', () {
      expect(books[0].chapterCount, 50);
    });

    test('Psalms has 150 chapters', () {
      final psalms = books.firstWhere((b) => b.name == 'Psalms');
      expect(psalms.chapterCount, 150);
    });

    test('Psalm 119 has 176 verses', () {
      final psalms = books.firstWhere((b) => b.name == 'Psalms');
      expect(psalms.verseCount(119), 176);
    });

    test('Jude has 1 chapter', () {
      final jude = books.firstWhere((b) => b.name == 'Jude');
      expect(jude.chapterCount, 1);
    });

    test('single-chapter books', () {
      final singleChapter = ['Obadiah', 'Philemon', '2 John', '3 John', 'Jude'];
      for (final name in singleChapter) {
        final book = books.firstWhere((b) => b.name == name);
        expect(book.chapterCount, 1, reason: '$name should have 1 chapter');
      }
    });
  });

  group('URI generation', () {
    test('Genesis 1:1 → 01001001', () {
      final ref = BibleReference(
        book: 1, chapter: 1, verse: 1, bookName: 'Genesis',
      );
      expect(ref.code, '01001001');
      expect(ref.toJwLibraryUri().toString(),
          'jwlibrary:///finder?bible=01001001');
    });

    test('Revelation 22:21 → 66022021', () {
      final ref = BibleReference(
        book: 66, chapter: 22, verse: 21, bookName: 'Revelation',
      );
      expect(ref.code, '66022021');
    });

    test('Psalm 119:176 → 19119176', () {
      final ref = BibleReference(
        book: 19, chapter: 119, verse: 176, bookName: 'Psalms',
      );
      expect(ref.code, '19119176');
    });
  });

  group('History serialization', () {
    test('round-trip', () {
      final entry = HistoryEntry(
        reference: BibleReference(
          book: 1, chapter: 1, verse: 1, bookName: 'Genesis',
        ),
        timestamp: DateTime(2026, 3, 21, 12, 0, 0),
      );

      final json = entry.toJson();
      final restored = HistoryEntry.fromJson(json);

      expect(restored.reference.book, 1);
      expect(restored.reference.chapter, 1);
      expect(restored.reference.verse, 1);
      expect(restored.reference.bookName, 'Genesis');
      expect(restored.timestamp, DateTime(2026, 3, 21, 12, 0, 0));
      expect(restored.displayLabel, 'Genesis 1:1');
    });
  });
}
