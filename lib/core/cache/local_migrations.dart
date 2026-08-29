import 'package:hive_flutter/hive_flutter.dart';

import '../../config/app_config.dart';

/// One-time on-disk upgrades that must run before providers read Hive.
///
/// Schema 1: followed-location cells grew from 5-char to 6-char geohash
/// prefixes. Cassandra unfollows are idempotent, so a stale 5-char
/// `DELETE /locations/:geohash/follow` returns 200 while deleting nothing.
/// Drop any persisted prefixes and let the next `GET /locations/following`
/// supply server-owned identifiers. Also drop cached `location_name` /
/// `address` on posts — those labels are now street-level and change.
class LocalMigrations {
  LocalMigrations._();

  /// Bump when a new one-time disk rewrite is required.
  static const int currentSchemaVersion = 1;

  static const String schemaVersionKey = 'schema_version';

  /// Runs pending migrations. Safe to call on every launch.
  static Future<void> run() async {
    final meta = await Hive.openBox(AppConfig.appMetaBox);
    final current = meta.get(schemaVersionKey);
    final version = current is int ? current : 0;
    if (version >= currentSchemaVersion) return;

    if (version < 1) {
      await migrateGeohashPrefixV6();
    }

    await meta.put(schemaVersionKey, currentSchemaVersion);
  }

  /// Purge persisted follow prefixes and stale post location labels.
  static Future<void> migrateGeohashPrefixV6() async {
    await purgeFollowedLocationCaches();
    await stripCachedPostLocationLabels();
  }

  /// Deletes Hive boxes that stored `geohash_prefix` as a durable key.
  static Future<void> purgeFollowedLocationCaches() async {
    for (final name in AppConfig.followedLocationCacheBoxes) {
      await _deleteBoxIfPresent(name);
    }
  }

  /// Removes `location_name` / `address` from the offline feed snapshot.
  static Future<void> stripCachedPostLocationLabels() async {
    try {
      if (!await Hive.boxExists(AppConfig.feedCacheBox)) return;
      final box = await Hive.openBox<Map>(AppConfig.feedCacheBox);
      for (final key in box.keys) {
        final raw = box.get(key);
        if (raw == null) continue;
        final data = Map<String, dynamic>.from(raw);
        final posts = data['posts'];
        if (posts is! List) continue;
        data['posts'] = posts.map(_stripLocationFields).toList();
        await box.put(key, data);
      }
    } catch (_) {
      // Cache rewrite must not block startup.
    }
  }

  static Map<String, dynamic> _stripLocationFields(dynamic post) {
    final json = Map<String, dynamic>.from(post as Map);
    json.remove('location_name');
    json.remove('address');
    return json;
  }

  static Future<void> _deleteBoxIfPresent(String name) async {
    try {
      if (Hive.isBoxOpen(name)) {
        final box = Hive.box(name);
        await box.clear();
        await box.close();
      }
      if (await Hive.boxExists(name)) {
        await Hive.deleteBoxFromDisk(name);
      }
    } catch (_) {
      // Missing or locked boxes are fine — the identifier is gone either way.
    }
  }
}
