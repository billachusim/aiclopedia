import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:AiClopedia/app_state.dart';
import 'package:AiClopedia/services/hidden_posts_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:AiClopedia/models/questionModel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../models/userModel.dart';
import '../paywall_overlay.dart';
import '../services/ad_state.dart';
import '../services/answer_engine.dart';
import '../services/firebaseServices.dart';
import '../services/image_engine.dart';

class QuestionDetails extends StatefulWidget {
  final Question question;

  const QuestionDetails({Key? key, required this.question}) : super(key: key);

  @override
  _QuestionDetailsState createState() => _QuestionDetailsState();
}

const int maxFailedLoadAttempts = 3;

class _QuestionDetailsState extends State<QuestionDetails> {
  // Services
  final FirebaseServices firebaseServices = FirebaseServices();
  final HiddenPostsService _hiddenPostsService = HiddenPostsService();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // State variables
  late String _answer;
  late String _imageUrl;
  bool _isLoadingAnswer = false;
  bool _isLoadingImage = false;
  bool _showImage = false;

  InterstitialAd? _interstitialAd;
  int _interstitialLoadAttempts = 0;
  BannerAd? questionDetailsTopBanner;
  BannerAd? questionDetailsBottomBanner;

  @override
  void initState() {
    super.initState();
    _createInterstitialAd();
    _initializeContent();
  }

  void _initializeContent() {
    _answer = widget.question.answer;
    _imageUrl = widget.question.imageUrl;
    _showImage = _imageUrl.isNotEmpty;

    if (_answer.isEmpty) {
      _getAnswer();
    }
  }


  @override
  void dispose() {
    _showInterstitialAd();
    questionDetailsTopBanner?.dispose();
    questionDetailsBottomBanner?.dispose();
    super.dispose();
    _interstitialAd?.dispose();
  }

