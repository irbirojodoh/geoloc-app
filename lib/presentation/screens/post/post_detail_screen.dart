import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../data/models/comment.dart';
import '../../providers/post_detail_provider.dart';
import '../../widgets/post_card.dart';
import '../../widgets/user_avatar.dart';

// ============================================================================
// Dynamic Colors for Light/Dark Mode Adaptation (matching CreatePostScreen)
// ============================================================================

const _cardBackgroundStart = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFF0F4F8),
  darkColor: Color(0xFF2C2C2E),
);

const _cardBackgroundEnd = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFFFFFFF),
  darkColor: Color(0xFF1C1C1E),
);

/// Post detail screen with comments
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

  Color _resolveColor(
    BuildContext context,
    CupertinoDynamicColor dynamicColor,
  ) {
    return CupertinoDynamicColor.resolve(dynamicColor, context);
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

    final backgroundColor = CupertinoDynamicColor.resolve(
      const CupertinoDynamicColor.withBrightness(
        color: CupertinoColors.systemGrey6,
        darkColor: CupertinoColors.darkBackgroundGray,
      ),
      context,
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            // Custom header matching CreatePostScreen
            _buildHeader(context),
            // Main content
            Expanded(
              child: RefreshIndicator(
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
                      const SliverFillRemaining(
                        child: Center(child: CupertinoActivityIndicator()),
                      )
                    else if (postDetailState.error != null &&
                        postDetailState.post == null)
                      SliverFillRemaining(
                        child: Center(child: Text(postDetailState.error!)),
                      )
                    else if (postDetailState.post != null) ...[
                      // Post content using PostCard
                      SliverToBoxAdapter(
                        child: PostCard(
                          post: postDetailState.post!,
                          // Disable onTap to avoid recursion
                          onTap: null,
                        ),
                      ),

                      // Comments header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'Comments',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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
                                  color: CupertinoColors.secondaryLabel,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final comment = postDetailState.comments[index];
                            return _CommentItem(comment: comment);
                          }, childCount: postDetailState.comments.length),
                        ),

                      // Bottom padding for scroll
                      const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    ],
                  ],
                ),
              ),
            ),

            // Comment input area
            if (postDetailState.post != null)
              _buildCommentInput(context, postDetailState),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final iconColor = CupertinoDynamicColor.resolve(
      CupertinoColors.label,
      context,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.14, 0.67],
          colors: [
            _resolveColor(context, _cardBackgroundStart),
            _resolveColor(context, _cardBackgroundEnd),
          ],
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                // Back button
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 35,
                    height: 35,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: CupertinoDynamicColor.resolve(
                        CupertinoColors.systemGrey5,
                        context,
                      ),
                    ),
                    child: Icon(
                      CupertinoIcons.chevron_back,
                      size: 18,
                      color: iconColor,
                    ),
                  ),
                ),
                const Spacer(),
                // Title
                Text(
                  'Post',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                ),
                const Spacer(),
                // Placeholder to balance the row
                const SizedBox(width: 35),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput(BuildContext context, PostDetailState state) {
    final inputBg = CupertinoDynamicColor.resolve(
      const CupertinoDynamicColor.withBrightness(
        color: Color(0xFFFFFFFF),
        darkColor: Color(0xFF1C1C1E),
      ),
      context,
    );

    // Get the keyboard height (viewInsets) and safe area padding
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safePadding = MediaQuery.of(context).padding.bottom;
    // When keyboard is up, add viewInsets to push content above keyboard
    // When keyboard is down, add safe area padding for home indicator
    final bottomPadding = bottomInset > 0 ? bottomInset : safePadding;

    return Container(
      decoration: BoxDecoration(
        color: inputBg,
        border: Border(
          top: BorderSide(
            color: CupertinoDynamicColor.resolve(
              CupertinoColors.separator,
              context,
            ),
            width: 0.5,
          ),
        ),
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
            child: CupertinoTextField(
              controller: _commentController,
              placeholder: 'Add a comment...',
              placeholderStyle: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                color: CupertinoColors.systemGrey,
              ),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              decoration: BoxDecoration(
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.systemGrey6,
                  context,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.label,
                  context,
                ),
              ),
              cursorColor: CupertinoColors.systemBlue,
              minLines: 1,
              maxLines: 4,
            ),
          ),
          const SizedBox(width: 8),
          if (state.isSubmittingComment)
            const CupertinoActivityIndicator()
          else
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _submitComment,
              child: Text(
                'Post',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.systemBlue,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CommentItem extends StatelessWidget {
  final Comment comment;

  const _CommentItem({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            imageUrl: comment.author?.profilePictureUrl,
            name: comment.author?.username ?? 'U',
            size: 36,
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
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeago.format(comment.createdAt, locale: 'en_short'),
                      style: GoogleFonts.plusJakartaSans(
                        color: CupertinoColors.secondaryLabel,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment.content,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
