/// Centralized API endpoints for the Geoloc backend
class ApiEndpoints {
  ApiEndpoints._();

  // Base paths
  static const String _authBase = '/auth';
  static const String _apiBase = '/api/v1';

  static const String _commentsBase = '/comments';
  static const String _locationsBase = '/locations';
  static const String _notificationsBase = '/notifications';
  static const String _searchBase = '/search';

  static const String _devicesBase = '/devices';

  // ==================== Auth Endpoints (Public) ====================

  /// POST - Register new user
  static const String register = '$_authBase/register';

  /// POST - Login, receive JWT tokens
  static const String login = '$_authBase/login';

  /// POST - Refresh access token
  static const String refreshToken = '$_authBase/refresh';

  // ==================== Feed Endpoints (Public) ====================

  /// GET - Get nearby posts
  /// Query params: latitude, longitude, radius_km, limit
  static const String feed = '$_apiBase/feed';

  // ==================== User Endpoints (Protected) ====================

  /// GET - Get current user profile
  static const String getCurrentUser = '$_apiBase/users/me';

  /// PUT - Update current user profile
  static const String updateProfile = '$_apiBase/users/me';

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

  // ==================== Post Endpoints (Protected) ====================

  /// POST - Create post
  static const String posts = '$_apiBase/posts';
  static const String createPost = '$_apiBase/posts';

  /// GET - Get single post
  static String getPost(String postId) => '$_apiBase/posts/$postId';

  /// POST - Like post (legacy)
  static String likePost(String postId) => '$_apiBase/posts/$postId/like';

  /// DELETE - Unlike post (legacy)
  static String unlikePost(String postId) => '$_apiBase/posts/$postId/like';

  /// POST - Toggle post like (idempotent, recommended)
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
      '$_commentsBase/$commentId/reply';

  /// POST - Like comment (legacy)
  static String likeComment(String commentId) =>
      '$_commentsBase/$commentId/like';

  /// DELETE - Unlike comment (legacy)
  static String unlikeComment(String commentId) =>
      '$_commentsBase/$commentId/like';

  /// POST - Toggle comment like (idempotent, recommended)
  /// Request: { "like": true/false }
  /// Response: { "is_liked": bool, "like_count": int, "changed": bool }
  static String toggleCommentLike(String commentId) =>
      '$_apiBase/comments/$commentId/toggle-like';

  /// DELETE - Delete own comment
  static String deleteComment(String commentId) => '$_commentsBase/$commentId';

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

  // ==================== Search Endpoints (Protected) ====================

  /// GET - Search users
  /// Query param: q
  static const String searchUsers = '$_searchBase/users';

  /// GET - Search posts
  /// Query param: q
  static const String searchPosts = '$_searchBase/posts';

  // ==================== Upload Endpoints (Protected) ====================

  /// POST - Upload avatar (max 5MB, multipart/form-data)
  static const String uploadAvatar = '$_apiBase/upload/avatar';

  /// POST - Upload post media (max 50MB, multipart/form-data)
  static const String uploadPostMedia = '$_apiBase/upload/post';

  // ==================== Device Endpoints (Protected) ====================

  /// POST - Register push token
  static const String registerDevice = _devicesBase;

  /// DELETE - Unregister push token
  static const String unregisterDevice = _devicesBase;
}
