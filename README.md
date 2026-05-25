# WeGo — Ride-hailing app with smart carpool matching

> Đồ án môn EXE201 — ứng dụng đặt xe + ghép khách thông minh kiểu Grab/Be cho Đà Nẵng, có thuật toán matching thật trên MongoDB Atlas.

---

## ✨ Tính năng nổi bật

- **2 role end-to-end**: Hành khách (10 màn) + Tài xế (6 màn).
- **Thuật toán ghép khách thông minh** (Phase 3):
  - **Geohash precision 6** (~1.2 km cell) + 9 ô lân cận để tìm trip cùng tuyến.
  - **Bearing < 45°** giữa 2 chuyến (cùng hướng đi).
  - **Dropoff distance < 5 km** (đích gần nhau).
  - `shared_with` tối đa 3 hành khách / xe.
- **Dispatch tài xế gần nhất**:
  - Geohash precision 5 (~5 km) → 9 ô lân cận → fallback precision 4 (~20 km) → cuối cùng pick any online.
  - Sort Haversine distance ascending.
- **Driver location update real-time**: push GPS lên Mongo mỗi 3 giây trong khi navigate.
- **Driver polling**: stream poll Mongo 4 giây tìm trip mới assign.
- **End-to-end booking flow**: search → matching (4 phase) → live trip (3 phase) → payment + rating → wallet/earnings/performance.
- **MongoDB Atlas cloud**: 5 collections (users, drivers, vehicles, trips, ratings) + 5 indexes.

---

## 🛠️ Stack

| Layer | Tech |
|---|---|
| Mobile | Flutter 3.44 · Dart 3.12 |
| State | Riverpod 2.6 + code generation |
| Routing | go_router 14.8 với CustomTransitionPage |
| Map | flutter_map 7 + OpenStreetMap tiles |
| Database | MongoDB Atlas (mongo_dart driver, SCRAM-SHA-1 auth) |
| Models | Freezed immutable + json_serializable |
| Geo | dart_geohash + Haversine custom |

---

## 📁 Cấu trúc project

```
lib/
├── core/
│   ├── theme/        # AppColors, AppTypography, AppSpacing, AppTheme
│   ├── widgets/      # 18 reusable widgets (WgButton, WgMapPin, WgStatusToggle…)
│   ├── utils/        # format, geohash_util, validators
│   └── db/           # MongoService + Collections
├── data/             # Mock data: places, drivers, hotspots, reviews, transactions
├── models/           # Freezed: User, Driver, Vehicle, Trip, Rating, Place, Transaction
├── providers/        # 17 Riverpod providers (auth, trip, driver, matching, polling…)
├── services/         # TripService + DriverService (matching engine ở đây)
├── screens/
│   ├── auth/         # Splash, RoleSelect, Login
│   ├── passenger/    # Home, Search, RideOptions, Matching, LiveTrip, TripSummary
│   ├── driver/       # Home, Navigation, TripCompleted, Earnings, Wallet, Performance
│   └── _dev/         # Showcase, MatchingTest, Seed (chỉ debug)
├── app.dart
├── router.dart
└── main.dart
```

---

## 🚀 Setup local

### Yêu cầu
- Flutter 3.44+
- Android Studio (cho Android emulator) hoặc thiết bị Android thật
- MongoDB Atlas free tier với IP allowlist `0.0.0.0/0`
- Windows: bật **Developer Mode** (cần symlinks cho plugins)

### Các bước

```powershell
git clone https://github.com/volamdp95/EXEWego.git d:\exe
cd d:\exe

# 1. Copy file env
copy .env.example .env
# → Sửa MONGODB_URI thành connection string Atlas của bạn
#   Bắt buộc có: ?authMechanism=SCRAM-SHA-1&authSource=admin

# 2. Cài deps
flutter pub get

# 3. Generate code
dart run build_runner build --delete-conflicting-outputs

# 4. Chạy
flutter run
```

### Cấu trúc `.env`

```
MONGODB_URI=mongodb+srv://USER:PASS@CLUSTER/wego?retryWrites=true&w=majority&appName=EXE201&authMechanism=SCRAM-SHA-1&authSource=admin
MONGODB_DB=wego
APP_ENV=dev
```

**Lưu ý**: `mongo_dart` không tương thích SCRAM-SHA-256 mặc định — phải force SHA-1.

---

## 🎬 Demo flow

