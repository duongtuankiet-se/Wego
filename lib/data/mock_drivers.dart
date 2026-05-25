/// Seed data for 3 mock drivers. TripService picks one when a passenger
/// books — replaces real-time driver matching for the demo.
class MockDriver {
  final String name;
  final String phone;
  final String vehicleModel;
  final String vehicleColor;
  final String vehiclePlate;
  final double rating;
  final int totalTrips;
  final double latOffset;
  final double lngOffset;

  const MockDriver({
    required this.name,
    required this.phone,
    required this.vehicleModel,
    required this.vehicleColor,
    required this.vehiclePlate,
    required this.rating,
    required this.totalTrips,
    required this.latOffset,
    required this.lngOffset,
  });
}

const List<MockDriver> kMockDrivers = [
  MockDriver(
    name: 'Trần Quang Minh',
    phone: '+84905111222',
    vehicleModel: 'Toyota Vios',
    vehicleColor: 'Trắng',
    vehiclePlate: '43A-128.66',
    rating: 4.92,
    totalTrips: 1284,
    latOffset: 0.0022,
    lngOffset: 0.0018,
  ),
  MockDriver(
    name: 'Lê Văn Cường',
    phone: '+84905333444',
    vehicleModel: 'Hyundai Accent',
    vehicleColor: 'Bạc',
    vehiclePlate: '43A-256.18',
    rating: 4.86,
    totalTrips: 942,
    latOffset: -0.0019,
    lngOffset: 0.0024,
  ),
  MockDriver(
    name: 'Phạm Đức Tài',
    phone: '+84905555666',
    vehicleModel: 'Honda City',
    vehicleColor: 'Đen',
    vehiclePlate: '43A-378.42',
    rating: 4.95,
    totalTrips: 2103,
    latOffset: 0.0028,
    lngOffset: -0.0017,
  ),
];
