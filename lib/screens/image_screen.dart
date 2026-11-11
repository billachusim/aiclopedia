import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:ai_clopedia/models/user_model.dart';
import 'package:ai_clopedia/paywall_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/scrollable_page.dart';
import '../services/ad_state.dart';
import '../services/firebase_services.dart';
import '../services/image_engine.dart';
import '../widgets/report_ai_content.dart';

class ImageScreen extends ScrollablePage {
  const ImageScreen({super.key});

  @override
  ScrollablePageState<ImageScreen> createState() => _ImageScreenState();
}

const int maxFailedLoadAttempts = 3;

class _ImageScreenState extends ScrollablePageState<ImageScreen> {
  String generatedImageUrl = '';
  final FirebaseServices firebaseServices = FirebaseServices();
  bool isTyping = false;
  bool _isGenerating = false;
  bool _hasGeneratedImage = false;
  bool _shouldSave = true;
  bool _isPublic = true;
  late TextEditingController textEditingController;
  late ScrollController _scrollController;
  late FocusNode focusNode;

  // --- UNCOMMENTED ---
  BannerAd? imageScreenTopBanner;

  @override
  void initState() {
    _scrollController = ScrollController();
    textEditingController = TextEditingController();
    focusNode = FocusNode();
    _createInterstitialAd();
    super.initState();
  }

