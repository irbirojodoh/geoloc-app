import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_extensions.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme/app_colors.dart';
import '../../../data/models/comment.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_detail_provider.dart';
import '../../widgets/comment_overflow_menu_button.dart';
import '../../widgets/post_card.dart';
import '../../widgets/post_overflow_menu_button.dart';
import '../../widgets/user_avatar.dart';

/// Post detail screen — old-money luxury aesthetic
class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _commentFocus = FocusNode();

  String? _replyingToCommentId;
  String _replyingToLabel = '';
  Comment? _editingComment;

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
    _commentFocus.dispose();
    super.dispose();
  }

  void _cancelModes() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToLabel = '';
      _editingComment = null;
      _commentController.clear();
    });
  }

  void _beginReply(Comment c) {
    setState(() {
      _replyingToCommentId = c.id;
      _replyingToLabel = c.effectiveUsername;
      _editingComment = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _commentFocus.requestFocus();
    });
  }

  void _beginEdit(Comment c) {
    setState(() {
      _editingComment = c;
      _replyingToCommentId = null;
      _replyingToLabel = '';
      _commentController.text = c.content;
      _commentController.selection = TextSelection.fromPosition(
        TextPosition(offset: _commentController.text.length),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _commentFocus.requestFocus();
    });
  }

  Future<void> _submitCommentInput() async {
    final raw = _commentController.text.trim();
    if (raw.isEmpty) return;

    final notifier = ref.read(postDetailProvider(widget.postId).notifier);
    bool ok;

    final editing = _editingComment;
    if (editing != null) {
      ok = await notifier.editComment(editing.id, raw);
      if (ok && mounted) _cancelModes();
      return;
    }

    final rid = _replyingToCommentId;
    if (rid != null) {
      ok = await notifier.submitReply(rid, raw);
      if (ok && mounted) {
        _commentController.clear();
        setState(() {
          _replyingToCommentId = null;
          _replyingToLabel = '';
        });
        FocusScope.of(context).unfocus();
      }
      return;
    }

    ok = await notifier.submitComment(raw);
    if (ok && mounted) {
      _commentController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _showEditSheet(Comment c) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final gold = AppColors.gold(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Comment',
                  style: context.textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Icon(Icons.edit_outlined, color: gold, size: 22),
                  title: Text(
                    'Edit',
                    style: context.bodyMedium,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _beginEdit(c);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final postDetailState = ref.watch(postDetailProvider(widget.postId));
    final cs = Theme.of(context).colorScheme;
    final gold = AppColors.gold(context);
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: RefreshIndicator(
                color: gold,
                onRefresh: () async {
                  await ref
                      .read(postDetailProvider(widget.postId).notifier)
                      .loadPost();
                  await ref
                      .read(postDetailProvider(widget.postId).notifier)
                      .loadComments();
                },
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (postDetailState.isLoading &&
                        postDetailState.post == null)
                      SliverFillRemaining(
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: gold,
                          ),
                        ),
                      )
                    else if (postDetailState.error != null &&
                        postDetailState.post == null)
                      SliverFillRemaining(
                        child: Center(
                          child: Text(
                            postDetailState.error!,
                            style: context.bodyMedium,
                          ),
                        ),
                      )
                    else if (postDetailState.post != null) ...[
                      SliverToBoxAdapter(
                        child: PostCard(
                          post: postDetailState.post!,
                          headerTrailing: PostOverflowMenuButton(
                            post: postDetailState.post!,
                            viewingPostDetailId: widget.postId,
                          ),
                          onTap: null,
                          onLike: () => ref
                              .read(postDetailProvider(widget.postId).notifier)
                              .togglePostLike(),
                          onUserTap: () => context.push(
                            '/profile/${postDetailState.post!.userId}',
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.favorite,
                                size: 14,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${postDetailState.post!.likeCount}',
                                style: context.monoData,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'likes',
                                style: context.bodySmallLight,
                              ),
                              const SizedBox(width: 16),
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 14,
                                color: AppColors.textMuted(context),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${postDetailState.post!.commentCount}',
                                style: context.monoData,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'comments',
                                style: context.bodySmallLight,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                          child: Text(
                            'COMMENTS',
                            style: context.sectionLabel,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            height: 0.5,
                            color: cs.outline,
                          ),
                        ),
                      ),
                      if (postDetailState.comments.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Center(
                              child: Text(
                                'No comments yet',
                                style: context.bodyMedium?.copyWith(color: AppColors.textMuted(context)),
                              ),
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final comment = postDetailState.comments[index];
                              return _CommentThread(
                                comment: comment,
                                postId: widget.postId,
                                depth: 0,
                                onReplyTap: _beginReply,
                                onOwnLongPress:
                                    me != null &&
                                            comment.userId == me.id &&
                                            !comment.isSoftDeleted
                                        ? _showEditSheet
                                        : null,
                              );
                            },
                            childCount: postDetailState.comments.length,
                          ),
                        ),
                      if (postDetailState.comments.isNotEmpty &&
                          postDetailState.isLoadingMoreComments)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 16,
                            ),
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: gold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ],
                ),
              ),
            ),
            if (postDetailState.post != null)
              _buildCommentInput(context, postDetailState),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      color: cs.surface,
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: cs.outline, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: cs.outline, width: 1),
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      size: 18,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Post',
                  style: context.appBarTitle,
                ),
                const Spacer(),
                const SizedBox(width: 34),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput(BuildContext context, PostDetailState state) {
    final cs = Theme.of(context).colorScheme;
    final gold = AppColors.gold(context);

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safePadding = MediaQuery.of(context).padding.bottom;
    final bottomPadding = bottomInset > 0 ? bottomInset : safePadding;

    final modeBanner = () {
      if (_editingComment != null) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Editing comment',
                  style: context.sheetItem?.copyWith(color: AppColors.gold(context)),
                ),
              ),
              TextButton(
                onPressed: _cancelModes,
                child: Text(
                  'Cancel',
                  style: context.caption,
                ),
              ),
            ],
          ),
        );
      }
      if (_replyingToCommentId != null) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Reply to @$_replyingToLabel',
                  style: context.sheetItem?.copyWith(color: AppColors.gold(context)),
                ),
              ),
              TextButton(
                onPressed: _cancelModes,
                child: Text(
                  'Cancel',
                  style: context.caption,
                ),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }();

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline, width: 0.5)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: 8 + bottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          modeBanner,
          Row(
            children: [
              Expanded(
                child: TextField(
                  focusNode: _commentFocus,
                  controller: _commentController,
                  style: context.bodyMedium,
                  cursorColor: gold,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText:
                        _editingComment != null
                        ? 'Update your comment…'
                        : 'Add a comment…',
                    hintStyle: context.bodyMedium?.copyWith(color: AppColors.textMuted(context)),
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 4,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (state.isSubmittingComment)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: gold,
                  ),
                )
              else
                TextButton(
                  onPressed: _submitCommentInput,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _editingComment != null ? 'Save' : 'Post',
                    style: context.link,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentThread extends ConsumerWidget {
  final Comment comment;
  final String postId;
  final int depth;
  final ValueChanged<Comment> onReplyTap;
  /// Long-press on own rows — opens edit sheet flow.
  final void Function(Comment)? onOwnLongPress;

  const _CommentThread({
    required this.comment,
    required this.postId,
    required this.depth,
    required this.onReplyTap,
    this.onOwnLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadingReplies =
        ref
            .watch(postDetailProvider(postId))
            .loadingMoreRepliesIds
            .contains(comment.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CommentRow(
          comment: comment,
          postId: postId,
          depth: depth,
          onReplyTap: onReplyTap,
          onOwnLongPress: onOwnLongPress,
        ),
        ...comment.replies.map(
          (r) => _CommentThread(
            comment: r,
            postId: postId,
            depth: depth + 1,
            onReplyTap: onReplyTap,
            onOwnLongPress: onOwnLongPress,
          ),
        ),
        if (comment.hasMoreReplies)
          Padding(
            padding: EdgeInsets.only(left: 16 + (depth + 1) * 14, bottom: 4),
            child: TextButton(
              onPressed:
                  loadingReplies
                      ? null
                      : () => ref
                          .read(postDetailProvider(postId).notifier)
                          .loadMoreReplies(comment.id),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: loadingReplies
                  ? SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1,
                        color: AppColors.gold(context),
                      ),
                    )
                  : Text(
                      'View more replies…',
                      style: context.link,
                    ),
            ),
          ),
      ],
    );
  }
}

class _CommentRow extends ConsumerWidget {
  final Comment comment;
  final String postId;
  final int depth;
  final ValueChanged<Comment> onReplyTap;
  final void Function(Comment)? onOwnLongPress;

  const _CommentRow({
    required this.comment,
    required this.postId,
    required this.depth,
    required this.onReplyTap,
    this.onOwnLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    Widget body = GestureDetector(
      onLongPress:
          onOwnLongPress == null || comment.isSoftDeleted
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  onOwnLongPress!(comment);
                },
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            imageUrl: comment.effectiveProfilePictureUrl,
            name: comment.effectiveUsername,
            size: 32,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment.effectiveUsername,
                        style: context.bodySmallLight,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeago.format(comment.createdAt, locale: 'en_short'),
                      style: context.monoCaption,
                    ),
                    if (comment.updatedAt != null) ...[
                      Text(
                        ' · ',
                        style: context.monoCaption,
                      ),
                      Text(
                        '(edited)',
                        style: context.monoCaption,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.isSoftDeleted
                      ? 'This comment was deleted'
                      : comment.content,
                  style: context.postContent,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed:
                          comment.canReply
                              ? () => onReplyTap(comment)
                              : null,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Reply',
                        style: context.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 14),
                    InkWell(
                      onTap:
                          comment.isSoftDeleted
                              ? null
                              : () => ref
                                  .read(postDetailProvider(postId).notifier)
                                  .toggleCommentLike(comment.id),
                      borderRadius: BorderRadius.circular(2),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              comment.isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 14,
                              color: comment.isLiked
                                  ? AppColors.error
                                  : AppColors.textMuted(context),
                            ),
                            if (comment.likeCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '${comment.likeCount}',
                                style: context.monoCaption,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          CommentOverflowMenuButton(
            comment: comment,
            postId: postId,
          ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(12 + depth * 14.0, 8, 8, 2),
      child: body,
    );
  }
}
