import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

part 'rating.freezed.dart';
part 'rating.g.dart';

@freezed
class Rating with _$Rating {
  const factory Rating({
    required String id,
    required String tripId,
    required String raterId,
    required String rateeId,
    required int stars,
    String? comment,
    required DateTime createdAt,
  }) = _Rating;

  factory Rating.fromJson(Map<String, dynamic> json) => _$RatingFromJson(json);

  static Rating fromMongo(Map<String, dynamic> doc) => Rating(
    id: (doc['_id'] as ObjectId).oid,
    tripId: doc['trip_id'] is ObjectId
        ? (doc['trip_id'] as ObjectId).oid
        : doc['trip_id'] as String,
    raterId: doc['rater_id'] is ObjectId
        ? (doc['rater_id'] as ObjectId).oid
        : doc['rater_id'] as String,
    rateeId: doc['ratee_id'] is ObjectId
        ? (doc['ratee_id'] as ObjectId).oid
        : doc['ratee_id'] as String,
    stars: (doc['stars'] as num).toInt(),
    comment: doc['comment'] as String?,
    createdAt: doc['created_at'] as DateTime,
  );
}
