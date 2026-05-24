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
import '../../widgets/top_bar_backdrop.dart';

/// Material 3 post detail screen.
class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  static const _composerEnterDelay = Duration(milliseconds: 340);
  static const _composerEnterDuration = Duration(milliseconds: 260);
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showCommentComposer = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybePaginateComments);
    Future<void>.delayed(_composerEnterDelay, () {
      if (!mounted) return;
      setState(() => _showCommentComposer = true);
    });
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
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: colorScheme.primary,
        backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.96),
        strokeWidth: 2.2,
        elevation: 1,
        edgeOffset: 86,
        displacement: 28,
        onRefresh: () async {
          await ref.read(postDetailProvider(widget.postId).notifier).loadPost();
          await ref
              .read(postDetailProvider(widget.postId).notifier)
              .loadComments();
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  pinned: true,
                  centerTitle: false,
                  titleSpacing: 16,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  flexibleSpace: TopBarBackdrop(
                    blurTintColor: colorScheme.surface,
                    blendColor: colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                  ),
                  leading: IconButton(
                    tooltip: 'Back',
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  title: Text(
                    'Post',
                    style: textTheme.headlineMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                if (postDetailState.post == null)
                  SliverFillRemaining(
                    hasScrollBody: false,
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
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
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
                      ]),
                    ),
                  ),
          ],
        ),
      ),
      bottomNavigationBar: AnimatedSwitcher(
        duration: _composerEnterDuration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final slide = Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
        child: _showCommentComposer
            ? DecoratedBox(
                key: const ValueKey('comment-composer-visible'),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.92),
                  border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    10,
                    12,
                    10 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Material(
                    elevation: 2,
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              minLines: 1,
                              maxLines: 4,
                              textInputAction: TextInputAction.newline,
                              decoration: InputDecoration(
                                hintText: 'Write a comment...',
                                hintStyle: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                isDense: true,
                                filled: true,
                                fillColor: colorScheme.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            tooltip: 'Send comment',
                            onPressed: postDetailState.isSubmittingComment
                                ? null
                                : _submitCommentInput,
                            style: IconButton.styleFrom(
                              minimumSize: const Size(42, 42),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: postDetailState.isSubmittingComment
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.send_rounded, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : const SizedBox(
                key: ValueKey('comment-composer-hidden'),
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
      padding: EdgeInsets.only(left: leftInset, top: 3, bottom: 3),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        leading: UserAvatar(
          imageUrl: c.effectiveProfilePictureUrl,
          name: c.effectiveUsername,
          size: 36,
        ),
        title: Text(c.effectiveUsername, style: textTheme.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              c.content,
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 2),
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
