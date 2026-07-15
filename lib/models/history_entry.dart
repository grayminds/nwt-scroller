import 'bible_reference.dart';

class HistoryEntry {
  final BibleReference reference;
  final DateTime timestamp;

  const HistoryEntry({
    required this.reference,
    required this.timestamp,
  });

  String get displayLabel => reference.displayLabel;

  Map<String, dynamic> toJson() => {
        'reference': reference.toJson(),
        'timestamp': timestamp.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      reference: BibleReference.fromJson(json['reference'] as Map<String, dynamic>),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
