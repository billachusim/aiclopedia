import 'package:ai_clopedia/screens/question_details.dart';
import 'dart:ui';
import 'package:ai_clopedia/app_state.dart';
import 'package:ai_clopedia/services/firebase_services.dart';
import 'package:ai_clopedia/services/hidden_posts_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../app_theme.dart';
import '../models/question_model.dart';

class QuestionWidget extends StatefulWidget {
  final Question question;
  final Widget? trailing; // For admin toggles or extra actions

  const QuestionWidget({
    super.key,
    required this.question,
    this.trailing,
  });

  @override
  State<QuestionWidget> createState() => _QuestionWidgetState();
}

class _QuestionWidgetState extends State<QuestionWidget> {
  // Services
  final FirebaseServices _firebaseServices = FirebaseServices();
  final HiddenPostsService _hiddenPostsService = HiddenPostsService();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // State
  late int _thumbsUpCount;
  late int _thumbsDownCount;

  @override
  void initState() {
    super.initState();
    _thumbsUpCount = widget.question.thumbsUpCount;
    _thumbsDownCount = widget.question.thumbsDownCount;
  }

  // --- START: MODERATION ACTION HANDLERS ---

  /// Option 1: Removes the post from the user's feed locally.
  Future<void> _removePostFromFeed(String questionId) async {
    await _hiddenPostsService.hidePost(questionId);
    if (mounted) {
      _showToast("This post has been removed from your feed.");
      // Trigger a refresh on the feed page.
      App.refreshFeed.add(true);
    }
  }

  /// Option 2: Reports the post and its owner, then hides it.
  Future<void> _reportPostAndOwner(String questionId, String ownerId) async {
    final success = await _firebaseServices.reportQuestion(questionId, ownerId);
    if (success) {
      await _hiddenPostsService.hidePost(questionId);
      if (mounted) {
        _showToast("This post has been reported and will be removed from your feed.");
        App.refreshFeed.add(true);
      }
    } else {
      if (mounted) _showToast("Failed to report post. Please try again.");
    }
  }

  /// Option 3: Blocks the post owner and hides their content.
  Future<void> _blockUser(String userIdToBlock) async {
    final success = await _firebaseServices.blockUser(userIdToBlock);
    if (success && mounted) {
      _showToast("This user has been blocked. Their content will no longer be visible.");
      // We don't need to hide individual posts, the feed query will handle this.
      App.refreshFeed.add(true);
    } else {
      if (mounted) _showToast("Failed to block user. Please try again.");
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // --- END: MODERATION ACTION HANDLERS ---


  Future<void> _updateCount(String field) async {
    final docRef = FirebaseFirestore.instance
        .collection('questions')
        .doc(widget.question.questionId);

    FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw Exception("Document does not exist!");
      }
      final currentCount = snapshot.data()![field] as int? ?? 0;
      transaction.update(docRef, {field: currentCount + 1});
    }).catchError((error, stackTrace) {
      if (mounted) {
        setState(() {
          if (field == 'thumbsUpCount') {
            _thumbsUpCount--;
          } else if (field == 'thumbsDownCount') {
            _thumbsDownCount--;
          }
        });
      }
    });
  }

  void _incrementThumbsUp() {
    setState(() => _thumbsUpCount++);
    _updateCount('thumbsUpCount');
  }

  void _incrementThumbsDown() {
    setState(() => _thumbsDownCount++);
    _updateCount('thumbsDownCount');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QuestionDetails(question: widget.question),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.glassmorphismColor(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 12),
                  _buildBody(context),
                  const SizedBox(height: 16),
                  _buildFooter(context),
                  if (widget.trailing != null) ...[
                    const Divider(height: 24),
                    widget.trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final secondaryTextColor = textColor.withValues(alpha: 0.7);

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          child: Icon(Icons.person_outline, color: textColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.question.nickname,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 12, color: secondaryTextColor),
                  const SizedBox(width: 4),
                  Text(
                    widget.question.city,
                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.person_outline, size: 12, color: secondaryTextColor),
                  const SizedBox(width: 4),
                  Text(
                    widget.question.gender,
                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                  ),
                ],
              ),
              Text(
                timeago.format(widget.question.timestamp),
                style: TextStyle(fontSize: 11, color: secondaryTextColor.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
        // --- ADDED: MODERATION POPUP BUTTON (HIDDEN FROM OWNER) ---
        if (widget.question.userId != currentUser?.uid)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz, color: textColor.withValues(alpha: 0.5)),
            onSelected: (String value) {
              final questionId = widget.question.questionId;
              final ownerId = widget.question.userId;

              switch (value) {
                case 'remove_post':
                  _removePostFromFeed(questionId);
                  break;
                case 'report_post':
                  _reportPostAndOwner(questionId, ownerId);
                  break;
                case 'block_user':
                  _blockUser(ownerId);
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'remove_post',
                child: Text('Remove post from my feed'),
              ),
              const PopupMenuItem<String>(
                value: 'report_post',
                child: Text('Report this post & owner'),
              ),
              const PopupMenuItem<String>(
                value: 'block_user',
                child: Text('Block owner of this post'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryTextColor = theme.colorScheme.onSurface.withValues(alpha: 0.7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.question.isFeatured)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, size: 12, color: AppTheme.primaryGreen),
                const SizedBox(width: 4),
                Text(
                  "FEATURED",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        Text(
          widget.question.question,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: theme.colorScheme.onSurface,
            height: 1.4,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        if (widget.question.answer.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 14, color: AppTheme.primaryGreen),
                    const SizedBox(width: 6),
                    Text(
                      "AI ANSWER",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.question.answer,
                  style: TextStyle(
                    fontSize: 14,
                    color: secondaryTextColor,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildActionButton(
          icon: Icons.thumb_up_alt_outlined,
          count: _thumbsUpCount,
          onPressed: _incrementThumbsUp,
          color: AppTheme.primaryGreen,
        ),
        const SizedBox(width: 20),
        _buildActionButton(
          icon: Icons.thumb_down_alt_outlined,
          count: _thumbsDownCount,
          onPressed: _incrementThumbsDown,
          color: AppTheme.accentPink,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required int count,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 6),
          Text(
            count.toString(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
