import 'dart:async';
import 'dart:developer';
import 'dart:ui';
import 'package:AiClopedia/app_state.dart';
import 'package:AiClopedia/screens/settings_page.dart';
import 'package:AiClopedia/services/hidden_posts_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

import 'package:AiClopedia/screens/all_activities.dart';
import 'package:AiClopedia/screens/question_details.dart';
import 'package:AiClopedia/screens/chat_screen.dart';
import 'package:AiClopedia/models/questionModel.dart';
import 'package:AiClopedia/models/userModel.dart';
import 'package:AiClopedia/services/ad_state.dart';
import 'package:AiClopedia/services/firebaseServices.dart';
import 'package:AiClopedia/widgets/question_widget.dart';
import 'package:AiClopedia/screens/login/login.dart';

import '../app_theme.dart';
import '../constants/scrollable_page.dart';
import '../widgets/auto_scroll_container.dart';
import 'credits_screen.dart';


class Homepage extends ScrollablePage {
  const Homepage({Key? key}) : super(key: key);

  @override
  ScrollablePageState<Homepage> createState() => _HomepageState();
}

const int maxFailedLoadAttempts = 3;

class _HomepageState extends ScrollablePageState<Homepage> {
  final FirebaseServices firebaseServices = FirebaseServices();
  final HiddenPostsService hiddenPostsService = HiddenPostsService();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  String nickname = '';

  final ScrollController _scrollController = ScrollController();

  RewardedInterstitialAd? _interstitialAd;
  //int _interstitialLoadAttempts = 0;
  //BannerAd? homeTopBanner;
  BannerAd? homeBottomBanner;

  // --- MODIFIED: For managing the question stream ---
  Stream<List<Question>>? _questionStream;
  StreamSubscription? _refreshSubscription;


  @override
  void initState() {
    super.initState();
    _initializeHomepage();
  }

  void _initializeHomepage() async {
    await AppTrackingTransparency.requestTrackingAuthorization();
    //_createInterstitialAd();
    if (currentUser != null) {
      getUser();
      // --- ADDED: Initialize and listen for refreshes ---
      _loadQuestionStream();
      _refreshSubscription = App.refreshFeed.stream.listen((_) {
        _loadQuestionStream();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadBanners();
  }

  @override
  void dispose() {
    //Future.delayed(const Duration(seconds: 2), _showInterstitialAd);
    //homeTopBanner?.dispose();
    homeBottomBanner?.dispose();
    _scrollController.dispose();
    _refreshSubscription?.cancel();
    super.dispose();
    _interstitialAd?.dispose();
  }

  void getUser() async {
    if (nickname.isEmpty) {
      final UserModel user = await firebaseServices.getUserInfo();
      if (mounted) {
        setState(() {
          nickname = user.nickname;
        });
      }
    }
  }

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



  /*void _createInterstitialAd() {
    RewardedInterstitialAd.load(
      adUnitId: Platform.isAndroid
          ? "ca-app-pub-2404156870680632/7858400876"
          : "ca-app-pub-2404156870680632/8883805999",
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (RewardedInterstitialAd ad) {
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
    if (_interstitialAd == null) {
      _createInterstitialAd();
      return;
    }
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (RewardedInterstitialAd ad) {
        ad.dispose();
        _createInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (RewardedInterstitialAd ad, AdError error) {
        ad.dispose();
        _createInterstitialAd();
      },
    );
    _interstitialAd!.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {});
  }*/

  void _loadBanners() {
    final adState = Provider.of<AdState>(context, listen: false);
    adState.initialization.then((status) {
      if (!mounted) return;
      setState(() {
        /*homeTopBanner = BannerAd(
          size: AdSize.banner,
          adUnitId: adState.homeTopBannerAdUnitId,
          request: const AdRequest(),
          listener: BannerAdListener(onAdFailedToLoad: (ad, error) => ad.dispose()),
        )..load();*/

        homeBottomBanner = BannerAd(
          size: AdSize.banner,
          adUnitId: adState.homeBottomBannerAdUnitId,
          request: const AdRequest(),
          listener: BannerAdListener(onAdFailedToLoad: (ad, error) => ad.dispose()),
        )..load();
      });
    });
  }

  // --- ADDED: New method to load and filter the question stream ---
  void _loadQuestionStream() {
    if (!mounted) return;
    setState(() {
      _questionStream = getQuestionsStream();
    });
  }

  // --- MODIFIED: Complete feed-filtering logic ---
  Stream<List<Question>> getQuestionsStream() async* {
    if (currentUser == null) {
      yield []; // Return an empty stream if user is not logged in.
      return;
    }

    // 1. Fetch current user data to get blocked user list.
    UserModel? userData;
    List<String> blockedUserIds = [];
    try {
      userData = await firebaseServices.getUserInfo();
      blockedUserIds = userData.blockedUsers;
    } catch (e) {
      log("Could not fetch user info for blocking: $e");
    }

    // 2. Fetch locally hidden post IDs.
    final hiddenPostIds = await hiddenPostsService.getHiddenPostIds();

    // 3. Build the Firestore query without the problematic 'whereNotIn' filter.
    Query query = FirebaseFirestore.instance
        .collection('questions')
        .where('isFeatured', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .limit(50);

    // 4. Listen to the stream and apply client-side filtering for both hidden posts and blocked users.
    await for (final querySnapshot in query.snapshots()) {
      final questions = querySnapshot.docs
          .map((doc) => Question.fromJson(doc.data() as Map<String, dynamic>))
          .where((question) {
        // Client-side filter for locally hidden posts and blocked users.
        final isHidden = hiddenPostIds.contains(question.questionId);
        final isBlocked = blockedUserIds.contains(question.userId);
        return !isHidden && !isBlocked;
      }).toList();
      yield questions;
    }
  }



  void _onAskAiPressed() {
    if (currentUser == null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => LoginPage()));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatScreen()));
    }
  }

