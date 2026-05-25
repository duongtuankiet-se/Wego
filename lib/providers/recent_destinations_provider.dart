import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/place.dart';

part 'recent_destinations_provider.g.dart';

const _kPrefKey = 'recent_destinations';
const _kMaxItems = 5;

@Riverpod(keepAlive: true)
class RecentDestinations extends _$RecentDestinations {
  @override
  Future<List<Place>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kPrefKey) ?? const [];
    return raw
        .map((s) {
          try {
            return Place.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<Place>()
        .toList();
  }

  Future<void> add(Place place) async {
    final current = state.valueOrNull ?? const <Place>[];
    final deduped = [
      place,
      ...current.where((p) => p.id != place.id),
    ].take(_kMaxItems).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kPrefKey,
      deduped.map((p) => jsonEncode(p.toJson())).toList(),
    );
    state = AsyncData(deduped);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefKey);
    state = const AsyncData([]);
  }
}
