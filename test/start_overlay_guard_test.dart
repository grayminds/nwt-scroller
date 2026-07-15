import 'package:flutter_test/flutter_test.dart';
import 'package:nwt_scroller/main.dart';

void main() {
  group('OverlayStartGuard', () {
    test('two rapid begins allow at most one start', () {
      final guard = OverlayStartGuard();

      // Simulate three near-simultaneous entrants:  initState auto-start, the
      // lifecycle-resumed re-check, and the Grant Permission button.  Only the
      // first may proceed.
      final first = guard.begin();
      final second = guard.begin();
      final third = guard.begin();

      expect(first, isTrue);
      expect(second, isFalse);
      expect(third, isFalse);
      expect(guard.isRunning, isTrue);
    });

    test('a later start proceeds after the previous one ends', () {
      final guard = OverlayStartGuard();

      expect(guard.begin(), isTrue);
      guard.end();
      expect(guard.isRunning, isFalse);

      // A fresh start attempt (for example a resume after the overlay closed)
      // must be allowed again.
      expect(guard.begin(), isTrue);
    });

    test('end after a failed start clears the guard', () {
      final guard = OverlayStartGuard();

      // Model the try/finally:  begin, the start throws, finally calls end.
      expect(guard.begin(), isTrue);
      try {
        throw StateError('start failed');
      } catch (_) {
        // ignored on purpose
      } finally {
        guard.end();
      }

      expect(guard.isRunning, isFalse);
      expect(guard.begin(), isTrue);
    });
  });
}
