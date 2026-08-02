import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:ai_clopedia/providers/chats_provider.dart';
import 'package:ai_clopedia/widgets/chat_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/scrollable_page.dart';
import '../models/user_model.dart';
import '../paywall_overlay.dart';
import '../services/ad_state.dart';
import '../services/firebase_services.dart';

class ChatScreen extends ScrollablePage {
  final String? initialPrompt;
  const ChatScreen({super.key, this.initialPrompt});

  @override
  ScrollablePageState<ChatScreen> createState() => _ChatScreenState();
}

const int maxFailedLoadAttempts = 3;

class _ChatScreenState extends ScrollablePageState<ChatScreen> {
  final FirebaseServices firebaseServices = FirebaseServices();
  var currentUser = FirebaseAuth.instance.currentUser;
  bool _isTyping = false;
  bool _isSending = false;
  bool _hasPerformedSearch = false;
  bool _shouldSave = true;
  bool _isPublic = true;
  late TextEditingController textEditingController;
  late ScrollController _listScrollController;
  late FocusNode focusNode;

  // --- UNCOMMENTED ---
  BannerAd? chatScreenTopBanner;

  @override
  void initState() {
    _listScrollController = ScrollController();
    textEditingController = TextEditingController();
    if (widget.initialPrompt != null) {
      textEditingController.text = widget.initialPrompt!;
    }
    focusNode = FocusNode();
    _createInterstitialAd();
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAiConsent();
      if (widget.initialPrompt != null) {
        _handleInitialPrompt();
      }
    });
  }

  Future<void> _handleInitialPrompt() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    await _handleSendMessage(chatProvider);
  }

  Future<void> _checkAiConsent() async {
    final prefs = await SharedPreferences.getInstance();
    bool hasConsent = prefs.getBool('ai_consent') ?? false;
    if (!hasConsent && mounted) {
      _showAiConsentDialog();
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
            children: [
              const Text(
                "To provide intelligent responses, AiClopedia uses third-party AI services (including Google Gemini). "
                "\n\nBy continuing, your messages will be shared with these AI providers to generate a response. "
                "Please do not share sensitive personal information.",
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 10),
              const Text(
                "For more details, please review our Privacy Policy.",
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back from ChatScreen
              },
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

                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text("I Understand & Agree"),
            ),
          ],
        );
      },
    );
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
    if (_hasPerformedSearch) {
      _showInterstitialAd();
    }
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
          log('Failed to load an interstitial ad: ${error.message}');
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

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) {
          if (chatProvider.getChatList.isNotEmpty) {
            chatProvider.chatList.clear();
          }
        }
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
              _buildSettingsStrip(),
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

  Future<void> _handleSendMessage(ChatProvider chatProvider) async {
    if (_isSending || textEditingController.text.trim().isEmpty) return;

    setState(() {
      _isSending = true;
    });

    final question = textEditingController.text.trim();
    const int creditCost = 5;

    try {
      final user = await firebaseServices.getUserInfo();

      if (!user.isPremium && user.credits < creditCost) {
        if (!mounted) return;
        _showPaywall(user);
        return;
      }

      if (_shouldSave) {
        if (question.length < 20) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Question too short (<20 chars). It won't be saved to history.")),
            );
          }
        } else {
          await firebaseServices.saveQuestion(user, question, isPublic: _isPublic);
        }
      }
      
      await sendMessageFCT(chatProvider: chatProvider, user: user, creditCost: creditCost);
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
          cost: 5, // Match creditCost
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

  Future<void> sendMessageFCT({required ChatProvider chatProvider, UserModel? user, int? creditCost}) async {
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
      _hasPerformedSearch = true;
      
      // Success! Now deduct credits if not premium
      if (user != null && !user.isPremium && creditCost != null) {
        await firebaseServices.updateUserCredits(user.userId, -creditCost);
      }
    } catch (error) {
      log("CHAT ERROR: $error");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to get answer. Please try again.")),
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
