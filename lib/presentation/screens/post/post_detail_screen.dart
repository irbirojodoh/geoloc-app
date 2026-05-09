import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../data/models/comment.dart';
import '../../providers/post_detail_provider.dart';
import '../../widgets/post_card.dart';
import '../../widgets/post_overflow_menu_button.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/states/error_state.dart';

/// Material 3 post detail screen.
class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybePaginateComments);
  }

  void _maybePaginateComments() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (!pos.hasViewportDimension) return;
    const threshold = 360.0;
    if (pos.pixels >= pos.maxScrollExtent - threshold) {
      ref.read(postDetailProvider(widget.postId).notifier).loadMoreComments();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_maybePaginateComments);
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submitCommentInput() async {
    final raw = _commentController.text.trim();
    if (raw.isEmpty) return;

    final notifier = ref.read(postDetailProvider(widget.postId).notifier);
    final ok = await notifier.submitComment(raw);
    if (ok && mounted) {
      _commentController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final postDetailState = ref.watch(postDetailProvider(widget.postId));
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final comments = _flattenComments(postDetailState.comments);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('Post'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(postDetailProvider(widget.postId).notifier).loadPost();
          await ref
              .read(postDetailProvider(widget.postId).notifier)
              .loadComments();
        },
        child: postDetailState.post == null
            ? ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.6,
                    child: Center(
                      child: postDetailState.error != null
                          ? ErrorState(
                              message: postDetailState.error!,
                              onRetry: () => ref
                                  .read(postDetailProvider(widget.postId).notifier)
                                  .loadPost(),
                            )
                          : const CircularProgressIndicator(),
                    ),
                  ),
                ],
              )
            : ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  PostCard(
                    post: postDetailState.post!,
                    headerTrailing: PostOverflowMenuButton(
                      post: postDetailState.post!,
                      viewingPostDetailId: widget.postId,
                    ),
                    onLike: () => ref
                        .read(postDetailProvider(widget.postId).notifier)
                        .togglePostLike(),
                    onUserTap: () =>
                        context.push('/profile/${postDetailState.post!.userId}'),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: colorScheme.outlineVariant),
                  const SizedBox(height: 8),
                  Text('Comments', style: textTheme.labelLarge),
                  const SizedBox(height: 8),
                  if (comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No comments yet',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ...comments.map(
                    (comment) => _CommentTile(
                      comment: comment,
                      postId: widget.postId,
                    ),
                  ),
                  if (postDetailState.isLoadingMoreComments)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Comment',
                    helperText: 'Be respectful',
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Send comment',
                onPressed:
                    postDetailState.isSubmittingComment ? null : _submitCommentInput,
                color: colorScheme.primary,
                icon: postDetailState.isSubmittingComment
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_CommentItem> _flattenComments(List<Comment> source, [int depth = 0]) {
    final out = <_CommentItem>[];
    for (final comment in source) {
      out.add(_CommentItem(comment: comment, depth: depth));
      if (comment.replies.isNotEmpty) {
        out.addAll(_flattenComments(comment.replies, depth + 1));
      }
    }
    return out;
  }
}

class _CommentItem {
  const _CommentItem({required this.comment, required this.depth});
  final Comment comment;
  final int depth;
}

class _CommentTile extends ConsumerWidget {
  const _CommentTile({required this.comment, required this.postId});

  final _CommentItem comment;
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = comment.comment;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final leftInset = 16.0 * comment.depth;

    return Padding(
      padding: EdgeInsets.only(left: leftInset, top: 8, bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        leading: UserAvatar(
          imageUrl: c.effectiveProfilePictureUrl,
          name: c.effectiveUsername,
          size: 36,
        ),
        title: Text(c.effectiveUsername, style: textTheme.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              c.content,
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              timeago.format(c.createdAt, locale: 'en_short'),
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          tooltip: 'Like comment',
          onPressed: () =>
              ref.read(postDetailProvider(postId).notifier).toggleCommentLike(c.id),
          icon: Icon(
            c.isLiked ? Icons.favorite : Icons.favorite_outline,
            color: c.isLiked ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
