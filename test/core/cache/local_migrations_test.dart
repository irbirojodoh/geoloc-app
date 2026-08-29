import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/config/app_config.dart';
import 'package:geoloc_app/core/cache/local_migrations.dart';
import 'package:geoloc_app/data/models/post.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String hiveDir;

  setUp(() async {
    hiveDir =
        './.dart_tool/test_hive_migrations_${DateTime.now().microsecondsSinceEpoch}';
    Hive.init(hiveDir);
  });

  tearDown(() async {
    await Hive.close();
  });

  test('purges persisted 5-char geohash prefixes and records schema v1',
      () async {
    final stale = await Hive.openBox('followed_locations');
    await stale.put('prefix', 'dr5ru');
    await stale.put(
      'row',
      {'geohash_prefix': 'dr5ru', 'name': 'Jakarta Pusat'},
    );
    await stale.close();
    expect(await Hive.boxExists('followed_locations'), isTrue);

    await LocalMigrations.run();

    expect(await Hive.boxExists('followed_locations'), isFalse);
    final meta = await Hive.openBox(AppConfig.appMetaBox);
    expect(meta.get(LocalMigrations.schemaVersionKey), 1);
  });

  test('strips location_name from the offline feed snapshot', () async {
    final box = await Hive.openBox<Map>(AppConfig.feedCacheBox);
    final post = Post.fromJson({
      'id': 'p1',
      'user_id': 'u1',
      'content': 'hello',
      'location_name': 'Jakarta Pusat',
      'address': {'city': 'Jakarta', 'village': 'Gambir'},
      'created_at': '2026-06-27T12:00:00Z',
    });
    await box.put('latest_feed', {
      'posts': [post.toJson()],
      'latitude': -6.2,
      'longitude': 106.8,
      'radius_km': 5,
      'has_more': false,
      'cached_at': DateTime.now().toIso8601String(),
    });

    await LocalMigrations.migrateGeohashPrefixV6();

    final raw = box.get('latest_feed');
    expect(raw, isNotNull);
    final stored = Map<String, dynamic>.from(raw!);
    final posts = stored['posts'] as List;
    final first = Map<String, dynamic>.from(posts.first as Map);
    expect(first.containsKey('location_name'), isFalse);
    expect(first.containsKey('address'), isFalse);
    expect(first['content'], 'hello');
  });

  test('is a no-op when schema is already current', () async {
    final meta = await Hive.openBox(AppConfig.appMetaBox);
    await meta.put(LocalMigrations.schemaVersionKey, 1);

    final keep = await Hive.openBox('followed_locations');
    await keep.put('prefix', 'qqggyn');
    await keep.close();

    await LocalMigrations.run();

    expect(await Hive.boxExists('followed_locations'), isTrue);
  });
}
