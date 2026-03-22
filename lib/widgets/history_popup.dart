import 'package:flutter/material.dart';
import '../models/history_entry.dart';
import '../theme/scroll_theme.dart';

class HistoryPopup extends StatelessWidget {
  final List<HistoryEntry> entries;
  final ScrollTheme theme;
  final ValueChanged<HistoryEntry> onEntryTap;
  final VoidCallback onClose;

  const HistoryPopup({
    super.key,
    required this.entries,
    required this.theme,
    required this.onEntryTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Text(
                  'History',
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onClose,
                  child: Icon(Icons.close, size: 18, color: theme.textSecondary),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.divider),
          // Entries
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No history yet',
                style: TextStyle(color: theme.textSecondary, fontSize: 13),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return InkWell(
                    onTap: () => onEntryTap(entry),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.history,
                              size: 14, color: theme.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.displayLabel,
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
