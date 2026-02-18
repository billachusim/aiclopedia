import 'dart:io';
import 'package:AiClopedia/models/userModel.dart';
import 'package:AiClopedia/paywall_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../constants/scrollable_page.dart';
import '../services/ad_state.dart';
import '../services/firebaseServices.dart';
import '../services/image_engine.dart';

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
    Future.delayed(const Duration(seconds: 2), _showInterstitialAd);
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
      return ClipRRect(
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
          onUnlock: () {
            Navigator.of(context).pop();
          },
        );
      },
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

    setState(() {
      _isGenerating = true;
      isTyping = true;
      generatedImageUrl = '';
    });

    try {
      final user = await firebaseServices.getUserInfo();

      if (user.credits < creditCost) {
        _showPaywall(user);
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deducting $creditCost credits and generating image...')),
        );
      }

      await firebaseServices.updateUserCredits(user.userId, -creditCost);

      final prompt = textEditingController.text.trim();
      final url = await ImageEngine.instance.generate(prompt);

      if (mounted) {
        setState(() {
          generatedImageUrl = url;
        });
      }

      if (generatedImageUrl.isNotEmpty) {
        await firebaseServices.saveQuestion(user, prompt);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("An error occurred: ${e.toString()}")),
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

