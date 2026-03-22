import 'package:nwt_vibration/nwt_vibration.dart';
import '../models/bible_reference.dart';

class LauncherService {
  static const _jwLibraryPackage = 'org.jw.jwlibrary.mobile';
  static const _playStoreUrl =
      'market://details?id=$_jwLibraryPackage';

  /// Launch a Bible reference in JW Library. Returns true if successful.
  /// Uses native Android Intent with FLAG_ACTIVITY_NEW_TASK so it works
  /// from the overlay Service context.
  static Future<bool> launch(BibleReference ref, {String language = 'English'}) async {
    final url = ref.toJwLibraryUri(language: language).toString();
    final launched = await NwtVibration.launchUrl(url);
    if (launched) return true;
    // JW Library not installed — try Play Store
    return NwtVibration.launchUrl(_playStoreUrl);
  }

  /// Open book at chapter 1 verse 1.
  static Future<bool> launchBook(int book, String bookName, {String language = 'English'}) {
    return launch(BibleReference.bookLevel(book, bookName), language: language);
  }

  /// Open chapter at verse 1.
  static Future<bool> launchChapter(int book, int chapter, String bookName, {String language = 'English'}) {
    return launch(BibleReference.chapterLevel(book, chapter, bookName), language: language);
  }
}
