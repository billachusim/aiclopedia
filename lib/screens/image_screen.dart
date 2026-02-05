import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../constants/scrollable_page.dart';
import '../services/ad_state.dart';
import '../services/firebaseServices.dart';

// --- NEW: Change StatefulWidget to ScrollablePage ---
class ImageScreen extends ScrollablePage {
  const ImageScreen({super.key});

  @override
  // --- NEW: The State class now extends ScrollablePageState ---
  ScrollablePageState<ImageScreen> createState() => _ImageScreenState();
}

const int maxFailedLoadAttempts = 3;

// --- NEW: Extend from ScrollablePageState ---
class _ImageScreenState extends ScrollablePageState<ImageScreen> {
  String generatedImageUrl = '';
  final FirebaseServices firebaseServices = FirebaseServices();
  bool isTyping = false;
  late TextEditingController textEditingController;
  // --- This will now be used with a SingleChildScrollView ---
  late ScrollController _scrollController;
  late FocusNode focusNode;

  // IMPORTANT: Storing API keys in client-side code is insecure.
  // Use a secure backend or environment variables for production apps.
  static const String openAIApiKey = 'YOUR_OPENAI_API_KEY';

  @override
  void initState() {
    // --- Controller name changed for clarity ---
    _scrollController = ScrollController();
    textEditingController = TextEditingController();
    focusNode = FocusNode();
    _createInterstitialAd();
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    textEditingController.dispose();
    focusNode.dispose();
    _interstitialAd?.dispose();
    imageScreenTopBanner?.dispose();
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


  InterstitialAd? _interstitialAd;
  int _interstitialLoadAttempts = 0;

  void _createInterstitialAd() {
    InterstitialAd.load(
      adUnitId: Platform.isAndroid
          ? "ca-app-pub-2404156870680632/9546372208"
          : "ca-app-pub-2404156870680632/5347272743",
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

  BannerAd? imageScreenTopBanner;

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        // Use theme colors
        backgroundColor: theme.appBarTheme.backgroundColor,
        titleTextStyle: theme.appBarTheme.titleTextStyle,
        iconTheme: theme.appBarTheme.iconTheme,
        elevation: 2,
        title: const Text("Generate Any Image"),
        // Use a standard back button that pops the screen
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (imageScreenTopBanner != null)
              SizedBox(
                height: imageScreenTopBanner!.size.height.toDouble(),
                child: AdWidget(ad: imageScreenTopBanner!),
              )
            else
              SizedBox(
                height: 50,
                child: Center(
                    child: Text('Relevant ads only',
                        style: theme.textTheme.bodySmall)),
              ),
            Expanded(
              // --- NEW: Wrap content in a SingleChildScrollView ---
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // --- NEW: Improved UI for image display area ---
                      AspectRatio(
                        aspectRatio: 1, // Keep it square
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.1)),
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
            // --- NEW: Theme-aware input area ---
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
                            hintStyle:
                            TextStyle(color: theme.textTheme.bodySmall?.color)),
                      ),
                    ),
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

  // --- NEW: Helper widget to build image content area ---
  Widget _buildImageContent(ThemeData theme) {
    if (generatedImageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(15), // Match container's radius
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


  Future<void> _generateImageFct() async {
    if (textEditingController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please type a prompt to generate an image."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Unfocus to hide keyboard
    focusNode.unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Creating image; an ad might appear later.')),
    );

    final prompt = textEditingController.text.trim();
    final user = await firebaseServices.getUserInfo();

    setState(() {
      isTyping = true;
      generatedImageUrl = ''; // Clear previous image
    });

    await generateImage(prompt);
    // Only save the question if an image was generated successfully
    if (generatedImageUrl.isNotEmpty) {
      await firebaseServices.saveQuestion(user, prompt,);
    }

    if (mounted) {
      setState(() {
        isTyping = false;
      });
    }

    Future.delayed(const Duration(seconds: 4), _showInterstitialAd);
  }

  Future<void> generateImage(String userInput) async {
    if (openAIApiKey == 'YOUR_OPENAI_API_KEY' || openAIApiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API Key is not configured.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final url = Uri.parse('https://api.openai.com/v1/images/generations');
    final headers = {
      'Authorization': 'Bearer $openAIApiKey',
      'Content-Type': 'application/json'
    };
    final body = {'model': 'dall-e-2', 'prompt': userInput, 'n': 1, 'size': '512x512'};

    try {
      final response = await http.post(url, headers: headers, body: jsonEncode(body));
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data['data'] != null && data['data'].isNotEmpty) {
          if (mounted) {
            setState(() {
              generatedImageUrl = data['data'][0]['url'];
            });
          }
        }
      } else {
        if (kDebugMode) {
          print('Error generating image: $data');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${data['error']['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch(e) {
      if (kDebugMode) {
        print('Error making HTTP request: $e');
      }
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An error occurred. Check your network connection.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
