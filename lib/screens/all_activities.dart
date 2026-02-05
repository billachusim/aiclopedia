import 'dart:ui';
import 'package:AiClopedia/screens/question_details.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../app_theme.dart';
import '../constants/scrollable_page.dart';
import '../models/questionModel.dart';
import '../services/ad_state.dart';
import '../services/firebaseServices.dart';
import '../services/helper.dart'; // For the logger

// --- NEW: Change StatefulWidget to ScrollablePage ---
class AllActivitiesScreen extends ScrollablePage {
  const AllActivitiesScreen({Key? key}) : super(key: key);

  @override
  // --- NEW: The State class now extends ScrollablePageState ---
  ScrollablePageState<AllActivitiesScreen> createState() =>
      _AllActivitiesScreenState();
}

// --- NEW: Extend from ScrollablePageState ---
class _AllActivitiesScreenState extends ScrollablePageState<AllActivitiesScreen> {
  BannerAd? activitiesScreenTopBanner;

  // --- NEW: Add ScrollController ---
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    activitiesScreenTopBanner?.dispose();
    // --- NEW: Dispose ScrollController ---
    _scrollController.dispose();
    super.dispose();
  }

  // --- NEW: Implemented from ScrollablePageState ---
  @override
  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  // --- NEW: Function to handle pull-to-refresh ---
  Future<void> _handleRefresh() async {
    // The StreamBuilder will automatically re-fetch data.
    // Adding a delay to make the refresh indicator visible.
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (activitiesScreenTopBanner == null) {
      final adState = Provider.of<AdState>(context);
      adState.initialization.then((status) {
        if (!mounted) return;
        setState(() {
          activitiesScreenTopBanner = BannerAd(
              size: AdSize.banner,
              adUnitId: adState.activitiesScreenTopBannerAdUnitId,
              request: const AdRequest(),
              listener: BannerAdListener(
                onAdFailedToLoad: (ad, error) {
                  ad.dispose();
                },
              ))
            ..load();
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Questions (Admin)'),
        // Use theme colors
        backgroundColor: theme.appBarTheme.backgroundColor,
        titleTextStyle: theme.appBarTheme.titleTextStyle,
        iconTheme: theme.appBarTheme.iconTheme,
        // Use a standard back button that just pops the screen
        automaticallyImplyLeading: true,
      ),
      body: Column(
        children: [
          // Top ad unit
          if (activitiesScreenTopBanner != null)
            SizedBox(
              height: activitiesScreenTopBanner!.size.height.toDouble(),
              child: AdWidget(ad: activitiesScreenTopBanner!),
            )
          else
            SizedBox(
              height: 50,
              child: Center(
                  child: Text('Relevant ads only',
                      style: theme.textTheme.bodySmall)),
            ),
          Expanded(
            child: StreamBuilder<List<Question>>(
              stream: getAllQuestions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No questions yet.'));
                }
                final questions = snapshot.data!;
                // --- NEW: Wrap with RefreshIndicator ---
                return RefreshIndicator(
                  onRefresh: _handleRefresh,
                  backgroundColor:
                  isDarkMode ? AppTheme.darkBackground : Colors.white,
                  color: AppTheme.primaryGreen,
                  child: ListView.builder(
                    // --- NEW: Assign ScrollController ---
                    controller: _scrollController,
                    itemCount: questions.length,
                    padding: const EdgeInsets.only(top: 8, bottom: 32),
                    itemBuilder: (context, index) {
                      final question = questions[index];
                      // --- NEW: Use the redesigned admin question card ---
                      return _buildAdminQuestionCard(context, question);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- NEW: A dedicated widget for the admin question card view ---
  Widget _buildAdminQuestionCard(BuildContext context, Question question) {
    final theme = Theme.of(context);
    final secondaryTextColor = theme.colorScheme.onSurface.withOpacity(0.7);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.glassmorphismColor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Question Text ---
                Text(
                  question.question,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600, fontSize: 16),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // --- User Info ---
                Row(
                  children: [
                    Icon(Icons.person_outline,
                        color: secondaryTextColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${question.nickname} • ${question.nameOfSchool}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: secondaryTextColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // --- Timestamp ---
                Row(
                  children: [
                    Icon(Icons.access_time,
                        color: secondaryTextColor, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      timeago.format(question.timestamp),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: secondaryTextColor),
                    ),
                  ],
                ),
                const Divider(height: 24),
                // --- Admin Actions ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // --- View Details Button ---
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                QuestionDetails(question: question),
                          ),
                        );
                      },
                      child: const Text('View Details'),
                    ),

                    // --- Feature Toggle ---
                    InkWell(
                      onTap: () => toggleFeaturedStatus(question, !question.isFeatured),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          children: [
                            Text(
                              'Feature',
                              style: TextStyle(
                                  color: question.isFeatured
                                      ? AppTheme.primaryGreen
                                      : secondaryTextColor,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              question.isFeatured
                                  ? Icons.toggle_on
                                  : Icons.toggle_off_outlined,
                              color: question.isFeatured
                                  ? AppTheme.primaryGreen
                                  : secondaryTextColor,
                              size: 30,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Stream<List<Question>> getAllQuestions() {
    return FirebaseFirestore.instance
        .collection('questions')
        .orderBy('timestamp', descending: true)
        .limit(100) // Limiting the load for performance
        .snapshots()
        .map((querySnapshot) => querySnapshot.docs
        .map((doc) => Question.fromJson(doc.data()))
        .toList());
  }

  // --- REFACTORED: Combined feature logic into one method ---
  Future<void> toggleFeaturedStatus(Question question, bool newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('questions')
          .doc(question.questionId)
          .update({
        "isFeatured": newStatus,
      });
      logger.d('Successfully changed feature to $newStatus for question ${question.questionId}');
      // The UI will update automatically via the StreamBuilder
    } catch (e) {
      logger.e('Failed to update feature status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status. Please try again.')),
        );
      }
    }
  }
}
