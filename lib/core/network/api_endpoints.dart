/// Centralized API endpoints for the Geoloc backend
class ApiEndpoints {
  ApiEndpoints._();

  // Base paths
  static const String _authBase = '/auth';
  static const String _apiBase = '/api/v1';
  static const String _usersBase = '/users';
  static const String _postsBase = '/posts';
  static const String _commentsBase = '/comments';
  static const String _locationsBase = '/locations';
  static const String _notificationsBase = '/notifications';
  static const String _searchBase = '/search';
  static const String _uploadBase = '/upload';
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

  /// PUT - Update current user profile
  static const String updateProfile = '$_usersBase/me';

  /// GET - Get user by ID
  static String getUser(String userId) => '$_usersBase/$userId';

  /// GET - Get user's posts
  static String getUserPosts(String userId) => '$_usersBase/$userId/posts';

  // ==================== Follow Endpoints (Protected) ====================

  /// POST - Follow user
  static String followUser(String userId) => '$_usersBase/$userId/follow';

  /// DELETE - Unfollow user
  static String unfollowUser(String userId) => '$_usersBase/$userId/follow';

  /// GET - Get user's followers
  static String getFollowers(String userId) => '$_usersBase/$userId/followers';

  /// GET - Get user's following
  static String getFollowing(String userId) => '$_usersBase/$userId/following';

  // ==================== Post Endpoints (Protected) ====================

  /// POST - Create post
  static const String createPost = _postsBase;

  /// GET - Get single post
  static String getPost(String postId) => '$_postsBase/$postId';

  /// POST - Like post
  static String likePost(String postId) => '$_postsBase/$postId/like';

  /// DELETE - Unlike post
  static String unlikePost(String postId) => '$_postsBase/$postId/like';

  /// POST - Add comment to post
  static String addComment(String postId) => '$_postsBase/$postId/comments';

  /// GET - Get post comments
  static String getComments(String postId) => '$_postsBase/$postId/comments';

  // ==================== Comment Endpoints (Protected) ====================

  /// POST - Reply to comment (max depth: 3)
  static String replyToComment(String commentId) =>
      '$_commentsBase/$commentId/reply';

  /// POST - Like comment
  static String likeComment(String commentId) =>
      '$_commentsBase/$commentId/like';

  /// DELETE - Unlike comment
  static String unlikeComment(String commentId) =>
      '$_commentsBase/$commentId/like';

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
  static const String uploadAvatar = '$_uploadBase/avatar';

  /// POST - Upload post media (max 50MB, multipart/form-data)
  static const String uploadPostMedia = '$_uploadBase/post';

  // ==================== Device Endpoints (Protected) ====================

  /// POST - Register push token
  static const String registerDevice = _devicesBase;

  /// DELETE - Unregister push token
  static const String unregisterDevice = _devicesBase;
}
