class BibleReference {
  final int book;
  final int chapter;
  final int verse;
  final String bookName;

  const BibleReference({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.bookName,
  });

  /// Formats as BBCCCVVV for JW Library deep link.
  String get code {
    final bb = book.toString().padLeft(2, '0');
    final ccc = chapter.toString().padLeft(3, '0');
    final vvv = verse.toString().padLeft(3, '0');
    return '$bb$ccc$vvv';
  }

  /// JW Library locale codes for supported languages.
  static const languageCodes = {
    'English': 'E',
    'Spanish': 'S',
    'Russian': 'U',
    'French': 'F',
    'Italian': 'I',
  };

  Uri toJwLibraryUri({String language = 'English'}) {
    final locale = languageCodes[language] ?? 'E';
    return Uri.parse('jwlibrary:///finder?bible=$code&wtlocale=$locale');
  }

  /// Book-level open: chapter 1, verse 1 as fallback.
  factory BibleReference.bookLevel(int book, String bookName) {
    return BibleReference(book: book, chapter: 1, verse: 1, bookName: bookName);
  }

  /// Chapter-level open: verse 1.
  factory BibleReference.chapterLevel(int book, int chapter, String bookName) {
    return BibleReference(
      book: book,
      chapter: chapter,
      verse: 1,
      bookName: bookName,
    );
  }

  String get displayLabel => '$bookName $chapter:$verse';

  Map<String, dynamic> toJson() => {
        'book': book,
        'chapter': chapter,
        'verse': verse,
        'bookName': bookName,
      };

  factory BibleReference.fromJson(Map<String, dynamic> json) {
    return BibleReference(
      book: json['book'] as int,
      chapter: json['chapter'] as int,
      verse: json['verse'] as int,
      bookName: json['bookName'] as String,
    );
  }
}
