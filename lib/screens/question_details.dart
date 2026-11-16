import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:ai_clopedia/app_state.dart';
import 'package:ai_clopedia/services/hidden_posts_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:ai_clopedia/models/question_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../app_theme.dart';
import '../models/user_model.dart';
import '../paywall_overlay.dart';
import '../services/ad_state.dart';
import '../constants/store_links.dart';
import '../services/answer_engine.dart';
import '../services/answer_utils.dart';
import '../services/interstitial_gate.dart';
import '../services/review_service.dart';
import '../widgets/markdown_answer.dart';
import '../widgets/shimmer_lines.dart';
import 'chat_screen.dart';
import '../services/firebase_services.dart';
import '../services/image_engine.dart';
import '../widgets/report_ai_content.dart';

class QuestionDetails extends StatefulWidget {
  final Question question;

  const QuestionDetails({super.key, required this.question});

  @override
  State<QuestionDetails> createState() => _QuestionDetailsState();
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
  bool _answerFailed = false;
  bool _needsConsent = false;
  bool _isLoadingImage = false;
  List<Question> _related = [];
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
    final q = widget.question;
    _answer = AnswerUtils.isUsable(q.answer)
        ? q.answer
        : (AnswerEngine.instance.peek(q.questionId) ?? '');
    _imageUrl = AnswerUtils.isUsableImageUrl(q.imageUrl) ? q.imageUrl : '';
    _showImage = _imageUrl.isNotEmpty;

