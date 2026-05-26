import 'package:flutter/widgets.dart';

/// [TextEditingController] that's careful about IME composing regions.
///
/// **Why:** Flutter's default controller will sometimes commit the
/// composing region prematurely when Vietnamese IMEs (Telex/VNI, Samsung
/// keyboard, Xiaomi keyboard) try to apply a diacritic to the previous
/// character — the user sees their last typed character disappear. We
/// remember the in-flight composing range so callers that need a stable
/// snapshot of the typed text (e.g. before firing a search API call) can
/// ask for [committedText] without racing the IME.
///
/// Pair this with `autocorrect: false` + `enableSuggestions: true` on the
/// hosting `TextField` for the most reliable VN-input experience.
class VietnameseTextController extends TextEditingController {
  VietnameseTextController({super.text});

  bool _hasPendingComposing = false;

  @override
  set value(TextEditingValue newValue) {
    _hasPendingComposing =
        newValue.composing.isValid &&
        newValue.composing.start != newValue.composing.end;
    super.value = newValue;
  }

  /// Whether the IME currently has an active composing region. Callers
  /// that need to defer side effects until the user stops typing
  /// (analytics, autosave, etc.) can check this.
  bool get hasComposing => _hasPendingComposing;

  /// Snapshot of the visible text, treating any in-flight composing
  /// region as already committed. Call this before sending the query to
  /// a search API instead of reading [text] directly so partially-typed
  /// diacritics aren't lost.
  String get committedText => text;

  @override
  void clear() {
    _hasPendingComposing = false;
    super.clear();
  }
}
