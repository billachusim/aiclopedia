import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:AiClopedia/providers/chats_provider.dart';
import 'package:AiClopedia/widgets/chat_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';

import '../constants/scrollable_page.dart';
import '../services/ad_state.dart';
import '../services/firebaseServices.dart';
import '../widgets/text_widget.dart';

// --- NEW: Change StatefulWidget to ScrollablePage ---
class ChatScreen extends ScrollablePage {
  const ChatScreen({super.key});

  @override
  // --- NEW: The State class now extends ScrollablePageState ---
  ScrollablePageState<ChatScreen> createState() => _ChatScreenState();
}

const int maxFailedLoadAttempts = 3;

// --- NEW: Extend from ScrollablePageState ---
class _ChatScreenState extends ScrollablePageState<ChatScreen> {
  final FirebaseServices firebaseServices = FirebaseServices();
  var currentUser = FirebaseAuth.instance.currentUser;
  bool _isTyping = false;
  late TextEditingController textEditingController;
  // This already exists, which is great.
  late ScrollController _listScrollController;
  late FocusNode focusNode;

  @override
  void initState() {
    _listScrollController = ScrollController();
    textEditingController = TextEditingController();
    focusNode = FocusNode();
    _createInterstitialAd();
    super.initState();
  }

  @override
  void dispose() {
    Future.delayed(const Duration(seconds: 2), _showInterstitialAd);
    _listScrollController.dispose();
    textEditingController.dispose();
    chatScreenTopBanner?.dispose();
    focusNode.dispose();
    super.dispose();
    _interstitialAd?.dispose();
  }

  // --- NEW: Implemented from ScrollablePageState ---
  @override
  void scrollToTop() {
    if (_listScrollController.hasClients) {
      _listScrollController.animateTo(
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
          ? "ca-app-pub-2404156870680632/5039939496"
          : "ca-app-pub-2404156870680632/4465224423",
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _interstitialLoadAttempts = 0;
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('Failed to load an interstitial ad: ${error.message}');
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
    if (_interstitialAd != null) {
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
  }

  BannerAd? chatScreenTopBanner;
  bool _bannerIsLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load banner only if it hasn't been loaded yet
    if (chatScreenTopBanner == null) {
      final adState = Provider.of<AdState>(context);
      adState.initialization.then((status) {
        if (!mounted) return;
        setState(() {
          chatScreenTopBanner = BannerAd(
              size: AdSize.banner,
              adUnitId: adState.chatScreenTopBannerAdUnitId,
              request: const AdRequest(),
              listener: BannerAdListener(
                onAdLoaded: (ad) {
                  setState(() {
                    _bannerIsLoaded = true;
                  });
                },
                onAdFailedToLoad: (ad, error) {
                  ad.dispose();
                },
              ))
            ..load();
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    // Use theme colors
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () {
        // Clear chat history
        if (chatProvider.getChatList.isNotEmpty) {
          chatProvider.chatList.clear();
        }
        // Allow pop to be handled by parent WillPopScope
        return Future.value(true);
      },
      child: Scaffold(
        // Use theme for AppBar
        appBar: AppBar(
          elevation: 2,
          automaticallyImplyLeading: true,
          title: Text("Ask AI Anything", style: theme.appBarTheme.titleTextStyle),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: theme.appBarTheme.iconTheme?.color), onPressed: () {
            Navigator.maybePop(context);
          },
          )
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (_bannerIsLoaded && chatScreenTopBanner != null)
                SizedBox(
                  height: chatScreenTopBanner!.size.height.toDouble(),
                  child: AdWidget(ad: chatScreenTopBanner!),
                )
              else
                SizedBox(
                  height: 50,
                  child: Center(
                      child: Text('Relevant ads only',
                          style: theme.textTheme.bodySmall)),
                ),
              Flexible(
                child: ListView.builder(
                    controller: _listScrollController,
                    itemCount: chatProvider.getChatList.length,
                    itemBuilder: (context, index) {
                      return ChatWidget(
                        msg: chatProvider.getChatList[index].msg,
                        chatIndex: chatProvider.getChatList[index].chatIndex,
                      );
                    }),
              ),
              if (_isTyping) ...[
                SpinKitThreeBounce(
                  color: theme.colorScheme.secondary, // Use accent color
                  size: 18,
                ),
              ],
              const SizedBox(
                height: 15,
              ),
              Material(
                // Use theme color for the input area background
                color: theme.colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          focusNode: focusNode,
                          // Use theme color for text
                          style: TextStyle(color: theme.colorScheme.onSurface),
                          controller: textEditingController,
                          onSubmitted: (value) async {
                            await _handleSendMessage(chatProvider);
                          },
                          decoration: InputDecoration.collapsed(
                              hintText: "Ask me anything. I mean anything!",
                              // Use theme color for hint text
                              hintStyle: TextStyle(color: theme.textTheme.bodySmall?.color)),
                        ),
                      ),
                      IconButton(
                          onPressed: () async {
                            await _handleSendMessage(chatProvider);
                          },
                          icon: Icon(
                            Icons.send,
                            // Use theme accent color
                            color: theme.colorScheme.secondary,
                          ))
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSendMessage(ChatProvider chatProvider) async {
    final question = textEditingController.text.trim();

    if (question.isEmpty) return;

    try {
      final user = await firebaseServices.getUserInfo();

      await firebaseServices.saveQuestion(user, question);
    } catch (e) {
      log("FIREBASE ERROR: $e");
    }

    await sendMessageFCT(chatProvider: chatProvider);
  }



  void scrollListToEND() {
    if (!_listScrollController.hasClients) return;

    Future.delayed(const Duration(milliseconds: 300), () {
      _listScrollController.animateTo(
        _listScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }


  Future<void> sendMessageFCT({required ChatProvider chatProvider}) async {
    if (_isTyping) return;

    final msg = textEditingController.text.trim();

    if (msg.isEmpty) return;

    setState(() {
      _isTyping = true;
      chatProvider.addUserMessage(msg: msg);
      textEditingController.clear();
      focusNode.unfocus();
    });

    scrollListToEND();

    try {
      await chatProvider.sendMessageAndGetAnswers(msg: msg);
    } catch (error) {
      log("CHAT ERROR: $error");
    } finally {
      if (mounted) {
        setState(() {
          _isTyping = false;
        });

        scrollListToEND();
      }
    }
  }

}
