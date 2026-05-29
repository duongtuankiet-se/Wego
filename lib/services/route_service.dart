import 'package:mongo_dart/mongo_dart.dart' show ObjectId, where;

import '../core/db/mongo_service.dart';
import '../models/route.dart';

class RouteService {
  RouteService(this._mongo);
  final MongoService _mongo;

  Future<List<RoutePreset>> getActiveRoutes() async {
    final col = await _mongo.routes();
    final cursor = col.find(
      where.eq('is_active', true).sortBy('display_order'),
    );
    final docs = await cursor.toList();
    return docs.map(RoutePreset.fromMongo).toList(growable: false);
  }

  Future<RoutePreset?> getById(String routeId) async {
    final col = await _mongo.routes();
    final doc = await col.findOne(where.id(ObjectId.fromHexString(routeId)));
    return doc == null ? null : RoutePreset.fromMongo(doc);
  }

  Future<RoutePreset?> getByCode(String routeCode) async {
    final col = await _mongo.routes();
    final doc = await col.findOne(where.eq('route_code', routeCode));
    return doc == null ? null : RoutePreset.fromMongo(doc);
  }

  /// Loose match used by the Schedule upsell banner when the user has
  /// picked free-form pickup/dropoff cities that happen to align with
  /// an existing preset (e.g. they typed "Tam Kỳ → Đà Nẵng" by hand;
  /// we can offer them the flat-fare QN-DN route).
  Future<RoutePreset?> findByEndpoints({
    required String pickupCity,
    required String dropoffCity,
  }) async {
    final col = await _mongo.routes();
    final pickup = _normalize(pickupCity);
    final dropoff = _normalize(dropoffCity);
    if (pickup.isEmpty || dropoff.isEmpty) return null;

    final cursor = col.find(where.eq('is_active', true));
    final docs = await cursor.toList();
    for (final doc in docs) {
      final route = RoutePreset.fromMongo(doc);
      final routePickup = _normalize(route.pickupCity);
      final routeDropoff = _normalize(route.dropoffCity);
      final pickupMatches =
          pickup.contains(routePickup) || routePickup.contains(pickup);
      final dropoffMatches =
          dropoff.contains(routeDropoff) || routeDropoff.contains(dropoff);
      if (pickupMatches && dropoffMatches) return route;
    }
    return null;
  }

  /// Strip diacritics + lowercase so the match works on either Latin
  /// "Da Nang" or accented "Đà Nẵng" inputs.
  String _normalize(String s) {
    const diacritic =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
    const plain =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyydAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
    final buf = StringBuffer();
    for (final ch in s.runes) {
      final str = String.fromCharCode(ch);
      final idx = diacritic.indexOf(str);
      buf.write(idx >= 0 ? plain[idx] : str);
    }
    return buf.toString().trim().toLowerCase();
  }
}
