import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/mock_places.dart';
import '../models/place.dart';

part 'places_provider.g.dart';

@riverpod
class SearchQuery extends _$SearchQuery {
  @override
  String build() => '';

  void setQuery(String value) => state = value;
  void clear() => state = '';
}

@riverpod
List<Place> filteredPlaces(Ref ref) {
  final q = ref.watch(searchQueryProvider).trim().toLowerCase();
  if (q.isEmpty) return const [];
  return kDanangPlaces
      .where(
        (p) =>
            p.name.toLowerCase().contains(q) ||
            p.address.toLowerCase().contains(q),
      )
      .toList();
}