    if (_answer.isEmpty) {
      _getAnswer();
    } else {
      AnswerEngine.instance.remember(q.questionId, _answer);
    }
    _loadRelated();
  }


  @override
  void dispose() {
    if (InterstitialGate.instance.shouldShow()) {
      _showInterstitialAd();
    }
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
  /// Shows a saved answer first (no consent prompt needed to read one).
  /// Only asks for AI consent when a new answer has to be generated.
  Future<void> _getAnswer({bool userAsked = false}) async {
    if (_answer.isNotEmpty) return;

    setState(() {
      _isLoadingAnswer = true;
      _answerFailed = false;
      _needsConsent = false;
    });

    final q = widget.question;
    try {
      final cached = await AnswerEngine.instance
          .cached(questionId: q.questionId, existingAnswer: q.answer);
      if (cached != null) {
        if (!mounted) return;
        setState(() {
          _answer = cached;
          _isLoadingAnswer = false;
        });
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final hasConsent = prefs.getBool('ai_consent') ?? false;
      if (!hasConsent) {
        final agreed = await _showAiConsentDialog();
        if (agreed != true) {
          if (mounted) {
            setState(() {
              _isLoadingAnswer = false;
              _needsConsent = true;
            });
          }
          return;
        }
      }

      final resolved = await AnswerEngine.instance.resolve(
        questionId: q.questionId,
        question: q.question,
        existingAnswer: q.answer,
      );

      if (!mounted) return;
      setState(() {
        _answer = resolved;
        _isLoadingAnswer = false;
      });
      ReviewService.instance.recordGoodAnswer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingAnswer = false;
        _answerFailed = true;
      });
      if (userAsked) _showToast("Still couldn't load the answer. Please try again shortly.");
    }
  }

  /// Finds a few related public questions that already have answers.
  Future<void> _loadRelated() async {
    try {
      final words = _keywords(widget.question.question);
      if (words.isEmpty) return;
      final snap = await FirebaseFirestore.instance
          .collection('questions')
          .orderBy('timestamp', descending: true)
          .limit(150)
          .get();
      final scored = <MapEntry<Question, int>>[];
      for (final doc in snap.docs) {
        final q = Question.fromJson(doc.data());
        if (q.questionId == widget.question.questionId) continue;
        if (!q.isPublic || !q.hasUsableAnswer) continue;
        final overlap = _keywords(q.question).intersection(words).length;
        if (overlap > 0) scored.add(MapEntry(q, overlap));
      }
      scored.sort((a, b) => b.value.compareTo(a.value));
      if (!mounted) return;
      setState(() => _related = scored.take(3).map((e) => e.key).toList());
    } catch (_) {
      // Related questions are a nice-to-have.
    }
  }

  static const _stopWords = {
    'what', 'which', 'when', 'where', 'who', 'whom', 'whose', 'why', 'how',
    'the', 'and', 'for', 'are', 'was', 'were', 'is', 'can', 'could', 'would',
    'should', 'does', 'did', 'have', 'has', 'had', 'with', 'from', 'that',
    'this', 'there', 'their', 'about', 'into', 'your', 'you', 'please', 'tell',
    'explain', 'give', 'make', 'some', 'many', 'much', 'more', 'most', 'best',
    'will', 'they', 'them', 'than', 'then', 'also', 'just', 'like', 'between',
  };

  Set<String> _keywords(String text) {
    return text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.length > 3 && !_stopWords.contains(w))
        .toSet();
  }

  Future<void> _copyAnswer() async {
    await Clipboard.setData(ClipboardData(text: AnswerUtils.plainText(_answer)));
    _showToast("Answer copied.");
  }

  Future<void> _shareAnswer() async {
    final plain = AnswerUtils.plainText(_answer);
    final snippet = plain.length > 400 ? '${plain.substring(0, 400).trim()}…' : plain;
    final text = 'Q: ${widget.question.question}\n\n'
        '$snippet\n\n'
        'Get answers to anything with Ai Clopedia: ${StoreLinks.forThisPlatform}';
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      text: text,
      subject: widget.question.question,
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  }

  void _askFollowUp() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          initialPrompt: 'Follow-up on "${widget.question.question}": ',
          sendInitialPrompt: false,
        ),
      ),
    );
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
            _buildGlassCard(context, child: _buildAnswerBody(theme)),
            if (!_isLoadingAnswer && _answer.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: _copyAnswer,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy'),
                    ),
                    TextButton.icon(
                      onPressed: _shareAnswer,
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: const Text('Share'),
                    ),
                    const Spacer(),
                    ReportAiContentButton(
                      contentType: 'answer',
                      content: _answer,
                      prompt: question.question,
                      questionId: question.questionId,
                      color: theme.colorScheme.secondary,
                      withLabel: true,
                    ),
                  ],
                ),
              ),
            if (!_isLoadingAnswer && _answer.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _askFollowUp,
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('Ask a follow-up'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ),
            ],
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
              Align(
                alignment: Alignment.centerRight,
                child: ReportAiContentButton(
                  contentType: 'image',
                  content: _imageUrl,
                  prompt: question.question,
                  questionId: question.questionId,
                  color: theme.colorScheme.secondary,
                  withLabel: true,
                ),
              ),
            ],
            if (_related.isNotEmpty) ...[
              const SizedBox(height: 32),
              Text('RELATED QUESTIONS', style: theme.textTheme.labelMedium?.copyWith(letterSpacing: 1.2, color: theme.colorScheme.secondary)),
              const SizedBox(height: 8),
              _buildGlassCard(
                context,
                child: Column(
                  children: [
                    for (final r in _related)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(r.question, maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => QuestionDetails(question: r)),
                        ),
                      ),
                  ],
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
  Widget _buildAnswerBody(ThemeData theme) {
    if (_isLoadingAnswer) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerLines(lines: 4),
          const SizedBox(height: 4),
          Text('Getting the answer…', style: theme.textTheme.bodySmall),
        ],
      );
    }
    if (_answer.isNotEmpty) {
      return MarkdownAnswer(data: _answer);
    }
    final message = _needsConsent
        ? 'To see an AI answer for this question, please allow AiClopedia to use its AI service.'
        : _answerFailed
            ? "We couldn't load this answer right now. Check your connection and try again."
            : 'No answer yet.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _getAnswer(userAsked: true),
          icon: const Icon(Icons.refresh_rounded),
          label: Text(_needsConsent ? 'Get the answer' : 'Try again'),
        ),
      ],
    );
  }

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
          _buildMetadataRow(theme, icon: Icons.location_on_outlined, label: 'Location', value: question.city),
          const SizedBox(height: 8),
          if (question.gender.isNotEmpty && question.gender != 'Not specified') ...[
            _buildMetadataRow(theme, icon: Icons.person_outline, label: 'Gender', value: question.gender),
            const SizedBox(height: 8),
          ],
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
