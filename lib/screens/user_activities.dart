import 'dart:io';
import 'dart:ui';
import 'package:AiClopedia/screens/question_details.dart';
import 'package:AiClopedia/services/firebaseServices.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../constants/scrollable_page.dart';
import '../models/questionModel.dart';
import '../services/ad_state.dart';
import 'login/login.dart';

// --- NEW: Change StatefulWidget to ScrollablePage ---
class ActivitiesScreen extends ScrollablePage {
  const ActivitiesScreen({Key? key}) : super(key: key);

  @override
  // --- NEW: The State class now extends ScrollablePageState ---
  ScrollablePageState<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

const int maxFailedLoadAttempts = 3;

// --- NEW: Extend from ScrollablePageState ---
class _ActivitiesScreenState extends ScrollablePageState<ActivitiesScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseServices firebaseServices = FirebaseServices();

  // --- NEW: Add ScrollController ---
  final ScrollController _scrollController = ScrollController();

  BannerAd? activitiesScreenTopBanner;
  InterstitialAd? _interstitialAd;
  int _interstitialLoadAttempts = 0;

  @override
  void initState() {
    super.initState();
    _createInterstitialAd();
  }

  @override
  void dispose() {
    Future.delayed(const Duration(seconds: 2), _showInterstitialAd);
    activitiesScreenTopBanner?.dispose();
    // --- NEW: Dispose ScrollController ---
    _scrollController.dispose();
    super.dispose();
    _interstitialAd?.dispose();
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


  void _createInterstitialAd() {
    InterstitialAd.load(
      adUnitId: Platform.isAndroid
          ? "ca-app-pub-2404156870680632/2913195951"
          : "ca-app-pub-2404156870680632/3304176259",
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _interstitialLoadAttempts = 0;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _interstitialLoadAttempts += 1;
          _interstitialAd = null;
          if (_interstitialLoadAttempts <= maxFailedLoadAttempts) {
            _createInterstitialAd();
          }
        },
      ),
    );
  }

  void _showInterstitialAd() {
    if (_interstitialAd == null) return;
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        ad.dispose();
        _createInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        ad.dispose();
        _createInterstitialAd();
      },
    );
    _interstitialAd!.show();
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
              onAdFailedToLoad: (ad, error) => ad.dispose(),
            ),
          )..load();
        });
      });
    }
  }

  deleteAccountAlertDialog(BuildContext context) {
    Widget cancelButton = TextButton(
      child: const Text("CANCEL"),
      onPressed: () => Navigator.of(context).pop(),
    );

    Widget continueButton = TextButton(
      child: const Text("DELETE", style: TextStyle(color: Colors.red)),
      onPressed: () {
        firebaseServices.deleteUserAccount(context, currentUser!.uid);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginPage()),
              (Route<dynamic> route) => false,
        );
      },
    );

    AlertDialog alert = AlertDialog(
      title: const Text("Delete Account?"),
      content: const Text("This action is irreversible and will delete all your data."),
      actions: [cancelButton, continueButton],
    );

    showDialog(context: context, builder: (BuildContext context) => alert);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // This handles the case where the user somehow lands here without being logged in.
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Questions')),
        body: const Center(child: Text("Please log in to see your activities.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Questions'),
        // Use theme colors for AppBar
        backgroundColor: theme.appBarTheme.backgroundColor,
        titleTextStyle: theme.appBarTheme.titleTextStyle,
        iconTheme: theme.appBarTheme.iconTheme,
        actions: [
          PopupMenuButton(
            color: theme.colorScheme.surface,
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete Account', style: TextStyle(color: theme.colorScheme.onSurface)),
              ),
            ],
            onSelected: (value) {
              if (value == 'delete') {
                deleteAccountAlertDialog(context);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
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
                        style: theme.textTheme.bodySmall))),
          Expanded(
            child: StreamBuilder<List<Question>>(
              stream: getQuestions(currentUser!.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('You have not asked any questions yet.'));
                }
                final questions = snapshot.data!;
                return ListView.builder(
                  // --- NEW: Assign ScrollController ---
                  controller: _scrollController,
                  itemCount: questions.length,
                  itemBuilder: (context, index) {
                    final question = questions[index];
                    // --- NEW: Use a redesigned, theme-aware widget ---
                    return _buildQuestionCard(context, question);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- REVISED: Update the question card to a more refined UI ---
  Widget _buildQuestionCard(BuildContext context, Question question) {
    final theme = Theme.of(context);
    final secondaryTextColor = theme.colorScheme.onSurface.withOpacity(0.7);

    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Getting answers; might see an ad.')),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => QuestionDetails(question: question)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppTheme.glassmorphismColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question.question,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 16),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8.0),
                  if (question.answer.isNotEmpty)
                    Text(
                      'Answer: ${question.answer}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14, color: secondaryTextColor),
                    ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Featured Status Icon
                      Row(
                        children: [
                          Icon(
                            question.isFeatured ? Icons.star : Icons.star_border,
                            color: question.isFeatured ? AppTheme.primaryGreen : secondaryTextColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            question.isFeatured ? 'Featured' : 'Standard',
                            style: theme.textTheme.bodySmall?.copyWith(color: secondaryTextColor),
                          ),
                        ],
                      ),
                      // View Button
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20.0),
                            color: AppTheme.primaryGreen.withOpacity(0.1),
                            border: Border.all(color: AppTheme.primaryGreen)
                        ),
                        child: Text('VIEW DETAILS',
                          style: TextStyle(
                              fontSize: 12.0,
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.bold),
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  Stream<List<Question>> getQuestions(String userId) {
    return FirebaseFirestore.instance
        .collection('questions')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((querySnapshot) =>
        querySnapshot.docs.map((doc) => Question.fromJson(doc.data())).toList());
  }
}