  void _onQuestionTapped(Question question) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Getting answers.')),
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => QuestionDetails(question: question)),
    );
  }


  Future<void> _handleRefresh() async {
    if (mounted) {
      if (currentUser != null) {
        getUser();
        _loadQuestionStream();
      }
    }
    await Future.delayed(const Duration(seconds: 1));
  }



  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDarkMode ? AppTheme.darkBackground.withAlpha(200) : AppTheme.primaryGreen,
        elevation: 2,
        title: const Text("AiClopedia"),
        leading: GestureDetector(
          onDoubleTap: () async {
            final navigator = Navigator.of(context);
            final user = await firebaseServices.getUserInfo();
            if (user.userType == 'ADMIN' && mounted) {
              navigator.push(MaterialPageRoute(builder: (context) => AllActivitiesScreen()));
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset("assets/images/aiclop.png"),
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.monetization_on, color: Colors.white),
            label: const Text('Credits', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreditsScreen()),
              );
            },
          ),
          if (currentUser == null)
            TextButton.icon(
              icon: const Icon(Icons.login, color: Colors.white),
              label: const Text('Login', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginPage(),
                  ),
                );
              },
            )
          else
            TextButton.icon(
              icon: const Icon(Icons.settings_outlined),
              label:
              const Text('Settings', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => const SettingsPage()));
              },
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              isDarkMode ? "assets/images/iconWhitePetal.png" : "assets/images/iconWhitePetal.png",
            ),
            fit: BoxFit.cover,
            colorFilter: isDarkMode
                ? ColorFilter.mode(Colors.white.withAlpha(30), BlendMode.dstATop)
                : ColorFilter.mode(Colors.white.withAlpha(30), BlendMode.dstATop),
          ),
        ),
        child: Column(
          children: [
            /*// --- Anchored Top Banner ---
            if (homeTopBanner != null)
              SizedBox(
                height: homeTopBanner!.size.height.toDouble(),
                child: AdWidget(ad: homeTopBanner!),
              ),
            // --- Scrollable Content ---*/
            Expanded(
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                backgroundColor: isDarkMode ? AppTheme.darkBackground : Colors.white,
                color: AppTheme.primaryGreen,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        // --- Section that scrolls away ---
                        SliverToBoxAdapter(
                          child: Column(
                            children: [
                              const SizedBox(height: 16),
                              InspirationalQuoteCard(nickname: nickname),
                              const SizedBox(height: 24),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.psychology_alt, color: Colors.white),
                                  label: const Text(
                                    "Ask AI Anything",
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accentPink,
                                    minimumSize: const Size(double.infinity, 56),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 8,
                                    shadowColor: AppTheme.accentPink.withAlpha(128),
                                  ),
                                  onPressed: _onAskAiPressed,
                                ),
                              ),
                              // The space that was above the header is now here
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),

                        // --- Sticky Header ---
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _SliverHeaderDelegate(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "Community Questions:",
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // --- Scrollable List of Questions ---
                        StreamBuilder<List<Question>>(
                          stream: _questionStream,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
                              return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
                            }
                            if (snapshot.hasError) {
                              return SliverToBoxAdapter(child: Center(child: Text("Error: ${snapshot.error}")));
                            }
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return SliverToBoxAdapter(
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32.0),
                                    child: Text(
                                      'No questions yet. Please log in first ',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              );
                            }
                            final questions = snapshot.data!;
                            return SliverList(
                              delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                  final question = questions[index];
                                  return GestureDetector(
                                    onTap: () => _onQuestionTapped(question),
                                    child: QuestionWidget(question: question),
                                  );
                                },
                                childCount: questions.length,
                              ),
                            );
                          },
                        ),
                        // Added padding at the end of the scroll view
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // --- Anchored Bottom Banner ---
            if (homeBottomBanner != null)
              SizedBox(
                height: homeBottomBanner!.size.height.toDouble(),
                child: AdWidget(ad: homeBottomBanner!),
              ),
          ],
        ),
      ),
    );
  }



}



class _SliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _SliverHeaderDelegate({required this.child, this.height = 48.0});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor.withAlpha(220), // Blended background
      child: child,
    );
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) {
    return true; // Rebuild if properties change
  }
}