### Hành khách (passenger)
1. Splash 2s → Role Select → Login (tên + SĐT VN)
2. Home: map full-screen + sliding panel + 4 shortcut chip
3. Tap "Tìm điểm đến" → Search → chọn (vd: Sân bay)
4. Ride Options: chọn Xe ghép / Xe riêng / Xe 7 chỗ
5. Matching: 4 phase real qua MongoDB
   - T=0: insert trip `pending`
   - T=1.5s: tìm carpool match (nếu shared)
   - T=3s: dispatch nearest driver
   - T=4.5s: navigate live-trip
6. Live Trip: map + driver info + 3-phase state machine
7. Trip Summary: fare breakdown + payment + rating 5 sao + tags

### Tài xế (driver)
1. Login với role=driver → auto-assigned mock vehicle
2. Driver Home: map + heat zones + status toggle (offline/online)
3. Bật online → poll Mongo 4s tìm trip mới
4. Modal incoming trip 15s countdown
5. Nhận → Navigation 20s mock + push GPS mỗi 3s
6. Trip completed → +earnings → quay home
7. Earnings / Wallet / Performance dashboards

### Dev tools (chỉ debug build)
- `/dev/seed`: reset toàn bộ data về initial state
- `/dev/matching-test`: 5 nút test matching engine cô lập
- `/showcase`: design system showcase

---

## 🧮 Thuật toán matching

### `findNearestDriver(pickupLat, pickupLng)` — Dispatch

```
1. Encode pickup geohash precision 5 (~4.9 km cell).
2. Lấy 9 ô lân cận → tạo 9 prefix.
3. Mongo query: status=online AND current_geohash regex ^(prefix|...)
4. Sort Dart-side theo Haversine distance ascending.
5. Fallback precision 4 (~39 km) nếu rỗng.
6. Cuối cùng: pick bất kỳ driver online (đảm bảo demo không stuck).
```

### `findCarpoolMatch(pickup, dropoff, currentPassengerId)` — Ghép khách

```
1. Encode pickup geohash precision 6 (~1.2 km cell) → 9 ô lân cận.
2. Mongo query trips:
   - status = pending
   - type = shared
   - passenger_id != currentPassengerId
   - created_at > now − 10 phút
   - pickup_geohash IN [9 ô]
3. Filter Dart-side:
   - sharedWith.length < 3
   - |bearing_mine − bearing_theirs| < 45° (cùng hướng)
   - Haversine(dropoff_mine, dropoff_theirs) < 5 km
4. Sort created_at ASC (oldest first → giảm wait time).
5. Return first match hoặc null.
```

---

## 📊 Database schema

5 collections, 5 indexes:

```js
users:    { _id, name, phone (unique), role, avatar?, created_at, updated_at }
drivers:  { _id, user_id (unique), name, phone, vehicle_model/color/plate,
            rating_avg, total_trips, status (offline/online/busy/...),
            current_lat/lng/geohash, created_at, updated_at }
vehicles: { _id, driver_id, plate, model, color, type }
trips:    { _id, passenger_id, driver_id?, type (private/shared),
            status (pending/matching/accepted/ongoing/completed/cancelled),
            pickup_lat/lng/address/geohash, dropoff_lat/lng/address/geohash,
            distance_km, duration_min, price, payment_method?,
            shared_with: [ObjectId], created_at, updated_at,
            started_at?, ended_at?, completed_at? }
ratings:  { _id, trip_id, rater_id, ratee_id, stars, tags: [String],
            comment?, created_at }
```

### Indexes
- `users.phone` unique
- `drivers.user_id` unique
- `trips.{pickup_geohash:1, status:1, created_at:-1}`
- `trips.{passenger_id:1, created_at:-1}`
- `trips.{driver_id:1, created_at:-1}`

---

## 📐 Phase history

| Phase | Nội dung | Commit |
|---|---|---|
| 0 + 1A | Setup + theme + 8 widgets + auth + Passenger Home/Search | `0bb84f4` |
| 1B | Ride Options + Matching + Live Trip + Summary | `f060042` |
| 2 | Driver app (6 màn: Home/Navigation/Earnings/Wallet/Performance) | `6f6b7d6` |
| 3 | Matching engine geohash + polish + README | *(latest)* |

---

## 🚧 Out of scope

- Real routing API (Mapbox/Google) — Phase 3 vẽ đường thẳng polyline
- WebSocket realtime (polling 4s + push 3s đủ cho demo)
- Push notification FCM (modal in-app)
- Admin panel
- Multi-language i18n (UI 100% tiếng Việt)
- Production deployment

---

## 📝 License

Đồ án môn học — không thương mại hoá.

Sinh viên: **Lê Cầu Nguyễn**  
Email: `tuanyen1409@gmail.com`  
GitHub: [@volamdp95](https://github.com/volamdp95)
