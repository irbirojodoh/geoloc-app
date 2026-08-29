/// Centralized API endpoints for the Geoloc backend
class ApiEndpoints {
  ApiEndpoints._();

  // Base paths
  static const String _authBase = '/auth';
  static const String _apiBase = '/api/v1';

  static const String _locationsBase = '$_apiBase/locations';
  static const String _notificationsBase = '$_apiBase/notifications';
  static const String _searchBase = '$_apiBase/search';

  static const String _devicesBase = '$_apiBase/devices';

  // ==================== Auth Endpoints (Public) ====================

  /// POST - Register new user
  static const String register = '$_authBase/register';

  /// POST - Login, receive JWT tokens
  static const String login = '$_authBase/login';

  /// POST - Refresh access token
  static const String refreshToken = '$_authBase/refresh';

  /// POST - Exchange Google ID token for JWT
  static const String googleToken = '$_authBase/google/token';

  /// POST - Exchange Apple ID token for JWT
  static const String appleToken = '$_authBase/apple/token';

  /// POST - Request password reset email (always 200 - no bearer)
  static const String forgotPassword = '$_authBase/forgot-password';

  /// POST - Complete reset with emailed token (no bearer)
  static const String resetPassword = '$_authBase/reset-password';

  // ==================== Feed Endpoints (Public) ====================

  /// GET - Get nearby posts
  /// Query params: latitude, longitude, radius_km, limit
  static const String feed = '$_apiBase/feed';

  // ==================== User Endpoints (Protected) ====================

  /// GET - Get current user profile
  static const String getCurrentUser = '$_apiBase/users/me';

  /// PUT - Update current user profile
  static const String updateProfile = '$_apiBase/users/me';

  /// GET - Live username availability (?username=)
  static const String usernameAvailable = '$_apiBase/users/username-available';

  /// PUT - Change current user's username (body: { username })
  static const String changeUsername = '$_apiBase/users/me/username';

  /// GET - Current username, cooldown, and rename history (?limit=)
  static const String usernameHistory = '$_apiBase/users/me/username-history';

  /// DELETE - Permanently delete current account (body: password)
  static const String deleteCurrentUser = '$_apiBase/users/me';

  /// GET - Users blocked by current user
  static const String getBlockedUsers = '$_apiBase/users/me/blocked';

  /// GET - Users muted by current user
  static const String getMutedUsers = '$_apiBase/users/me/muted';

  /// POST - Submit content report (body: target_type, target_id, reason, description?)
  static const String reports = '$_apiBase/reports';

  /// GET - Get user by ID
  static String getUser(String userId) => '$_apiBase/users/$userId';

  /// GET - Get user's posts
  static String getUserPosts(String userId) => '$_apiBase/users/$userId/posts';

  // ==================== Follow Endpoints (Protected) ====================

  /// POST - Follow user
  static String followUser(String userId) => '$_apiBase/users/$userId/follow';

  /// DELETE - Unfollow user
  static String unfollowUser(String userId) => '$_apiBase/users/$userId/follow';

  /// GET - Get user's followers
  static String getFollowers(String userId) =>
      '$_apiBase/users/$userId/followers';

  /// GET - Get user's following
  static String getFollowing(String userId) =>
      '$_apiBase/users/$userId/following';

  /// POST - Block another user (no body)
  static String blockUser(String userId) => '$_apiBase/users/$userId/block';

  /// DELETE - Unblock user
  static String unblockUser(String userId) => '$_apiBase/users/$userId/block';

  /// POST - Mute another user (no body)
  static String muteUser(String userId) => '$_apiBase/users/$userId/mute';

  /// DELETE - Unmute user
  static String unmuteUser(String userId) => '$_apiBase/users/$userId/mute';

  // ==================== Post Endpoints (Protected) ====================

  /// POST - Create post
  static const String posts = '$_apiBase/posts';
  static const String createPost = '$_apiBase/posts';

  /// GET - Get single post
  static String getPost(String postId) => '$_apiBase/posts/$postId';

  /// DELETE - Delete own post by id
  static String deletePost(String postId) => '$_apiBase/posts/$postId';

  /// POST - Toggle post like (idempotent)
  /// Request: { "like": true/false }
  /// Response: { "is_liked": bool, "like_count": int, "changed": bool }
  static String togglePostLike(String postId) =>
      '$_apiBase/posts/$postId/toggle-like';

  /// POST - Add comment to post
  static String addComment(String postId) => '$_apiBase/posts/$postId/comments';

  /// GET - Get post comments
  static String getComments(String postId) =>
      '$_apiBase/posts/$postId/comments';

  // ==================== Comment Endpoints (Protected) ====================

  /// POST - Reply to comment (max depth: 3)
  static String replyToComment(String commentId) =>
      '$_apiBase/comments/$commentId/reply';

  /// GET - Paginated replies for a comment thread
  /// Query: limit, cursor
  static String getCommentReplies(String commentId) =>
      '$_apiBase/comments/$commentId/replies';

