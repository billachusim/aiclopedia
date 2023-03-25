import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:provider/provider.dart';

import '../constants/constants.dart';
import '../providers/chats_provider.dart';
import '../services/ad_state.dart';
import '../services/assets_manager.dart';
import '../services/services.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/image_widget.dart';
import 'home_screen.dart';

class ImageScreen extends StatefulWidget {
  const ImageScreen({super.key});

  @override
  _ImageScreenState createState() => _ImageScreenState();
}

class _ImageScreenState extends State<ImageScreen> {
  String generatedImageUrl = '';
  List<Widget> chatList = [];

  bool isTyping = false;

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

  late BannerAd imageScreenTopBanner;

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
            request: AdRequest(),
            listener: BannerAdListener(
              onAdFailedToLoad: (ad, error) {
                ad.dispose();
              },
            )
        )
          ..load();
      });
    });
  }

  // List<ChatModel> chatList = [];
  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    return WillPopScope(
      onWillPop: (){
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
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset("assets/images/aiclo.png"),
          ),
          title: const Text("Ask Anything"),
          actions: [
            IconButton(
              onPressed: () async {
                await Services.showModalSheet(context: context);
              },
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Top ad unit is here
              if(imageScreenTopBanner == null)
                SizedBox(height: 70)
              else
                SizedBox(
                  height: 60,
                  child: AdWidget(ad: imageScreenTopBanner),
                ),

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
                            setState(() {
                              isTyping = true;
                            });
                            await generateImage(textEditingController.text);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => ImageWidget(msg: generatedImageUrl)),
                            );
                            textEditingController.clear();
                            isTyping = false;
                          },
                          decoration: const InputDecoration.collapsed(
                              hintText: "What's the second law of motion?",
                              hintStyle: TextStyle(color: Colors.grey)),
                        ),
                      ),
                      IconButton(
                          onPressed: () async {
                            setState(() {
                              isTyping = true;
                            });
                            await generateImage(textEditingController.text);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => ImageWidget(msg: generatedImageUrl)),
                            );
                            textEditingController.clear();
                            isTyping = false;
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
      'Authorization': 'Bearer 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',
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
