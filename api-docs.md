# Geoloc API Documentation

**Base URL:** `http://localhost:8080`

## Table of Contents

- [Overview](#overview)
- [Authentication](#authentication)
- [Public Endpoints](#public-endpoints)
- [Protected Endpoints](#protected-endpoints)
  - [Profile](#profile)
  - [Users](#users)
  - [Follows](#follows)
  - [Posts](#posts)
  - [Likes](#likes)
  - [Comments](#comments)
  - [Locations](#locations)
  - [Notifications](#notifications)
  - [Search](#search)
  - [Upload](#upload)
  - [Devices](#devices)
- [Error Responses](#error-responses)
- [Rate Limits](#rate-limits)

---

## Overview

Geoloc is a hyper-local social media API built with Go and Cassandra. It features:
- JWT-based authentication (15-min access token, 7-day refresh token)
- Geospatial posts using geohashing (~5km precision)
- Nested comments (up to 3 levels)
- User and location following
- Push notification support
- Rate limiting (100 req/min per IP)

---

## Authentication

All protected endpoints require a Bearer token in the Authorization header:

```
Authorization: Bearer <access_token>
```

### Token Lifecycle
| Token | Expiry |
|-------|--------|
| Access Token | 15 minutes |
| Refresh Token | 7 days |

---

## Public Endpoints

### Health Check

**Endpoint:** `GET /health`

**Response:** `200 OK`
```json
{
  "status": "ok",
  "database": "cassandra"
}
```

---

### Register

**Endpoint:** `POST /auth/register`

**Request Body:**
| Field | Type | Required | Constraints |
|-------|------|----------|-------------|
| username | string | Yes | 3-50 characters, unique |
| email | string | Yes | Valid email, unique |
| password | string | Yes | Min 6 characters |
| full_name | string | Yes | - |
| phone_number | string | No | - |

**Request Example:**
```json
{
  "username": "johndoe",
  "email": "john@example.com",
  "password": "securepassword123",
  "full_name": "John Doe",
  "phone_number": "+1234567890"
}
```

**Success Response:** `201 Created`
```json
{
  "message": "User registered successfully",
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "username": "johndoe",
    "email": "john@example.com",
    "full_name": "John Doe"
  },
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "expires_in": 900
}
```

---

### Login

**Endpoint:** `POST /auth/login`

**Request Body:**
| Field | Type | Description |
|-------|------|-------------|
| identifier | string | Email or username |
| password | string | User password |

**Request Example:**
```json
{
  "identifier": "johndoe",
  "password": "securepassword123"
}
```

**Success Response:** `200 OK`
```json
{
  "message": "Login successful",
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "expires_in": 900,
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "username": "johndoe",
    "email": "john@example.com"
  }
}
```

---

### Refresh Token

**Endpoint:** `POST /auth/refresh`

**Request Body:**
```json
{
  "refresh_token": "eyJ..."
}
```

**Success Response:** `200 OK`
```json
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "expires_in": 900
}
```

---

### Get Feed (Public)

**Endpoint:** `GET /api/v1/feed`

**Query Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| latitude | float | Yes | - | -90 to 90 |
| longitude | float | Yes | - | -180 to 180 |
| radius_km | float | No | 10 | Search radius in km |
| limit | int | No | 50 | Max posts (max 100) |

**Example:** `GET /api/v1/feed?latitude=40.785091&longitude=-73.968285&radius_km=5&limit=20`

**Success Response:** `200 OK`
```json
{
  "message": "Feed fetched successfully",
  "count": 2,
  "posts": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440001",
      "user_id": "550e8400-e29b-41d4-a716-446655440000",
      "content": "Beautiful day in Central Park!",
      "media_urls": ["http://localhost:8080/uploads/posts/abc.jpg"],
      "latitude": 40.785091,
      "longitude": -73.968285,
      "geohash": "dr5ru",
      "created_at": "2025-12-13T19:30:00Z"
    }
  ]
}
```

---

## Protected Endpoints

> All endpoints below require `Authorization: Bearer <token>` header.

---

### Profile

#### Get Current User Profile

**Endpoint:** `GET /api/v1/users/me`

**Success Response:** `200 OK`
```json
{
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "username": "johndoe",
    "email": "john@example.com",
    "full_name": "John Doe",
    "profile_picture_url": "http://localhost:8080/uploads/avatars/abc.jpg"
  }
}
```

#### Update Current User Profile

**Endpoint:** `PUT /api/v1/users/me`

**Request Body:**
| Field | Type | Description |
|-------|------|-------------|
| full_name | string | Display name |
| bio | string | User bio |
| phone_number | string | Phone number |
| profile_picture_url | string | Avatar URL |

**Success Response:** `200 OK`
```json
{
  "message": "Profile updated",
  "user": { ... }
}
```

---

### Geocode

#### Get Address from Coordinates

**Endpoint:** `GET /api/v1/geocode/address`

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| lat | float | Yes | Latitude |
| lng | float | Yes | Longitude |

**Success Response:** `200 OK`
```json
{
  "geohash": "qqggy",
  "location_name": "Kukusan",
  "address": {
    "village": "Kukusan",
    "city_district": "Beji",
    "city": "Depok",
    "state": "West Java",
    "postcode": "16425",
    "country": "Indonesia",
    "country_code": "id"
  }
}
```

---

### Users

#### Get User by ID

**Endpoint:** `GET /api/v1/users/:id`

**Success Response:** `200 OK`
```json
{
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "username": "johndoe",
    "full_name": "John Doe",
    "bio": "Tech enthusiast",
    "profile_picture_url": "http://...",
    "created_at": "2025-12-13T19:30:00Z"
  }
}
```

#### Get User by Username

**Endpoint:** `GET /api/v1/users/username/:username`

#### Get User's Posts

**Endpoint:** `GET /api/v1/users/:id/posts`

**Success Response:** `200 OK`
```json
{
  "count": 10,
  "posts": [ ... ]
}
```

---

### Follows

#### Follow User

**Endpoint:** `POST /api/v1/users/:id/follow`

**Success Response:** `200 OK`
```json
{
  "message": "User followed"
}
```

#### Unfollow User

**Endpoint:** `DELETE /api/v1/users/:id/follow`

**Success Response:** `200 OK`
```json
{
  "message": "User unfollowed"
}
```

#### Get Followers

**Endpoint:** `GET /api/v1/users/:id/followers`

**Query Parameters:**
| Parameter | Type | Default |
|-----------|------|---------|
| limit | int | 50 |

**Success Response:** `200 OK`
```json
{
  "user_id": "...",
  "count": 42,
  "followers": [ ... ]
}
```

#### Get Following

**Endpoint:** `GET /api/v1/users/:id/following`

**Query Parameters:**
| Parameter | Type | Default |
|-----------|------|---------|
| limit | int | 50 |

**Success Response:** `200 OK`
```json
{
  "user_id": "...",
  "count": 15,
  "following": [ ... ]
}
```

---

### Posts

#### Create Post

**Endpoint:** `POST /api/v1/posts`

**Request Body:**
| Field | Type | Required | Constraints |
|-------|------|----------|-------------|
| user_id | UUID | Yes | Must exist |
| content | string | Yes | - |
| latitude | float | Yes | -90 to 90 |
| longitude | float | Yes | -180 to 180 |
| media_urls | array | No | Max 4 URLs |

**Request Example:**
```json
{
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "content": "Hello from Central Park!",
  "latitude": 40.785091,
  "longitude": -73.968285,
  "media_urls": ["http://localhost:8080/uploads/posts/photo.jpg"]
}
```

**Success Response:** `201 Created`
```json
{
  "message": "Post created successfully",
  "post": { ... }
}
```

#### Get Post by ID

**Endpoint:** `GET /api/v1/posts/:id`

**Success Response:** `200 OK`
```json
{
  "post": { ... }
}
```

---

### Likes

#### Like Post

**Endpoint:** `POST /api/v1/posts/:id/like`

**Success Response:** `200 OK`
```json
{
  "message": "Post liked"
}
```

#### Unlike Post

**Endpoint:** `DELETE /api/v1/posts/:id/like`

**Success Response:** `200 OK`
```json
{
  "message": "Post unliked"
}
```

#### Like Comment

**Endpoint:** `POST /api/v1/comments/:id/like`

#### Unlike Comment

**Endpoint:** `DELETE /api/v1/comments/:id/like`

---

### Comments

#### Create Comment

**Endpoint:** `POST /api/v1/posts/:id/comments`

**Request Body:**
| Field | Type | Required |
|-------|------|----------|
| content | string | Yes |

**Success Response:** `201 Created`
```json
{
  "message": "Comment created",
  "comment": {
    "id": "...",
    "post_id": "...",
    "user_id": "...",
    "content": "Great post!",
    "depth": 1,
    "created_at": "..."
  }
}
```

#### Get Comments for Post

**Endpoint:** `GET /api/v1/posts/:id/comments`

**Query Parameters:**
| Parameter | Type | Default |
|-----------|------|---------|
| limit | int | 50 |

**Success Response:** `200 OK`
```json
{
  "post_id": "...",
  "total_count": 15,
  "comments": [ ... ]
}
```

#### Reply to Comment

**Endpoint:** `POST /api/v1/comments/:id/reply`

> Maximum nesting depth is 3 levels.

**Request Body:**
```json
{
  "content": "Thanks!"
}
```

**Success Response:** `201 Created`
```json
{
  "message": "Reply created",
  "comment": { ... }
}
```

#### Delete Comment

**Endpoint:** `DELETE /api/v1/comments/:id`

> Users can only delete their own comments.

**Success Response:** `200 OK`
```json
{
  "message": "Comment deleted"
}
```

---

### Locations

#### Follow Location

**Endpoint:** `POST /api/v1/locations/follow`

**Request Body:**
| Field | Type | Required |
|-------|------|----------|
| latitude | float | Yes |
| longitude | float | Yes |
| name | string | No |

**Request Example:**
```json
{
  "latitude": 40.785091,
  "longitude": -73.968285,
  "name": "Central Park"
}
```

**Success Response:** `201 Created`
```json
{
  "message": "Location followed",
  "location": {
    "geohash_prefix": "dr5ru",
    "name": "Central Park",
    "latitude": 40.785091,
    "longitude": -73.968285
  }
}
```

#### Unfollow Location

**Endpoint:** `DELETE /api/v1/locations/:geohash/follow`

**Success Response:** `200 OK`
```json
{
  "message": "Location unfollowed"
}
```

#### Get Followed Locations

**Endpoint:** `GET /api/v1/locations/following`

**Success Response:** `200 OK`
```json
{
  "locations": [ ... ],
  "count": 3
}
```

---

### Notifications

#### Get Notifications

**Endpoint:** `GET /api/v1/notifications`

**Query Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| limit | int | 50 | Max results |
| unread | bool | false | Filter unread only |

**Success Response:** `200 OK`
```json
{
  "notifications": [
    {
      "id": "...",
      "type": "follow",
      "actor_id": "...",
      "message": "started following you",
      "is_read": false,
      "created_at": "..."
    }
  ],
  "unread_count": 5,
  "total": 20
}
```

#### Mark Notification as Read

**Endpoint:** `PUT /api/v1/notifications/:id/read`

**Success Response:** `200 OK`
```json
{
  "message": "Notification marked as read"
}
```

#### Mark All Notifications as Read

**Endpoint:** `PUT /api/v1/notifications/read-all`

**Success Response:** `200 OK`
```json
{
  "message": "All notifications marked as read"
}
```

---

### Search

#### Search Users

**Endpoint:** `GET /api/v1/search/users`

**Query Parameters:**
| Parameter | Type | Required | Constraints |
|-----------|------|----------|-------------|
| q | string | Yes | Min 2 characters |
| limit | int | No | Default: 20 |

**Success Response:** `200 OK`
```json
{
  "query": "john",
  "results": [ ... ],
  "count": 5
}
```

#### Search Posts

**Endpoint:** `GET /api/v1/search/posts`

**Query Parameters:**
| Parameter | Type | Required | Constraints |
|-----------|------|----------|-------------|
| q | string | Yes | Min 2 characters |
| limit | int | No | Default: 20 |

**Success Response:** `200 OK`
```json
{
  "query": "central park",
  "results": [ ... ],
  "count": 10
}
```

---

### Upload

#### Upload Avatar

**Endpoint:** `POST /api/v1/upload/avatar`

**Content-Type:** `multipart/form-data`

| Field | Type | Constraints |
|-------|------|-------------|
| file | file | Max 5MB, JPEG/PNG/GIF/WebP |

**Success Response:** `200 OK`
```json
{
  "message": "Avatar uploaded",
  "filename": "avatars/abc123.jpg",
  "url": "http://localhost:8080/uploads/avatars/abc123.jpg"
}
```

#### Upload Post Media

**Endpoint:** `POST /api/v1/upload/post`

**Content-Type:** `multipart/form-data`

| Field | Type | Constraints |
|-------|------|-------------|
| file | file | Max 50MB, JPEG/PNG/GIF/WebP/MP4/MOV |

**Success Response:** `200 OK`
```json
{
  "message": "Media uploaded",
  "filename": "posts/xyz789.mp4",
  "url": "http://localhost:8080/uploads/posts/xyz789.mp4",
  "media_type": "video",
  "extension": ".mp4"
}
```

---

### Devices

#### Register Device (Push Notifications)

**Endpoint:** `POST /api/v1/devices`

**Request Body:**
```json
{
  "token": "fcm_device_token_here",
  "platform": "ios"
}
```

**Success Response:** `200 OK`
```json
{
  "message": "Device registered"
}
```

#### Unregister Device

**Endpoint:** `DELETE /api/v1/devices`

**Success Response:** `200 OK`
```json
{
  "message": "Device unregistered"
}
```

---

## Error Responses

All errors follow this format:

```json
{
  "error": "Error message",
  "details": "Optional detailed information"
}
```

### Common HTTP Status Codes

| Code | Description |
|------|-------------|
| 200 | Success |
| 201 | Created |
| 400 | Bad Request (validation failed) |
| 401 | Unauthorized (invalid/missing token) |
| 403 | Forbidden (not allowed) |
| 404 | Not Found |
| 409 | Conflict (duplicate resource) |
| 429 | Too Many Requests (rate limited) |
| 500 | Internal Server Error |

---

## Rate Limits

| Limit | Value |
|-------|-------|
| Requests per IP | 100/minute |

When rate limited, you'll receive:

```json
{
  "error": "Rate limit exceeded. Please try again later."
}
```

---

## CORS Configuration

| Setting | Value |
|---------|-------|
| Allow Origins | `*` |
| Allow Methods | GET, POST, PUT, DELETE |
| Allow Headers | Origin, Content-Type, Authorization |

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CASSANDRA_HOST` | `localhost` | Cassandra host |
| `CASSANDRA_KEYSPACE` | `geoloc` | Keyspace name |
| `JWT_SECRET` | (default) | JWT signing secret |
| `PORT` | `8080` | Server port |
| `UPLOAD_PATH` | `./uploads` | Upload directory |
| `BASE_URL` | `http://localhost:8080` | Base URL for uploads |
