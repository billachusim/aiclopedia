import 'package:AiClopedia/screens/question_details.dart';
import 'package:AiClopedia/services/firebaseServices.dart';
import 'package:AiClopedia/widgets/bottom_nav.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../models/questionModel.dart';
import '../services/ad_state.dart';
import 'login/login.dart';

class ActivitiesScreen extends StatefulWidget {

  const ActivitiesScreen({Key? key,}) : super(key: key);

  @override
  _ActivitiesScreenState createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  var currentUser = FirebaseAuth.instance.currentUser;
  FirebaseServices firebaseServices = FirebaseServices();

  BannerAd? activitiesScreenTopBanner;
  bool _bannerIsLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final adState = Provider.of<AdState>(context);

    // Implement a top location banner ad unit.
    adState.initialization.then((status) {
      setState(() {
        activitiesScreenTopBanner = BannerAd(
            size: AdSize.banner,
            adUnitId: adState.activitiesScreenTopBannerAdUnitId,
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

  deleteAccountAlertDialog(BuildContext context) {

    // set up the buttons
    Widget cancelButton = TextButton(
      child: Text("NO, WAIT!"),
      onPressed:  () {
        Navigator.of(context).pop();
      },
    );

    Widget continueButton = TextButton(
      child: Text("YES, DELETE EGO."),
      onPressed:  () {
        firebaseServices.deleteEgoAccount(context, currentUser!.uid);
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => LoginPage()),
        );
        },
    );

    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: Text("Delete your account and all your data?"),
      content: Text("Do you really want to delete your account and all your data?"),
      actions: [
        cancelButton,
        continueButton,
      ],
    );

    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
          title: Text('My Questions'),
          automaticallyImplyLeading: true,
          actions: [
            PopupMenuButton(
              itemBuilder: (BuildContext context) => [
                PopupMenuItem(
                  child: Text('Delete Account'),
                  value: 'delete',
                ),
              ],
              onSelected: (value) {
                // Handle item selection
                if (value == 'delete') {
                  // Handle settings selection
                  deleteAccountAlertDialog(context);
                }
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Top ad unit is here
            if (activitiesScreenTopBanner != null && _bannerIsLoaded)
              SizedBox(
                height: 60,
                child: AdWidget(ad: activitiesScreenTopBanner!),
              )
            else
              SizedBox(height: 70, child: Text('Relevant ads only', style: TextStyle(color: Colors.white),),),

            StreamBuilder<List<Question>>(
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

                return Flexible(
                  child: ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final question = snapshot.data![index];
                      return GestureDetector(
                        onTap: () async {
                          // Navigate to the QuestionDetails screen and wait for a result.
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QuestionDetails(question: question),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8.0),
                            color: Colors.grey[200],
                          ),
                          margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                          padding: EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                question.question,
                                style: TextStyle(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8.0),
                              Text(
                                'Answer: ${question.answer}',
                                maxLines: 3,
                                style: TextStyle(
                                  fontSize: 14.0,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(height: 5.0),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    child: Icon(
                                      question.isFeatured == true ? Icons.lightbulb : Icons.lightbulb_outline,
                                      color: Colors.green,
                                      size: 26,
                                    ),
                                  ),

                                  Container(
                                    margin: EdgeInsets.only(bottom: 6),
                                    padding: EdgeInsets.all(5),
                                    width: 115,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20.0),
                                      gradient: LinearGradient(
                                        begin: Alignment(-0.37857140550652835, -1.9473685559777252),
                                        end: Alignment(1.2428571464417884, 2.526316110739735),
                                        stops: [0.0, 0.856177031993866, 1.0],
                                        colors: [
                                          Colors.white54,
                                          Colors.green,
                                          Colors.lightGreenAccent,
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: Text('O P E N',
                                        style: TextStyle(
                                            fontSize: 15.0,
                                            color: Colors.green,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Stream<List<Question>> getQuestions(String userId) {
    return FirebaseFirestore.instance
        .collection('questions')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((querySnapshot) => querySnapshot.docs
        .map((doc) => Question.fromJson(doc.data()))
        .toList());
  }
}
