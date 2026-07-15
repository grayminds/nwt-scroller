import 'package:nwt_vibration/nwt_vibration.dart';
import '../models/bible_reference.dart';

class LauncherService {
  static const _jwLibraryPackage = 'org.jw.jwlibrary.mobile';

  /// Launch a Bible reference. Tries JW Library first, falls back to jw.org.
  static Future<bool> launch(BibleReference ref, {String language = 'English'}) async {
    final installed = await NwtVibration.isPackageInstalled(_jwLibraryPackage);
    if (installed) {
      final url = ref.toJwLibraryUri(language: language).toString();
      final launched = await NwtVibration.launchUrl(url);
      if (launched) return true;
    }
    // Fall back to jw.org in browser
    final webUrl = ref.toJwOrgUri(language: language).toString();
    return NwtVibration.launchUrl(webUrl);
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
