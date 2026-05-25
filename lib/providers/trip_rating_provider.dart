import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'trip_rating_provider.freezed.dart';
part 'trip_rating_provider.g.dart';

@freezed
class TripRatingState with _$TripRatingState {
  const factory TripRatingState({
    @Default(0) int stars,
    @Default(<String>{}) Set<String> tags,
  }) = _TripRatingState;
}

@riverpod
class TripRating extends _$TripRating {
  @override
  TripRatingState build() => const TripRatingState();

  void setStars(int n) => state = state.copyWith(stars: n);

  void toggleTag(String tag) {
    final next = Set<String>.from(state.tags);
    next.contains(tag) ? next.remove(tag) : next.add(tag);
    state = state.copyWith(tags: next);
  }

  void reset() => state = const TripRatingState();
}
