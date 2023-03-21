import 'package:AiClopedia/widgets/auto_scroll_container.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:AiClopedia/screens/chat_screen.dart';
import 'package:AiClopedia/screens/image_screen.dart';
import 'package:AiClopedia/services/helper.dart';

import '../models/questionModel.dart';
import '../services/ad_state.dart';
import '../services/assets_manager.dart';
import '../services/services.dart';
import 'login/login.dart';

class Homepage extends StatefulWidget {

  const Homepage({
    Key? key
  }) : super(key: key);

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  var currentUser = FirebaseAuth.instance.currentUser;


  @override
  void initState() {
    super.initState();
  }



  @override
  void dispose() {
    super.dispose();
  }


  // Admob Ad Units.
  late BannerAd homeTopBanner;
  late BannerAd homeBottomBanner;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final adState = Provider.of<AdState>(context);

    // Implement a top location banner ad unit.
    adState.initialization.then((status) {
      setState(() {
        homeTopBanner = BannerAd(
            size: AdSize.banner,
            adUnitId: adState.homeTopBannerAdUnitId,
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


    // Implement a top location banner ad unit.
    adState.initialization.then((status) {
      setState(() {
        homeBottomBanner = BannerAd(
            size: AdSize.banner,
            adUnitId: adState.homeBottomBannerAdUnitId,
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

  Stream<List<Question>> getQuestions(String userId) {
    return FirebaseFirestore.instance
        .collection('questions')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((querySnapshot) => querySnapshot.docs
        .map((doc) => Question.fromJson(doc.data()))
        .toList());
  }


  @override
  Widget build(BuildContext context) {

    return Material(
      child: Scaffold(
        appBar: AppBar(
          elevation: 2,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset("assets/images/aiclopedia.png"),
          ),
          title: const Text("AiClopedia"),
          actions: [
            IconButton(
              onPressed: () async {
                await Services.showModalSheet(context: context);
              },
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: SizedBox(
            height: getDeviceHeight(context),
            width: getDeviceWidth(context),
            child: Stack(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height,
                  width: MediaQuery.of(context).size.width,
                  child: Image.asset(
                    "assets/images/amy.jpeg",
                    fit: BoxFit.fill,
                  ),
                ),
                Column(
                  children: [
                    // Top ad unit is here
                    if(homeTopBanner == null)
                      SizedBox(height: 70)
                    else
                      SizedBox(
                        height: 60,
                        child: AdWidget(ad: homeTopBanner),
                      ),

                    SizedBox(height: 4,),

                    Column(
                      children: [

                        AutoScrollContainer(),

                        SizedBox(height: 120,),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            GestureDetector(
                              onTap: () async {
                                if (currentUser == null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => LoginPage()),
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => ChatScreen()),
                                  );
                                }
                              },
                              child: Container(
                                height: 60,
                                width: 220,
                                decoration: BoxDecoration(
                                    color: Colors.yellow,
                                    borderRadius: BorderRadius.circular(10),
                                    gradient: LinearGradient(
                                        colors: const [
                                          Colors.green,
                                          Colors.lightGreenAccent,
                                        ]
                                    )
                                ),
                                child: Center(
                                  child: Text(
                                    "Ask AI Anything",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 30,),

                        Align(
                          alignment: Alignment.topLeft,
                          child: Container(
                            margin: EdgeInsets.only(left: 16),
                            width: 140,
                            alignment: Alignment.topLeft,
                            padding: EdgeInsets.all(3),
                            decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(25)
                            ),
                            child: Container(
                              height: 23,
                              width: 130,
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20)
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 9.0),
                                child: Text(
                                  "Answering Now:",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 15,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        Container(
                          margin: EdgeInsets.all(16),
                          height: 220,
                          width: getDeviceWidth(context),
                          decoration: BoxDecoration(
                            color: Colors.green,
                          ),
                          child: StreamBuilder<List<Question>>(
                            stream: getQuestions(currentUser!.uid),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return Center(
                                  child: Text('No questions yet'),
                                );
                              }

                              return ListView.builder(
                                itemCount: snapshot.data!.length,
                                itemBuilder: (context, index) {
                                  final question = snapshot.data![index];
                                  return Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8.0),
                                      color: Colors.grey[200],
                                    ),
                                    margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0),
                                    padding: EdgeInsets.all(4.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SelectableText(
                                          question.question,
                                          style: TextStyle(
                                            fontSize: 14.0,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 2.0),
                                        Text(
                                          "${question.nickname}, ${question.nameOfSchool}. | ${question.timestamp}",
                                          style: TextStyle(
                                            fontSize: 12.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),

                        SizedBox(height: 10,),

                        if(homeBottomBanner == null)
                          SizedBox(height: 70)
                        else
                          SizedBox(
                            height: 60,
                            child: AdWidget(ad: homeBottomBanner),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}