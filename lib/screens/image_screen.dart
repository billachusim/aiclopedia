import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:provider/provider.dart';

import '../constants/api_consts.dart';
import '../constants/constants.dart';
import '../providers/chats_provider.dart';
import '../services/ad_state.dart';
import '../services/firebaseServices.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/image_widget.dart';

class ImageScreen extends StatefulWidget {
  const ImageScreen({super.key});

  @override
  _ImageScreenState createState() => _ImageScreenState();
}

const int maxFailedLoadAttempts = 3;


class _ImageScreenState extends State<ImageScreen> {
  String generatedImageUrl = '';
  List<Widget> chatList = [];
  final FirebaseServices firebaseServices = FirebaseServices();
  bool isTyping = false;
  late TextEditingController textEditingController;
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
    _listScrollController.dispose();
    textEditingController.dispose();
    focusNode.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }



  InterstitialAd? _interstitialAd;
  int _interstitialLoadAttempts = 0;

  // Create interstitial ad.

  void _createInterstitialAd() {
    InterstitialAd.load(
      adUnitId: Platform.isAndroid
          ? "ca-app-pub-2404156870680632/9546372208"
          : Platform.isIOS
          ? "ca-app-pub-2404156870680632/5347272743"
          : '',
      request: AdRequest(),
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



  BannerAd? imageScreenTopBanner;
  bool _bannerIsLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final adState = Provider.of<AdState>(context);

    // Implement a top location banner ad unit.
    adState.initialization.then((status) {
      setState(() {
        imageScreenTopBanner = BannerAd(
            size: AdSize.banner,
            adUnitId: adState.imageScreenTopBannerAdUnitId,
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
          title: const Text("Get Any Image"),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Top ad unit is here
              if (imageScreenTopBanner != null && _bannerIsLoaded)
                SizedBox(
                  height: 60,
                  child: AdWidget(ad: imageScreenTopBanner!),
                )
              else
                SizedBox(height: 70, child: Text('Relevant ads only', style: TextStyle(color: Colors.white),),),

              Flexible(
                child: ListView.builder(
                    controller: _listScrollController,
                    itemCount: chatProvider.getChatList.length, //chatList.length,
                    itemBuilder: (context, index) {
                      return Container();
                    }
                    ),
              ),
              if (isTyping) ...[
                const SpinKitThreeBounce(
                  color: Colors.white,
                  size: 18,
                ),
                Text("Loading image of ${textEditingController.text}",
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
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
                            final question = textEditingController.text.trim();
                            final user = await firebaseServices.getUserInfo();
                            setState(() {
                              isTyping = true;
                            });
                            await generateImage(textEditingController.text);
                            await firebaseServices.saveQuestion(user, question);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => ImageWidget(msg: generatedImageUrl)),
                            );
                            textEditingController.clear();
                            isTyping = false;
                          },
                          decoration: const InputDecoration.collapsed(
                              hintText: "Image of a happy rabbit?",
                              hintStyle: TextStyle(color: Colors.grey)),
                        ),
                      ),
                      IconButton(
                          onPressed: () async {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Creating image; might see an ad.'),
                              ),
                            );
                            final question = textEditingController.text.trim();
                            final user = await firebaseServices.getUserInfo();
                            setState(() {
                              isTyping = true;
                            });
                            await generateImage(question);
                            await firebaseServices.saveQuestion(user, question);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => ImageWidget(msg: generatedImageUrl)),
                            );
                            textEditingController.clear();
                            isTyping = false;
                            Future.delayed(Duration(seconds: 4), () {
                              _showInterstitialAd();
                            });
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



  Future<void> generateImage(String userInput) async {
    final url = Uri.parse('https://api.openai.com/v1/images/generations');
    final headers = {
      'Authorization': 'Bearer $API_KEY',
      'Content-Type': 'application/json'
    };
    final body = {'model': 'image-alpha-001', 'prompt': userInput, 'num_images': 1, 'size': '512x512'};
    final response = await http.post(url, headers: headers, body: jsonEncode(body));
    final data = jsonDecode(response.body);
    if (data != null && data['data'] != null && data['data'].isNotEmpty) {
      setState(() {
        generatedImageUrl = data['data'][0]['url'];
      });
    } else {
      if (kDebugMode) {
        print('Error generating image: $data');
      }
    }
  }

}
