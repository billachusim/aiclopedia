import 'package:AiClopedia/screens/question_details.dart';
import 'package:AiClopedia/widgets/bottom_nav.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../models/questionModel.dart';
import '../services/ad_state.dart';
import '../services/firebaseServices.dart';

class AllActivitiesScreen extends StatefulWidget {

  const AllActivitiesScreen({Key? key,}) : super(key: key);

  @override
  _AllActivitiesScreenState createState() => _AllActivitiesScreenState();
}

class _AllActivitiesScreenState extends State<AllActivitiesScreen> {
  var currentUser = FirebaseAuth.instance.currentUser;
  bool? isFeatured;
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
          title: Text('All Questions'),
          leading: Image.asset("assets/images/aiclop.png"),
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
              stream: getAllQuestions(),
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
                        onTap: () {
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
                                'Asked by: ${question.nickname}',
                                style: TextStyle(
                                  fontSize: 16.0,
                                ),
                              ),
                              SizedBox(height: 4.0),
                              Text(
                                'School: ${question.nameOfSchool}',
                                style: TextStyle(
                                  fontSize: 16.0,
                                ),
                              ),

                              GestureDetector(
                                onTap: () {
                                  if (question.isFeatured == false)
                                    setState(() {
                                      setToFeatured(question);
                                    });
                                  else removeFromFeatured(question);
                                  setState(() {});
                                },
                                child: Container(
                                  child: Icon(
                                    question.isFeatured == true ? Icons.lightbulb : Icons.lightbulb_outline,
                                    color: Colors.green,
                                    size: 26,
                                  ),
                                ),
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

  Stream<List<Question>> getAllQuestions() {
    return FirebaseFirestore.instance
        .collection('questions')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((querySnapshot) => querySnapshot.docs
        .map((doc) => Question.fromJson(doc.data()))
        .toList());
  }


  /// Edit feature

  Future<bool?> setToFeatured(Question question) async {
    final String questionId = question.questionId;
    final value = true;
    FirebaseFirestore.instance
        .collection('questions')
        .doc(questionId)
        .update({
      "isFeatured": value,
    },
    );
    logger.d('Successfully changed feature');
    print('Is Featured?: $value');
    isFeatured = value;
    return value;
  }


  Future<bool?> removeFromFeatured(Question question) async {
    final String questionId = question.questionId;
    final value = false;
    FirebaseFirestore.instance
        .collection('questions')
        .doc(questionId)
        .update({
      "isFeatured": value,
    },
    );
    logger.d('Successfully changed feature');
    print('Is Featured?: $value');
    isFeatured = value;
    return value;
  }



}
