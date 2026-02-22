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
import '../models/userModel.dart';
import '../paywall_overlay.dart';
import '../services/ad_state.dart';
import '../services/firebaseServices.dart';

class ChatScreen extends ScrollablePage {
  const ChatScreen({super.key});

  @override
  ScrollablePageState<ChatScreen> createState() => _ChatScreenState();
}

const int maxFailedLoadAttempts = 3;

class _ChatScreenState extends ScrollablePageState<ChatScreen> {
  final FirebaseServices firebaseServices = FirebaseServices();
  var currentUser = FirebaseAuth.instance.currentUser;
  bool _isTyping = false;
  bool _isSending = false;
  late TextEditingController textEditingController;
  late ScrollController _listScrollController;
  late FocusNode focusNode;

  // --- UNCOMMENTED ---
  BannerAd? chatScreenTopBanner;

  @override
  void initState() {
    _listScrollController = ScrollController();
    textEditingController = TextEditingController();
    focusNode = FocusNode();
    _createInterstitialAd();
    super.initState();
  }

  // --- UNCOMMENTED and CORRECTED ---
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
  void dispose() {
    Future.delayed(const Duration(seconds: 2), _showInterstitialAd);
    _listScrollController.dispose();
    textEditingController.dispose();
    focusNode.dispose();
    chatScreenTopBanner?.dispose();
    super.dispose();
    _interstitialAd?.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () {
        if (chatProvider.getChatList.isNotEmpty) {
          chatProvider.chatList.clear();
        }
        return Future.value(true);
      },
      child: Scaffold(
        appBar: AppBar(
            elevation: 2,
            automaticallyImplyLeading: true,
            title: Text("Ask AI Anything", style: theme.appBarTheme.titleTextStyle),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: theme.appBarTheme.iconTheme?.color),
              onPressed: () {
                Navigator.maybePop(context);
              },
            )),
        body: SafeArea(
          child: Column(
            children: [
              // --- MODIFIED: Anchored Banner Ad ---
              if (chatScreenTopBanner != null)
                SizedBox(
                  height: chatScreenTopBanner!.size.height.toDouble(),
                  child: AdWidget(ad: chatScreenTopBanner!),
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
                  color: theme.colorScheme.secondary,
                  size: 18,
                ),
              ],
              const SizedBox(
                height: 15,
              ),
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
                            await _handleSendMessage(chatProvider);
                          },
                          decoration: InputDecoration.collapsed(
                              hintText: "Ask me anything. I mean anything!",
                              hintStyle: TextStyle(color: theme.textTheme.bodySmall?.color)),
                        ),
                      ),
                      if (_isSending)
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
                            onPressed: () async {
                              await _handleSendMessage(chatProvider);
                            },
                            icon: Icon(
                              Icons.send,
                              color: theme.colorScheme.secondary,
                            )),
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
    if (_isSending || textEditingController.text.trim().isEmpty) return;

    setState(() {
      _isSending = true;
    });

    final question = textEditingController.text.trim();
    const int creditCost = 5;

    try {
      final user = await firebaseServices.getUserInfo();

      if (user.credits < creditCost) {
        _showPaywall(user);
        return;
      }

      await firebaseServices.updateUserCredits(user.userId, -creditCost);
      await firebaseServices.saveQuestion(user, question);
      await sendMessageFCT(chatProvider: chatProvider);
    } catch (e) {
      log("FIREBASE ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("An error occurred: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
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
          onUnlock: () {
            Navigator.of(context).pop();
          },
        );
      },
    );
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
    if (textEditingController.text.trim().isEmpty) return;

    final msg = textEditingController.text.trim();

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to get answer. Please try again.")),
      );
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
