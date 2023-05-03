import 'dart:async';
import 'dart:developer';
import 'package:AiClopedia/widgets/bottom_nav.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:AiClopedia/constants/constants.dart';
import 'package:AiClopedia/providers/chats_provider.dart';
import 'package:AiClopedia/widgets/chat_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';

import '../providers/models_provider.dart';
import '../services/ad_state.dart';
import '../services/firebaseServices.dart';
import '../widgets/text_widget.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseServices firebaseServices = FirebaseServices();
  var currentUser = FirebaseAuth.instance.currentUser;
  bool _isTyping = false;

  late TextEditingController textEditingController;
  late ScrollController _listScrollController;
  late FocusNode focusNode;
  @override
  void initState() {
    _listScrollController = ScrollController();
    textEditingController = TextEditingController();
    focusNode = FocusNode();
    super.initState();
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    textEditingController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  BannerAd? chatScreenTopBanner;
  bool _bannerIsLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final adState = Provider.of<AdState>(context);

    // Implement a top location banner ad unit.
    adState.initialization.then((status) {
      setState(() {
        chatScreenTopBanner = BannerAd(
            size: AdSize.banner,
            adUnitId: adState.chatScreenTopBannerAdUnitId,
            request: const AdRequest(),
            listener: BannerAdListener(
              onAdFailedToLoad: (ad, error) {
                ad.dispose();
              },
            )
        )
          ..load();
        _bannerIsLoaded = true;
      });
    });
  }

  // List<ChatModel> chatList = [];
  @override
  Widget build(BuildContext context) {
    final modelsProvider = Provider.of<ModelsProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    return WillPopScope(
      onWillPop: (){
        chatProvider.chatList.clear();
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => BottomNavBar()),
        );
        return Future.value(false);
      },
      child: Scaffold(
        appBar: AppBar(
          elevation: 2,
          automaticallyImplyLeading: true,
          title: const Text("Ask AI Anything"),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Top ad unit is here
              if (chatScreenTopBanner != null && _bannerIsLoaded)
                SizedBox(
                  height: 60,
                  child: AdWidget(ad: chatScreenTopBanner!),
                )
              else
                SizedBox(height: 70, child: Text('Relevant ads only', style: TextStyle(color: Colors.white),),),

              Flexible(
                child: ListView.builder(
                    controller: _listScrollController,
                    itemCount: chatProvider.getChatList.length, //chatList.length,
                    itemBuilder: (context, index) {
                      return ChatWidget(
                        msg: chatProvider
                            .getChatList[index].msg, // chatList[index].msg,
                        chatIndex: chatProvider.getChatList[index]
                            .chatIndex, //chatList[index].chatIndex,
                      );
                    }),
              ),
              if (_isTyping) ...[
                const SpinKitThreeBounce(
                  color: Colors.white,
                  size: 18,
                ),
              ],
              const SizedBox(
                height: 15,
              ),
              Material(
                color: cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          focusNode: focusNode,
                          style: const TextStyle(color: Colors.white),
                          controller: textEditingController,
                          onSubmitted: (value) async {
                            await sendMessageFCT(
                                modelsProvider: modelsProvider,
                                chatProvider: chatProvider);
                            final question = textEditingController.text.trim();
                            final user = await firebaseServices.getUserInfo();
                            if (question.isNotEmpty) {
                              await firebaseServices.saveQuestion(user, question);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Question saved'),
                                ),
                              );
                            }
                          },
                          decoration: const InputDecoration.collapsed(
                              hintText: "Ask me anything. I mean anything!",
                              hintStyle: TextStyle(color: Colors.grey)),
                        ),
                      ),
                      IconButton(
                          onPressed: () async {
                            final question = textEditingController.text.trim();
                            final user = await firebaseServices.getUserInfo();
                            if (question.isNotEmpty) {
                              await firebaseServices.saveQuestion(user, question);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Question saved'),
                                ),
                              );
                            }

                            await sendMessageFCT(
                                modelsProvider: modelsProvider,
                                chatProvider: chatProvider);
                          },
                          icon: const Icon(
                            Icons.send,
                            color: Colors.white,
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

  void scrollListToEND() {
    _listScrollController.animateTo(
        _listScrollController.position.maxScrollExtent,
        duration: const Duration(seconds: 2),
        curve: Curves.easeOut);
  }

  Future<void> sendMessageFCT(
      {required ModelsProvider modelsProvider,
      required ChatProvider chatProvider}) async {
    if (_isTyping) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TextWidget(
            label: "You cant send multiple messages at a time",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (textEditingController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TextWidget(
            label: "Please type a message",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    try {
      String msg = textEditingController.text;
      setState(() {
        _isTyping = true;
        // chatList.add(ChatModel(msg: textEditingController.text, chatIndex: 0));
        chatProvider.addUserMessage(msg: msg);
        textEditingController.clear();
        focusNode.unfocus();
      });
      await chatProvider.sendMessageAndGetAnswers(
          msg: msg, chosenModelId: modelsProvider.getCurrentModel);
      setState(() {});
    } catch (error) {
      log("error $error");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: TextWidget(
          label: error.toString(),
        ),
        backgroundColor: Colors.red,
      ));
    } finally {
      setState(() {
        scrollListToEND();
        _isTyping = false;
      });
    }
  }
}
