import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/core/utils/username_rewrite.dart';
import 'package:geoloc_app/data/models/comment.dart';
import 'package:geoloc_app/data/models/post.dart';
import 'package:geoloc_app/data/models/user.dart';

User _user(String id, String username) => User(
      id: id,
      username: username,
      email: '',
    );

void main() {
  group('rewritePostAuthorUsername', () {
    test('updates author when the post belongs to the user', () {
      final post = Post(
        id: 'p1',
        userId: 'u1',
        content: 'hi',
        createdAt: DateTime.utc(2026, 1, 1),
        author: _user('u1', 'old'),
      );
      final updated = rewritePostAuthorUsername(post, 'u1', 'new');
      expect(updated.author?.username, 'new');
    });

    test('leaves other authors unchanged', () {
      final post = Post(
        id: 'p1',
        userId: 'u2',
        content: 'hi',
        createdAt: DateTime.utc(2026, 1, 1),
        author: _user('u2', 'other'),
      );
      expect(rewritePostAuthorUsername(post, 'u1', 'new'), post);
    });
  });

  group('rewriteCommentAuthorUsername', () {
    test('updates nested replies for the same author', () {
      final tree = Comment(
        id: 'c1',
        postId: 'p1',
        userId: 'u2',
        content: 'root',
        createdAt: DateTime.utc(2026, 1, 1),
        username: 'other',
        author: _user('u2', 'other'),
        replies: [
          Comment(
            id: 'c2',
            postId: 'p1',
            userId: 'u1',
            content: 'reply',
            createdAt: DateTime.utc(2026, 1, 1),
            username: 'old',
            author: _user('u1', 'old'),
          ),
        ],
      );

      final updated = rewriteCommentAuthorUsername(tree, 'u1', 'new');
      expect(updated.username, 'other');
      expect(updated.replies.single.username, 'new');
      expect(updated.replies.single.author?.username, 'new');
    });
  });
}
