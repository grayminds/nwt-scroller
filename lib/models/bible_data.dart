class BibleBook {
  final int number;
  final String name;
  final String abbr;     // Short: Ge, Ex, Le
  final String abbrMed;  // Medium: Gen., Ex., Lev.
  final List<int> verseCounts;

  const BibleBook({
    required this.number,
    required this.name,
    required this.abbr,
    required this.abbrMed,
    required this.verseCounts,
  });

  int get chapterCount => verseCounts.length;

  int verseCount(int chapter) {
    if (chapter < 1 || chapter > chapterCount) return 0;
    return verseCounts[chapter - 1];
  }

  factory BibleBook.fromJson(Map<String, dynamic> json) {
    return BibleBook(
      number: json['number'] as int,
      name: json['name'] as String,
      abbr: json['abbr'] as String,
      abbrMed: json['abbrMed'] as String,
      verseCounts: (json['verseCounts'] as List)
          .map((e) => (e as num).toInt())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'number': number,
        'name': name,
        'abbr': abbr,
        'abbrMed': abbrMed,
        'verseCounts': verseCounts,
      };
}
