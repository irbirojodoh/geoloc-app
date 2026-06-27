# Media, Caching & Ambient UI

Client-side patterns for R2 media, feed performance, and the animated shell background.

## Media upload (R2)

**Primary flow — Pattern B (presigned PUT):**

1. `POST /api/v1/media/upload-url` → `upload_url`, `key`
2. PUT bytes to R2 with a **plain Dio client** (no JWT); `Content-Type` must match step 1
3. Attach **`key`** on profile/post mutations — never presigned URLs

**Fallback — Pattern A (multipart):** `POST /api/v1/upload/{avatar|cover|post}` if Pattern B fails.

| Service | File | Role |
|---------|------|------|
| `UploadService` | `lib/services/upload_service.dart` | Pattern B + A fallback, validation (10 MB, JPEG/PNG/GIF/WebP) |
| `MediaService` | `lib/services/media_service.dart` | `GET /api/v1/media/sign`, in-memory URL cache, hydrate offline posts |
| `MediaUrl` | `lib/core/media/media_url.dart` | Detect R2 URLs, parse object keys |
| `MediaContentType` | `lib/core/media/media_content_type.dart` | MIME types for presigned PUT |

### Attach keys (not URLs)

| Action | Payload fields |
|--------|----------------|
| Avatar / cover | `avatar_key`, `cover_key` on `PUT /api/v1/users/me` |
| Create post | `media_keys` (max 4 combined with external `media_urls`) |

API responses resolve keys → presigned GET URLs in `profile_picture_url`, `cover_image_url`, `media_urls` (~15 min TTL).

## Display rules

- **`AuthNetworkImage`** — loads presigned/external URLs **without** Bearer token
- Optional **`mediaKey`** — refresh via `/media/sign` on 403 without parsing URL
- **`UserAvatar`** — accepts `imageKey` for key-only offline/cached data
- Presigned URLs are ephemeral; do not persist long-term in Hive/SQLite

## Feed caching (stale-while-revalidate)

| Component | File | Behavior |
|-----------|------|----------|
| `FeedCacheService` | `lib/services/feed_cache_service.dart` | Hive box `feed_cache`; stores posts via `Post.toCacheJson()` (no presigned URLs) |
| `FeedPostMerge` | `lib/core/cache/feed_post_merge.dart` | Merge refreshes without rotating image URLs when keys unchanged |
| `FeedNotifier` | `lib/presentation/providers/feed_provider.dart` | Show disk cache instantly; background fetch; `refreshIfStale()` (5 min TTL on resume) |

## Post detail (instant open)

| Component | File | Behavior |
|-----------|------|----------|
| `PostPreviewCache` | `lib/presentation/providers/post_preview_cache.dart` | In-memory seed from list screens |
| `openPostDetail` | `lib/presentation/helpers/open_post_detail.dart` | Seed cache + push; sync back on pop |

List → detail uses cached `Post` immediately; API refresh merges in background.

## Ambient background

**Widget:** `lib/presentation/widgets/ambient_glow_background.dart`

Used in `AppShell` as the bottom stack layer:

1. Solid midnight base (`#0A0F1C` dark / soft slate light)
2. Two **animated** radial orbs (purple-indigo, teal-blue) on Lissajous drift paths
3. `ClipRect` + `RepaintBoundary`; UI in sibling layer above

56s `AnimationController` loop; low alpha (≤20%) for subtle premium glow.

## Checklist

- [x] Upload returns `key`; attach uses `*_key` fields
- [x] Pattern B with separate HTTP client for R2 PUT
- [x] Image widgets load without Bearer on presigned URLs
- [x] Post composer sends `media_keys` only
- [x] Feed offline cache + merge refresh
- [x] Post preview cache for instant detail
- [x] Animated ambient shell background
