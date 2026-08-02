import 'dart:async';
import 'dart:developer';
import 'dart:ui';
import 'package:ai_clopedia/app_state.dart';
import 'package:ai_clopedia/screens/settings_page.dart';
import 'package:ai_clopedia/services/hidden_posts_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_clopedia/screens/all_activities.dart';
import 'package:ai_clopedia/screens/chat_screen.dart';
import 'package:ai_clopedia/models/question_model.dart';
import 'package:ai_clopedia/models/user_model.dart';
import 'package:ai_clopedia/services/ad_state.dart';
import 'package:ai_clopedia/services/firebase_services.dart';
import 'package:ai_clopedia/widgets/question_widget.dart';
import 'package:ai_clopedia/screens/login/login.dart';

import '../app_theme.dart';
import '../constants/scrollable_page.dart';
import '../widgets/auto_scroll_container.dart';
import '../widgets/quick_chat_strips.dart';
import 'credits_screen.dart';
import '../services/ad_service.dart';


class Homepage extends ScrollablePage {
  const Homepage({super.key});

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
  BannerAd? homeBottomBanner;

  Stream<List<Question>>? _questionStream;
  StreamSubscription? _refreshSubscription;


  @override
  void initState() {
    super.initState();
    _initializeHomepage();
  }

  void _initializeHomepage() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastCheckTime = prefs.getInt('last_permission_check') ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        
        // Re-check every 7 days (7 * 24 * 60 * 60 * 1000)
        final bool shouldRecheck = (now - lastCheckTime) > 604800000;

