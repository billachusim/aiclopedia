import 'package:AiClopedia/screens/all_activities.dart';
import 'package:AiClopedia/screens/question_details.dart';
import 'package:AiClopedia/widgets/auto_scroll_container.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:AiClopedia/screens/chat_screen.dart';
import 'package:AiClopedia/services/helper.dart';

import '../models/questionModel.dart';
import '../models/userModel.dart';
import '../services/ad_state.dart';
import '../services/firebaseServices.dart';
import '../widgets/question_widget.dart';
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
  final FirebaseServices firebaseServices = FirebaseServices();
  var currentUser = FirebaseAuth.instance.currentUser;
  String nickname = '';

  @override
  void initState() {
    super.initState();
    AppTrackingTransparency.requestTrackingAuthorization();
    getUser();
  }



  @override
  void dispose() {
    super.dispose();
  }

  void getUser() async {
    final UserModel user = await firebaseServices.getUserInfo();
    nickname = user.nickname;
  }


  // Admob Ad Units.
  BannerAd? homeTopBanner;
  BannerAd? homeBottomBanner;
  bool _bannerIsLoaded = false;

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

  Stream<List<Question>> getQuestions() {
    return FirebaseFirestore.instance
        .collection('questions')
        .where("isFeatured", isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .limit(50)
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
          leading: GestureDetector(
            onDoubleTap: () async {
              final user = await firebaseServices.getUserInfo();
              if (user.userType == 'ADMIN') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => AllActivitiesScreen()),
                );
              }
            },
              child: Image.asset("assets/images/aiclop.png")
          ),
          title: const Text("Ai Clopedia"),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              child: Image.asset(
                "assets/images/ClaireDark.png",
                fit: BoxFit.fill,
              ),
            ),
            ListView(
              children: [
                // Top ad unit is here
                if (homeTopBanner != null && _bannerIsLoaded)
                  SizedBox(
                    height: 60,
                    child: AdWidget(ad: homeTopBanner!),
                  )
                else
                  SizedBox(height: 70, child: Text('Relevant ads only', style: TextStyle(color: Colors.white),),),

                SizedBox(height: 4,),

                AutoScrollContainer(nickname: nickname),

                SizedBox(height: 75,),

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
                            boxShadow: [
                              BoxShadow(
                                color: Colors.lightGreen.withOpacity(0.9),
                                spreadRadius: 2,
                                blurRadius: 3,
                                offset: Offset(0, 3), // changes position of shadow
                              ),
                            ],
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

                SizedBox(height: 50,),

                Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    margin: EdgeInsets.only(left: 16),
                    width: 185,
                    alignment: Alignment.topLeft,
                    padding: EdgeInsets.all(3),
                    decoration: BoxDecoration(
                        color: Colors.yellow,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12.withOpacity(0.9),
                            spreadRadius: 2,
                            blurRadius: 3,
                            offset: Offset(0, 3), // changes position of shadow
                          ),
                        ],
                        gradient: LinearGradient(
                            colors: const [
                              Colors.lightGreenAccent,
                              Colors.green,
                            ]
                        )
                    ),
                    child: Container(
                      height: 22,
                      width: 170,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20)
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 9.0),
                        child: Text(
                          "Featured Questions:",
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
                  height: 400,
                  width: getDeviceWidth(context),
                  decoration: BoxDecoration(
                    //color: Colors.green,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: StreamBuilder<List<Question>>(
                    stream: getQuestions(),
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

                      if (snapshot.hasData) {
                      }

                      return ListView.builder(
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final question = snapshot.data![index];
                          return GestureDetector(
                            onTap: () async {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => QuestionDetails(question: question),
                                ),
                              );

                              // Handle the result, if needed.
                              // For example, you could refresh the question list if the user edited the question.
                            },
                            child: QuestionWidget(question: question,)
                          );
                        },
                      );
                    },
                  ),
                ),

                SizedBox(height: 10,),

                if (homeBottomBanner != null && _bannerIsLoaded)
                  SizedBox(
                    height: 60,
                    child: AdWidget(ad: homeBottomBanner!),
                  )
                else
                  SizedBox(height: 70, child: Text('Relevant ads only', style: TextStyle(color: Colors.white),),),

              ],
            ),
          ],
        ),
      ),
    );
  }
}