  /// PUT - Edit own comment (body: content)
  static String updateComment(String commentId) =>
      '$_apiBase/comments/$commentId';

  /// POST - Toggle comment like (idempotent)
  /// Request: { "like": true/false }
  /// Response: { "is_liked": bool, "like_count": int, "changed": bool }
  static String toggleCommentLike(String commentId) =>
      '$_apiBase/comments/$commentId/toggle-like';

  /// DELETE - Delete own comment
  static String deleteComment(String commentId) =>
      '$_apiBase/comments/$commentId';

  // ==================== Location Endpoints (Protected) ====================

  /// POST - Follow a geographic area
  static const String followLocation = '$_locationsBase/follow';

  /// DELETE - Unfollow a geographic area
  static String unfollowLocation(String geohash) =>
      '$_locationsBase/$geohash/follow';

  /// GET - Get followed locations
  static const String getFollowedLocations = '$_locationsBase/following';

  // ==================== Geocode Endpoints (Protected) ====================

  /// GET - Get address from coordinates
  /// Query params: lat, lng
  static const String getAddress = '$_apiBase/geocode/address';

  // ==================== Notification Endpoints (Protected) ====================

  /// GET - Get all notifications
  static const String getNotifications = _notificationsBase;

  /// PUT - Mark notification as read
  static String markNotificationRead(String notificationId) =>
      '$_notificationsBase/$notificationId/read';

  /// PUT - Mark all notifications as read
  static const String markAllNotificationsRead = '$_notificationsBase/read-all';

  /// GET - SSE Notification Stream
  static const String getNotificationStream = '$_notificationsBase/stream';

  // ==================== Search Endpoints (Protected) ====================

  /// GET - Elasticsearch global search
  /// Query params: q, type(all|posts|users), page, limit
  static const String search = _searchBase;

  /// GET - Elasticsearch nearby search (geo-filtered posts)
  /// Query params: q, lat, lon, radius_km, type
  static const String searchNearby = '$_searchBase/nearby';

  /// GET - Autocomplete for usernames and hashtags
  /// Query params: q, type(all|users|hashtags)
  static const String autocomplete = '$_apiBase/autocomplete';

  // ==================== Upload Endpoints (Protected) ====================

  /// POST - Upload avatar (max 10MB, multipart/form-data)
  static const String uploadAvatar = '$_apiBase/upload/avatar';

  /// POST - Upload cover image (max 10MB, multipart/form-data)
  static const String uploadCover = '$_apiBase/upload/cover';

  /// POST - Upload post media image (max 10MB, multipart/form-data)
  static const String uploadPostMedia = '$_apiBase/upload/post';

  // ==================== Media Endpoints (Protected) ====================

  /// GET - Resolve an R2 object key to a presigned GET URL
  /// Query params: key
  static const String mediaSign = '$_apiBase/media/sign';

  /// POST - Request a presigned PUT URL for direct R2 upload (Pattern B)
  static const String mediaUploadUrl = '$_apiBase/media/upload-url';

  /// DELETE - Delete an owned R2 object
  /// Query params: key
  static const String mediaDeleteObject = '$_apiBase/media/object';

  // ==================== Device Endpoints (Protected) ====================

  /// POST - Register push token
  static const String registerDevice = _devicesBase;

  /// DELETE - Unregister push token
  static const String unregisterDevice = _devicesBase;

  // ==================== Direct Message Endpoints (Protected) ====================

  static const String _dmBase = '$_apiBase/dm';

  /// PUT - Upload or rotate caller's public key
  static const String uploadDmKey = '$_dmBase/keys';

  /// PUT / GET - Passphrase-wrapped identity backup (caller only)
  static const String dmKeyBackup = '$_dmBase/keys/backup';

  /// GET - Fetch another user's public key (?key_version=N optional)
  static String getDmKey(String userId) => '$_dmBase/keys/$userId';

  /// GET - List all public key versions for a user
  static String getDmKeyVersions(String userId) =>
      '$_dmBase/keys/$userId/versions';

  /// POST - Start or retrieve 1:1 conversation
  static const String createDmConversation = '$_dmBase/conversations';

  /// GET - Inbox list
  static const String getDmConversations = '$_dmBase/conversations';

  /// DELETE - Remove conversation from your inbox only
  static String deleteDmConversation(String conversationId) =>
      '$_dmBase/conversations/$conversationId';

  /// GET - Message history
  static String getDmMessages(String conversationId) =>
      '$_dmBase/conversations/$conversationId/messages';

  /// POST - Send encrypted message
  static String sendDmMessage(String conversationId) =>
      '$_dmBase/conversations/$conversationId/messages';

  /// DELETE - Soft-delete own message
  static String deleteDmMessage(String messageId) =>
      '$_dmBase/messages/$messageId';

  /// PUT - Update read receipt
  static String markDmConversationRead(String conversationId) =>
      '$_dmBase/conversations/$conversationId/read';
}
