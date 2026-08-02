import 'package:ai_clopedia/services/firebase_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ai_clopedia/widgets/question_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../constants/scrollable_page.dart';
import '../models/question_model.dart';
import '../models/user_model.dart';
import '../services/ad_state.dart';
import '../services/ad_service.dart';
import 'credits_screen.dart';
import 'login/login.dart';

// --- NEW: Change StatefulWidget to ScrollablePage ---
class ActivitiesScreen extends ScrollablePage {
  const ActivitiesScreen({super.key});

  @override
  // --- NEW: The State class now extends ScrollablePageState ---
  ScrollablePageState<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

const int maxFailedLoadAttempts = 3;

// --- NEW: Extend from ScrollablePageState ---
class _ActivitiesScreenState extends ScrollablePageState<ActivitiesScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseServices firebaseServices = FirebaseServices();

  // --- NEW: Add ScrollControllers for each tab ---
  final ScrollController _myQuestionsController = ScrollController();
  final ScrollController _communityController = ScrollController();

  BannerAd? activitiesScreenTopBanner;
  InterstitialAd? _interstitialAd;

  String _filterType = 'All'; // All, Text, Image
  String _sortBy = 'Newest'; // Newest, Popular
  String _genderFilter = 'All'; // All, Male, Female, Other
  final TextEditingController _citySearchController = TextEditingController();
  final TextEditingController _keywordSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _createInterstitialAd();
  }

  @override
  void dispose() {
    activitiesScreenTopBanner?.dispose();
    _myQuestionsController.dispose();
    _communityController.dispose();
    _citySearchController.dispose();
    _keywordSearchController.dispose();
    super.dispose();
    _interstitialAd?.dispose();
  }

  @override
  void scrollToTop() {
    // Scroll the active tab to top
    if (_myQuestionsController.hasClients) {
      _myQuestionsController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    }
    if (_communityController.hasClients) {
      _communityController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    }
  }


  void _createInterstitialAd() {
    // Interstitial ads removed from Activities per user request
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

  void deleteAccountAlertDialog(BuildContext context) {
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
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Activities')),
        body: const Center(child: Text("Please log in to see your activities.")),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Activities'),
          backgroundColor: theme.appBarTheme.backgroundColor,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'My Questions'),
              Tab(text: 'Community'),
            ],
            indicatorColor: AppTheme.primaryGreen,
            labelColor: AppTheme.primaryGreen,
            unselectedLabelColor: Colors.grey,
          ),
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
              ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildMyQuestionsTab(),
                  _buildCommunityTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyQuestionsTab() {
    return StreamBuilder<List<Question>>(
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
          controller: _myQuestionsController,
          itemCount: questions.length,
          itemBuilder: (context, index) {
            return QuestionWidget(question: questions[index]);
          },
        );
      },
    );
  }

  Widget _buildCommunityTab() {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: StreamBuilder<List<Question>>(
            stream: getCommunityQuestions(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No community questions found.'));
              }
              
              return StreamBuilder<UserModel>(
                stream: currentUser != null ? firebaseServices.streamUser(currentUser!.uid) : Stream.empty(),
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

                  return ListView.builder(
                    controller: _communityController,
                    itemCount: isLimited ? displayCount + 1 : displayCount,
                    itemBuilder: (context, index) {
                      if (isLimited && index == displayCount) {
                        return _buildUnlockCTA();
                      }
                      return QuestionWidget(question: questions[index]);
                    },
                  );
                }
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          TextField(
            controller: _keywordSearchController,
            decoration: InputDecoration(
              hintText: 'Search keywords...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (val) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _citySearchController,
                  decoration: InputDecoration(
                    hintText: 'Search city...',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (val) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _genderFilter,
                items: ['All', 'Male', 'Female', 'Other'].map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
                }).toList(),
                onChanged: (val) => setState(() => _genderFilter = val!),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              DropdownButton<String>(
                value: _filterType,
                items: ['All', 'Text', 'Image'].map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
                }).toList(),
                onChanged: (val) => setState(() => _filterType = val!),
              ),
              DropdownButton<String>(
                value: _sortBy,
                items: ['Newest', 'Popular'].map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
                }).toList(),
                onChanged: (val) => setState(() => _sortBy = val!),
              ),
            ],
          ),
        ],
      ),
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
          const Text("Unlock Full Community Feed", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            "Watch an ad or use credits to browse all community questions.",
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
                        setState(() {});
                      }
                    },
                  );
                },
                icon: const Icon(Icons.play_circle_fill),
                label: const Text("Watch Ad"),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white),
              ),
              OutlinedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreditsScreen())),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryGreen),
                child: const Text("Buy Credits"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Stream<List<Question>> getCommunityQuestions() {
    Query query = FirebaseFirestore.instance.collection('questions');
    
    if (_filterType == 'Text') {
      query = query.where('imageUrl', isEqualTo: '');
    } else if (_filterType == 'Image') {
      query = query.where('imageUrl', isNotEqualTo: '');
    }

    if (_genderFilter != 'All') {
      query = query.where('gender', isEqualTo: _genderFilter);
    }

    final citySearch = _citySearchController.text.trim();
    if (citySearch.isNotEmpty) {
      query = query.where('city', isEqualTo: citySearch);
    }

    if (_sortBy == 'Newest') {
      query = query.orderBy('timestamp', descending: true);
    } else {
      query = query.orderBy('thumbsUpCount', descending: true);
    }

    final keyword = _keywordSearchController.text.trim().toLowerCase();

    return query.limit(100).snapshots().map((snap) {
      final docs = snap.docs
          .map((doc) => Question.fromJson(doc.data() as Map<String, dynamic>))
          .where((q) => q.isPublic)
          .toList();
      
      if (keyword.isEmpty) return docs;
      
      return docs.where((q) => 
        q.question.toLowerCase().contains(keyword) || 
        q.answer.toLowerCase().contains(keyword)
      ).toList();
    });
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