        if (shouldRecheck) {
          final status = await AppTrackingTransparency.trackingAuthorizationStatus;
          if (status != TrackingStatus.authorized) {
            await Future.delayed(const Duration(milliseconds: 1500));
            await AppTrackingTransparency.requestTrackingAuthorization();
          }
          
          if (currentUser != null) {
            final user = await firebaseServices.getUserInfo();
            if (!user.hasConsentedToDataSharing && mounted) {
              await firebaseServices.checkAndRequestDataSharingConsent(context, user);
            }
          }
          
          await prefs.setInt('last_permission_check', now);
        }
      } catch (e) {
        log("Error requesting ATT or consent: $e");
      }
    });

    if (currentUser != null) {
      getUser();
      // Initialize and listen for refreshes
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

  void _loadBanners() {
    final adState = Provider.of<AdState>(context, listen: false);
    adState.initialization.then((status) {
      if (!mounted) return;
      setState(() {
        homeBottomBanner = BannerAd(
          size: AdSize.banner,
          adUnitId: adState.homeBottomBannerAdUnitId,
          request: const AdRequest(),
          listener: BannerAdListener(onAdFailedToLoad: (ad, error) => ad.dispose()),
        )..load();
      });
    });
  }

  void _loadQuestionStream() {
    if (!mounted) return;
    setState(() {
      _questionStream = getQuestionsStream();
    });
  }

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

    // 3. Build the Firestore query
    Query query = FirebaseFirestore.instance
        .collection('questions')
        .where('isFeatured', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .limit(50);

    // 4. Listen to the stream and apply client-side filtering
    await for (final querySnapshot in query.snapshots()) {
      final questions = querySnapshot.docs
          .map((doc) => Question.fromJson(doc.data() as Map<String, dynamic>))
          .where((question) {
        // Client-side filter for locally hidden posts, blocked users, and privacy.
        final isHidden = hiddenPostIds.contains(question.questionId);
        final isBlocked = blockedUserIds.contains(question.userId);
        return !isHidden && !isBlocked && question.isPublic;
      }).toList();
      yield questions;
    }
  }

  void _onAskAiPressed() async {
    if (currentUser == null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => LoginPage()));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    bool hasConsent = prefs.getBool('ai_consent') ?? false;

    if (!hasConsent && mounted) {
      _showAiConsentDialog();
    } else {
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatScreen()));
    }
  }

  void _showAiConsentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("AI Privacy Disclosure"),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                "To provide intelligent responses and creative content, AiClopedia uses third-party AI services (including Google Gemini and OpenAI). "
                "\n\nBy continuing, your questions and prompts will be shared with these AI providers to generate answers and images. "
                "Please do not share sensitive personal information.",
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 10),
              Text(
                "For more details, please review our Privacy Policy.",
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Decline"),
            ),
            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('ai_consent', true);
                
                // Sync with Firebase
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await FirebaseServices().updateConsentStatus(user.uid, true);
                }

                if (context.mounted) {
                  Navigator.of(context).pop();
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatScreen()));
                }
              },
              child: const Text("I Understand & Agree"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUnlockCTA() {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_outline, size: 48, color: AppTheme.primaryGreen),
          const SizedBox(height: 16),
          const Text(
            "Want to see more?",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "You've reached the free limit. Watch a quick ad or top up credits to unlock the full feed.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  final adState = Provider.of<AdState>(context, listen: false);
                  AdService.instance.showRewardedAd(
                    context: context,
                    adState: adState,
                    onRewardEarned: (reward) async {
                      if (currentUser != null) {
                        await firebaseServices.updateUserCredits(currentUser!.uid, reward);
                        _loadQuestionStream(); // Refresh feed
                      }
                    },
                  );
                },
                icon: const Icon(Icons.play_circle_fill),
                label: const Text("Watch Ad"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                ),
              ),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const CreditsScreen()));
                },
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryGreen),
                child: const Text("Buy Credits"),
              ),
            ],
          ),
        ],
      ),
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
            image: const AssetImage("assets/images/iconWhitePetal.png"),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.white.withAlpha(30), BlendMode.dstATop),
          ),
        ),
        child: Column(
          children: [
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
                              const SizedBox(height: 20),
                              QuickChatStrips(
                                onSelect: (prompt) {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(initialPrompt: prompt)));
                                },
                              ),
                              const SizedBox(height: 24),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: LinearGradient(
                                      colors: [AppTheme.accentPink, AppTheme.accentPink.withValues(alpha: 0.8)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.accentPink.withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.psychology_alt, color: Colors.white, size: 28),
                                    label: const Text(
                                      "Ask AI Anything",
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      minimumSize: const Size(double.infinity, 64),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    ),
                                    onPressed: _onAskAiPressed,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),

                        // --- Sticky Header ---
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _SliverHeaderDelegate(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0),
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1))),
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "Featured Questions",
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
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
                            
                            return StreamBuilder<UserModel>(
                              stream: currentUser != null ? firebaseServices.streamUser(currentUser!.uid) : const Stream.empty(),
                              builder: (context, userSnapshot) {
                                final questions = snapshot.data!;
                                bool isLimited = false;
                                
                                if (userSnapshot.hasData) {
                                  final user = userSnapshot.data!;
                                  final bool hasCredits = user.credits > 0 || user.isPremium;
                                  final bool isUnlocked = AdService.instance.isAdUnlockedForSession;
                                  
                                  if (!hasCredits && !isUnlocked && questions.length > 10) {
                                    isLimited = true;
                                  }
                                }

                                final displayCount = isLimited ? 10 : questions.length;

                                return SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      if (isLimited && index == displayCount) {
                                        return _buildUnlockCTA();
                                      }
                                      return QuestionWidget(question: questions[index]);
                                    },
                                    childCount: isLimited ? displayCount + 1 : displayCount,
                                  ),
                                );
                              }
                            );
                          },
                        ),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
  static const double _headerHeight = 48.0;

  _SliverHeaderDelegate({required this.child});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor.withAlpha(220), // Blended background
      child: child,
    );
  }

  @override
  double get maxExtent => _headerHeight;

  @override
  double get minExtent => _headerHeight;

  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) {
    return true; // Rebuild if properties change
  }
}