  // --- UNCOMMENTED ---
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (imageScreenTopBanner == null) {
      final adState = Provider.of<AdState>(context);
      adState.initialization.then((status) {
        if (!mounted) return;
        setState(() {
          imageScreenTopBanner = BannerAd(
              size: AdSize.banner,
              adUnitId: adState.imageScreenTopBannerAdUnitId,
              request: const AdRequest(),
              listener: BannerAdListener(
                onAdFailedToLoad: (ad, error) => ad.dispose(),
              ))
            ..load();
        });
      });
    }
  }


  @override
  void dispose() {
    if (_hasGeneratedImage) {
      _showInterstitialAd();
    }
    _scrollController.dispose();
    textEditingController.dispose();
    focusNode.dispose();
    imageScreenTopBanner?.dispose();
    super.dispose();
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

  InterstitialAd? _interstitialAd;
  int _interstitialLoadAttempts = 0;

  void _createInterstitialAd() {
    InterstitialAd.load(
      adUnitId: Platform.isAndroid
          ? "ca-app-pub-2404156870680632/4330219400"
          : "ca-app-pub-2404156870680632/5986179917",
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        titleTextStyle: theme.appBarTheme.titleTextStyle,
        iconTheme: theme.appBarTheme.iconTheme,
        elevation: 2,
        title: const Text("Generate Any Image"),
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // --- MODIFIED: Anchored Banner Ad ---
            if (imageScreenTopBanner != null)
              SizedBox(
                height: imageScreenTopBanner!.size.height.toDouble(),
                child: AdWidget(ad: imageScreenTopBanner!),
              ),
            _buildSettingsStrip(),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withAlpha(128), // Adjusted opacity
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: theme.colorScheme.onSurface.withAlpha(25)),
                          ),
                          child: _buildImageContent(theme),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (isTyping) ...[
              SpinKitThreeBounce(
                color: theme.colorScheme.secondary,
                size: 18,
              ),
              if (textEditingController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "Generating image of: \"${textEditingController.text}\"",
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
            Material(
              color: theme.colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        focusNode: focusNode,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        controller: textEditingController,
                        onSubmitted: (value) async {
                          await _generateImageFct();
                        },
                        decoration: InputDecoration.collapsed(
                            hintText: "e.g., A fox in a spacesuit, digital art",
                            hintStyle: TextStyle(color: theme.textTheme.bodySmall?.color)),
                      ),
                    ),
                    if (_isGenerating)
                      const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      IconButton(
                          onPressed: _generateImageFct,
                          icon: Icon(
                            Icons.send,
                            color: theme.colorScheme.secondary,
                          ))
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageContent(ThemeData theme) {
    if (generatedImageUrl.isNotEmpty) {
      return Stack(
        children: [
          Positioned.fill(child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Image.network(
          generatedImageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.secondary,
                ));
          },
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Failed to load image.',
                    textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
              ),
            );
          },
        ),
      )),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: ReportAiContentButton(
                contentType: 'image',
                content: generatedImageUrl,
                prompt: textEditingController.text.trim(),
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    } else {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Type a prompt below to generate an image.',
            style: theme.textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
  }

  void _showPaywall(UserModel user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PaywallOverlay(
          user: user,
          cost: 20, // Match creditCost
          onUnlock: () {
            Navigator.of(context).pop();
          },
        );
      },
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
                "To provide creative content, AiClopedia uses third-party AI services (OpenAI). "
                "\n\nBy continuing, your prompt will be shared with these AI providers to generate an image. "
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
                if (context.mounted) Navigator.of(context).pop(true);
              },
              child: const Text("I Understand & Agree"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettingsStrip() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surface.withValues(alpha: 0.5),
      child: Row(
        children: [
          _buildToggle(
            icon: _shouldSave ? Icons.history : Icons.history_toggle_off,
            label: "Save",
            value: _shouldSave,
            onChanged: (val) => setState(() => _shouldSave = val),
          ),
          const SizedBox(width: 16),
          _buildToggle(
            icon: _isPublic ? Icons.public : Icons.public_off,
            label: _isPublic ? "Public" : "Private",
            value: _isPublic,
            onChanged: _shouldSave ? (val) => setState(() => _isPublic = val) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildToggle({
    required IconData icon,
    required String label,
    required bool value,
    required Function(bool)? onChanged,
  }) {
    final theme = Theme.of(context);
    final color = value ? theme.colorScheme.primary : Colors.grey;
    return InkWell(
      onTap: onChanged != null ? () => onChanged(!value) : null,
      child: Opacity(
        opacity: onChanged != null ? 1.0 : 0.4,
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Future<void> _generateImageFct() async {
    if (_isGenerating || textEditingController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please type a prompt to generate an image."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    focusNode.unfocus();
    const int creditCost = 20;

    try {
      final user = await firebaseServices.getUserInfo();

      if (!user.isPremium) {
        if (user.credits < creditCost) {
          _showPaywall(user);
          return;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      bool hasConsent = prefs.getBool('ai_consent') ?? false;

      if (!hasConsent) {
        bool? agreed = await _showAiConsentDialog();
        if (agreed != true) return;
      }

      setState(() {
        _isGenerating = true;
        isTyping = true;
        generatedImageUrl = '';
      });

      if (mounted && !user.isPremium) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generating image (Cost: $creditCost credits)...')),
        );
      }

      final prompt = textEditingController.text.trim();
      final url = await ImageEngine.instance.generate(prompt);

      if (!user.isPremium) {
        await firebaseServices.updateUserCredits(user.userId, -creditCost);
      }

      if (mounted) {
        setState(() {
          generatedImageUrl = url;
          _hasGeneratedImage = true;
        });
      }

      if (generatedImageUrl.isNotEmpty && _shouldSave) {
        if (prompt.length < 20) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Prompt too short (<20 chars). It won't be saved to history.")),
            );
          }
        } else {
          await firebaseServices.saveQuestion(user, prompt, isPublic: _isPublic);
          // Important: Update the saved question with the image URL
          final String? lastQuestionId = (await SharedPreferences.getInstance()).getString('questionId');
          if (lastQuestionId != null) {
            await firebaseServices.saveImageUrl(lastQuestionId, url);
          }
        }
      }
    } catch (e) {
      debugPrint('Image generation failed: $e');
      String message = "We couldn't create that image right now. Please try again in a moment.";
      if (e is FirebaseFunctionsException &&
          (e.code == 'failed-precondition' || e.code == 'invalid-argument') &&
          (e.message ?? '').isNotEmpty) {
        message = e.message!;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          isTyping = false;
        });
      }
    }
  }
}

