import '../models/place.dart';

/// Saved-place type — drives icon + tint + "personal vs preset" UX:
/// - personal entries (Home/Work) start `place == null`; tapping them
///   opens the map picker to let the user set the location.
/// - preset entries (airport, city center) already have a [Place] and
///   tap-selects them as the dropoff immediately.
enum SavedPlaceKind { home, work, airport, city }

class SavedPlace {
  final String id;
  final String label;
  final Place? place;
  final SavedPlaceKind kind;

  const SavedPlace({
    required this.id,
    required this.label,
    required this.place,
    required this.kind,
  });

  bool get isPersonal =>
      kind == SavedPlaceKind.home || kind == SavedPlaceKind.work;
}

const List<SavedPlace> kDefaultSavedPlaces = [
  SavedPlace(
    id: 'saved_home',
    label: 'Nhà',
    place: null,
    kind: SavedPlaceKind.home,
  ),
  SavedPlace(
    id: 'saved_work',
    label: 'Công ty',
    place: null,
    kind: SavedPlaceKind.work,
  ),
  SavedPlace(
    id: 'saved_airport',
    label: 'Sân bay Đà Nẵng',
    kind: SavedPlaceKind.airport,
    place: Place(
      id: 'saved_p_airport',
      name: 'Sân bay Quốc tế Đà Nẵng',
      address: 'Hải Châu, Đà Nẵng',
      lat: 16.0439,
      lng: 108.1995,
      icon: 'airplane',
    ),
  ),
  SavedPlace(
    id: 'saved_center',
    label: 'Trung tâm Đà Nẵng',
    kind: SavedPlaceKind.city,
    place: Place(
      id: 'saved_p_center',
      name: 'Trung tâm Đà Nẵng — Cầu Rồng',
      address: 'Bạch Đằng, Hải Châu, Đà Nẵng',
      lat: 16.0612,
      lng: 108.2272,
      icon: 'buildings',
    ),
  ),
];