  // --- AD METHODS ---
  void _createInterstitialAd() {
    InterstitialAd.load(
      adUnitId: Platform.isAndroid
          ? "ca-app-pub-2404156870680632/6736890895"
          : "ca-app-pub-2404156870680632/6899816077",
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
    _loadBanners();
  }

  void _loadBanners() {
    if (questionDetailsTopBanner != null) return;

    final adState = Provider.of<AdState>(context, listen: false);
    adState.initialization.then((status) {
      if (!mounted) return;
      setState(() {
        questionDetailsTopBanner = BannerAd(
          size: AdSize.banner,
          adUnitId: adState.questionDetailsTopBanner,
          request: const AdRequest(),
          listener: BannerAdListener(onAdFailedToLoad: (ad, error) => ad.dispose()),
        )..load();

        questionDetailsBottomBanner = BannerAd(
          size: AdSize.banner,
          adUnitId: adState.questionDetailsBottomBanner,
          request: const AdRequest(),
          listener: BannerAdListener(onAdFailedToLoad: (ad, error) => ad.dispose()),
        )..load();
      });
    });
  }

  // --- START: MODERATION ACTION HANDLERS ---
  Future<void> _removePostFromFeed(String questionId) async {
    await _hiddenPostsService.hidePost(questionId);
    if (mounted) {
      _showToast("This post has been removed from your feed.");
      App.refreshFeed.add(true);
      Navigator.of(context).pop(); // Close the details page
    }
  }

  Future<void> _reportPostAndOwner(String questionId, String ownerId) async {
    final success = await firebaseServices.reportQuestion(questionId, ownerId);
    if (success) {
      await _hiddenPostsService.hidePost(questionId);
      if (mounted) {
        _showToast("This post has been reported and will be removed from your feed.");
        App.refreshFeed.add(true);
        Navigator.of(context).pop(); // Close the details page
      }
    } else {
      if (mounted) _showToast("Failed to report post. Please try again.");
    }
  }

  Future<void> _blockUser(String userIdToBlock) async {
    final success = await firebaseServices.blockUser(userIdToBlock);
    if (success && mounted) {
      _showToast("This user has been blocked. Their content will no longer be visible.");
      App.refreshFeed.add(true);
      Navigator.of(context).pop(); // Close the details page
    } else {
      if (mounted) _showToast("Failed to block user. Please try again.");
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  // --- END: MODERATION ACTION HANDLERS ---


  // --- CONTENT GENERATION METHODS ---
  Future<void> _getAnswer() async {
    if (_answer.isNotEmpty) return;

    setState(() => _isLoadingAnswer = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      bool hasConsent = prefs.getBool('ai_consent') ?? false;

      if (!hasConsent) {
        bool? agreed = await _showAiConsentDialog();
        if (agreed != true) {
          if (mounted) setState(() => _isLoadingAnswer = false);
          return;
        }
      }

      final resolved = await AnswerEngine.instance.resolve(
        questionId: widget.question.questionId,
        question: widget.question.question,
        existingAnswer: widget.question.answer,
      );

      if (!mounted) return;

      setState(() {
        _answer = resolved;
        _isLoadingAnswer = false;
      });

    } catch (e) {
      if (mounted) setState(() => _isLoadingAnswer = false);
      _showToast("Failed to load answer.");
    }
  }

  Future<bool?> _showAiConsentDialog() {
    return showDialog<bool>(
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
                "To generate answers and images, AiClopedia uses third-party AI services (including Google Gemini and OpenAI). "
                "\n\nBy continuing, this question will be shared with these AI providers to generate a response. "
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
              onPressed: () => Navigator.of(context).pop(false),
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

                if (context.mounted) Navigator.of(context).pop(true);
              },
              child: const Text("I Understand & Agree"),
            ),
          ],
        );
      },
    );
  }


  Future<void> _handleImageGeneration() async {

    // already have one → just toggle
    if (_imageUrl.isNotEmpty) {
      setState(() => _showImage = !_showImage);
      return;
    }

    setState(() => _isLoadingImage = true);

    try {
      final user = await firebaseServices.getUserInfo();
      const int imageCreditCost = 20; // Images are more expensive

      if (!user.isPremium) {
        if (user.credits < imageCreditCost) {
          _showPaywall(user);
          if (mounted) setState(() => _isLoadingImage = false);
          return;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      bool hasConsent = prefs.getBool('ai_consent') ?? false;

      if (!hasConsent) {
        bool? agreed = await _showAiConsentDialog();
        if (agreed != true) {
          if (mounted) setState(() => _isLoadingImage = false);
          return;
        }
      }

      final url =
      await ImageEngine.instance.generate(widget.question.question);

      if (!mounted) return;

      if (!user.isPremium) {
        await firebaseServices.updateUserCredits(user.userId, -imageCreditCost);
      }

      setState(() {
        _imageUrl = url;
        _showImage = true;
      });

      await firebaseServices.saveImageUrl(
        widget.question.questionId,
        url,
      );

    } catch (e) {
      if (mounted) _showToast("Image generation failed.");
    } finally {
      if (mounted) {
        setState(() => _isLoadingImage = false);
      }
    }
  }

  void _showPaywall(UserModel user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PaywallOverlay(
          user: user,
          cost: 20, // Match imageCreditCost
          onUnlock: () {
            Navigator.of(context).pop();
          },
        );
      },
    );
  }




  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final question = widget.question;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Question Details'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        titleTextStyle: theme.appBarTheme.titleTextStyle,
        iconTheme: theme.appBarTheme.iconTheme,
        actions: [
          // --- ADDED: MODERATION POPUP BUTTON (HIDDEN FROM OWNER) ---
          if (widget.question.userId != currentUser?.uid)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (questionDetailsTopBanner != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: SizedBox(
                  height: questionDetailsTopBanner!.size.height.toDouble(),
                  child: AdWidget(ad: questionDetailsTopBanner!),
                ),
              ),
            _buildGlassCard(context, child: Text(question.question, style: theme.textTheme.titleLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.bold))),
            const SizedBox(height: 24.0),
            Text('AI ANSWER', style: theme.textTheme.labelMedium?.copyWith(letterSpacing: 1.2, color: theme.colorScheme.secondary)),
            const SizedBox(height: 8.0),
            _buildGlassCard(
              context,
              child: _isLoadingAnswer
                  ? _buildLoadingIndicator(theme, text: 'Thinking...')
                  : SelectableLinkify(
                text: _answer,
                onOpen: (link) async {
                  final Uri url = Uri.parse(link.url);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
                linkStyle: TextStyle(color: theme.colorScheme.secondary),
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.6, fontSize: 16),
              ),
            ),
            const SizedBox(height: 32.0),
            if (_showImage || _imageUrl.isEmpty)
              Center(
                child: Column(
                  children: [
                    if (_imageUrl.isEmpty)
                      Text('Visualize this question with AI', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: _isLoadingImage
                          ? const SizedBox.shrink()
                          : Icon(_showImage && _imageUrl.isNotEmpty
                              ? Icons.visibility_off_outlined
                              : Icons.auto_awesome),
                      label: _isLoadingImage
                          ? const SpinKitThreeBounce(color: Colors.white, size: 18)
                          : Text(_imageUrl.isNotEmpty
                              ? (_showImage ? 'Hide Illustration' : 'Show Illustration')
                              : 'Generate AI Illustration'),
                      onPressed: _isLoadingImage ? null : _handleImageGeneration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentPink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 4,
                      ),
                    ),
                  ],
                ),
              ),
            if (_showImage && _imageUrl.isNotEmpty) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: _imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _buildLoadingIndicator(theme),
                  errorWidget: (_, __, ___) => const Text('Could not load image.'),
                ),
              ),
            ],
            const Divider(height: 48),
            _buildMetadata(context, question),
            if (questionDetailsBottomBanner != null)
              Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: SizedBox(
                  height: questionDetailsBottomBanner!.size.height.toDouble(),
                  child: AdWidget(ad: questionDetailsBottomBanner!),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---
  Widget _buildGlassCard(BuildContext context, {required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: AppTheme.glassmorphismColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(ThemeData theme, {String? text}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SpinKitThreeBounce(color: theme.colorScheme.secondary, size: 24),
            if (text != null) ...[
              const SizedBox(height: 16),
              Text(text, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetadata(BuildContext context, Question question) {
    final theme = Theme.of(context);
    return _buildGlassCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Details', style: theme.textTheme.titleMedium),
          const Divider(height: 24),
          _buildMetadataRow(theme, icon: Icons.person_outline, label: 'Asked by', value: question.nickname),
          const SizedBox(height: 8),
          _buildMetadataRow(theme, icon: Icons.school_outlined, label: 'From', value: question.nameOfSchool),
          const SizedBox(height: 8),
          _buildMetadataRow(theme, icon: Icons.access_time, label: 'Time', value: timeago.format(question.timestamp)),
          const SizedBox(height: 8),
          _buildMetadataRow(
            theme,
            icon: Icons.star_outline,
            label: 'Status',
            value: question.isFeatured ? 'Featured' : 'Standard',
            valueColor: question.isFeatured ? AppTheme.primaryGreen : null,
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(ThemeData theme, {required IconData icon, required String label, required String value, Color? valueColor}) {
    final secondaryTextColor = theme.colorScheme.onSurface.withValues(alpha: 0.7);
    return Row(
      children: [
        Icon(icon, color: secondaryTextColor, size: 18),
        const SizedBox(width: 12),
        Text('$label:', style: TextStyle(color: secondaryTextColor)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: valueColor ?? theme.colorScheme.onSurface),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
