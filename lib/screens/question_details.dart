import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:ui';
import 'package:AiClopedia/app_state.dart';
import 'package:AiClopedia/services/hidden_posts_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:AiClopedia/models/questionModel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../services/ad_state.dart';
import '../services/firebaseServices.dart';

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
    _interstitialAd?.dispose();
    questionDetailsTopBanner?.dispose();
    questionDetailsBottomBanner?.dispose();
    super.dispose();
  }

  // --- AD METHODS ---
  void _createInterstitialAd() {
    InterstitialAd.load(
      adUnitId: Platform.isAndroid
          ? "ca-app-pub-2404156870680632/4294045529"
          : "ca-app-pub-2404156870680632/4034191073",
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
      await Future.delayed(const Duration(seconds: 2));
      final fakeResponse =
          "This is a generated answer for '${widget.question.question}'. Caching ensures this is only generated once.";

      if (mounted) {
        setState(() {
          _answer = fakeResponse;
          _isLoadingAnswer = false;
        });
        firebaseServices.saveAnswer(widget.question.questionId, _answer);
      }
    } catch (error) {
      if (mounted) setState(() => _isLoadingAnswer = false);
      log("Error occurred while getting answer: $error");
      _showToast('Failed to get answer.');
    }
  }

  Future<void> _handleImageGeneration() async {
    if (_imageUrl.isNotEmpty) {
      setState(() => _showImage = !_showImage);
      return;
    }
    setState(() => _isLoadingImage = true);
    _showToast('Creating image; an ad might appear later.');

    try {
      final generatedUrl = await generateImage(widget.question.question);
      if (generatedUrl != null && mounted) {
        setState(() {
          _imageUrl = generatedUrl;
          _showImage = true;
        });
        firebaseServices.saveImageUrl(widget.question.questionId, _imageUrl);
      }
    } catch (e) {
      log("Error in handleImageGeneration: $e");
    } finally {
      if (mounted) setState(() => _isLoadingImage = false);
      Future.delayed(const Duration(seconds: 4), _showInterstitialAd);
    }
  }

  Future<String?> generateImage(String userInput) async {
    await Future.delayed(const Duration(seconds: 3));
    return 'https://picsum.photos/512'; // Placeholder image
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
            _buildGlassCard(context, child: Text(question.question, style: theme.textTheme.titleLarge?.copyWith(fontSize: 20))),
            const SizedBox(height: 16.0),
            _buildGlassCard(
              context,
              child: _isLoadingAnswer
                  ? _buildLoadingIndicator(theme, text: 'Generating Answer...')
                  : SelectableLinkify(
                text: _answer,
                onOpen: (link) async {
                  final Uri url = Uri.parse(link.url);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
                linkStyle: TextStyle(color: theme.colorScheme.secondary),
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
            ),
            const SizedBox(height: 24.0),
            Center(
              child: ElevatedButton.icon(
                icon: _isLoadingImage
                    ? const SizedBox.shrink()
                    : Icon(_showImage && _imageUrl.isNotEmpty ? Icons.visibility_off_outlined : Icons.image_outlined),
                label: _isLoadingImage
                    ? const SpinKitThreeBounce(color: Colors.white, size: 18)
                    : Text(_imageUrl.isNotEmpty ? (_showImage ? 'Hide Image' : 'Show Image') : 'Generate Image'),
                onPressed: _isLoadingImage ? null : _handleImageGeneration,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentPink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_showImage && _imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  _imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) => progress == null ? child : _buildLoadingIndicator(theme),
                  errorBuilder: (context, error, stack) => _buildGlassCard(context, child: const Text('Could not load image.')),
                ),
              ),
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
            border: Border.all(color: Colors.white.withOpacity(0.2)),
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
    final secondaryTextColor = theme.colorScheme.onSurface.withOpacity(0.7);
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
