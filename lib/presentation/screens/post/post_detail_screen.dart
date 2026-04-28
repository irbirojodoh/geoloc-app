import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme/app_colors.dart';
import '../../../data/models/comment.dart';
import '../../providers/post_detail_provider.dart';
import '../../widgets/post_card.dart';
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

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _submitComment() async {
    final success = await ref
        .read(postDetailProvider(widget.postId).notifier)
        .submitComment(_commentController.text);

    if (success) {
      _commentController.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final postDetailState = ref.watch(postDetailProvider(widget.postId));
    final cs = Theme.of(context).colorScheme;
    final gold = AppColors.gold(context);

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
                            style: GoogleFonts.plusJakartaSans(
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      )
                    else if (postDetailState.post != null) ...[
                      SliverToBoxAdapter(
                        child: PostCard(
                          post: postDetailState.post!,
                          onTap: null,
                          onLike: () => ref
                              .read(postDetailProvider(widget.postId).notifier)
                              .togglePostLike(),
                          onUserTap: () => context.push(
                            '/profile/${postDetailState.post!.userId}',
                          ),
                        ),
                      ),

                      // Stats row
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
                                style: GoogleFonts.firaCode(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'likes',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: AppColors.textMuted(context),
                                ),
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
                                style: GoogleFonts.firaCode(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'comments',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: AppColors.textMuted(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Comments header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                          child: Text(
                            'COMMENTS',
                            style: GoogleFonts.ptSerif(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.8,
                              color: gold,
                            ),
                          ),
                        ),
                      ),

                      // Divider
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            height: 0.5,
                            color: cs.outline,
                          ),
                        ),
                      ),

                      // Comments list
                      if (postDetailState.comments.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Center(
                              child: Text(
                                'No comments yet',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.textMuted(context),
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final comment =
                                  postDetailState.comments[index];
                              return _CommentItem(
                                comment: comment,
                                postId: widget.postId,
                              );
                            },
                            childCount: postDetailState.comments.length,
                          ),
                        ),

                      const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    ],
                  ],
                ),
              ),
            ),

            // Comment input
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
                  style: GoogleFonts.ptSerif(
                    fontSize: 17,
                    fontStyle: FontStyle.italic,
                    color: cs.onSurface,
                  ),
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
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: cs.onSurface,
              ),
              cursorColor: gold,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textMuted(context),
                ),
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
              onPressed: _submitComment,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Post',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: gold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CommentItem extends ConsumerWidget {
  final Comment comment;
  final String postId;

  const _CommentItem({required this.comment, required this.postId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            imageUrl: comment.author?.profilePictureUrl,
            name: comment.author?.username ?? 'U',
            size: 34,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.author?.username ?? 'User',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeago.format(comment.createdAt, locale: 'en_short'),
                      style: GoogleFonts.firaCode(
                        color: AppColors.textMuted(context),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  comment.content,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    height: 1.4,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => ref
                      .read(postDetailProvider(postId).notifier)
                      .toggleCommentLike(comment.id),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        comment.isLiked
                            ? Icons.favorite
                            : Icons.favorite_outline,
                        size: 14,
                        color: comment.isLiked
                            ? AppColors.error
                            : AppColors.textMuted(context),
                      ),
                      if (comment.likeCount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '${comment.likeCount}',
                          style: GoogleFonts.firaCode(
                            fontSize: 11,
                            color: AppColors.textMuted(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
