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

  /// Language slugs for jw.org URLs.
  static const languageSlugs = {
    'English': 'en',
    'Spanish': 'es',
    'Russian': 'ru',
    'French': 'fr',
    'Italian': 'it',
  };

  /// Book slugs for jw.org URL paths (1-indexed by book number).
  static const bookSlugs = [
    '', // placeholder for 0-index
    'genesis', 'exodus', 'leviticus', 'numbers', 'deuteronomy',
    'joshua', 'judges', 'ruth', '1-samuel', '2-samuel',
    '1-kings', '2-kings', '1-chronicles', '2-chronicles', 'ezra',
    'nehemiah', 'esther', 'job', 'psalms', 'proverbs',
    'ecclesiastes', 'song-of-solomon', 'isaiah', 'jeremiah', 'lamentations',
    'ezekiel', 'daniel', 'hosea', 'joel', 'amos',
    'obadiah', 'jonah', 'micah', 'nahum', 'habakkuk',
    'zephaniah', 'haggai', 'zechariah', 'malachi',
    'matthew', 'mark', 'luke', 'john', 'acts',
    'romans', '1-corinthians', '2-corinthians', 'galatians', 'ephesians',
    'philippians', 'colossians', '1-thessalonians', '2-thessalonians',
    '1-timothy', '2-timothy', 'titus', 'philemon', 'hebrews',
    'james', '1-peter', '2-peter', '1-john', '2-john', '3-john',
    'jude', 'revelation',
  ];

  Uri toJwOrgUri({String language = 'English'}) {
    final langSlug = languageSlugs[language] ?? 'en';
    final bookSlug = (book >= 1 && book < bookSlugs.length)
        ? bookSlugs[book]
        : 'genesis';
    return Uri.parse(
        'https://www.jw.org/$langSlug/library/bible/nwt/books/$bookSlug/$chapter/#v${book}0${chapter}0$verse');
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
