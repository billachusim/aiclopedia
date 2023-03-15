import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:school_expo/screens/chat_screen.dart';
import 'package:school_expo/screens/image_screen.dart';
import 'package:school_expo/services/helper.dart';

import '../services/ad_state.dart';
import '../services/assets_manager.dart';
import '../services/services.dart';

class Homepage extends StatefulWidget {

  const Homepage({
    Key? key
  }) : super(key: key);

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {

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


  @override
  Widget build(BuildContext context) {

    return Material(
      child: Scaffold(
        appBar: AppBar(
          elevation: 2,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset(AssetsManager.openaiLogo),
          ),
          title: const Text("School Expo"),
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
            child: Column(
              children: [
                // Top ad unit is here
                if(homeTopBanner == null)
                  SizedBox(height: 70)
                else
                  SizedBox(
                    height: 60,
                    child: AdWidget(ad: homeTopBanner),
                  ),

                SizedBox(height: 20,),

                Column(
                  children: [

                    Container(
                      margin: EdgeInsets.all(16),
                      height: 120,
                      width: getDeviceWidth(context),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                      ),
                      child: Text(
                        "Welcome, Student\n"
                            "Here is a rap encouraging you to keep studying...",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    SizedBox(height: 30,),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => ChatScreen()),
                            );
                          },
                          child: Container(
                            height: 90,
                            width: 150,
                            decoration: BoxDecoration(
                              color: Colors.yellow,
                            ),
                            child: Center(
                              child: Text(
                                "Start Text Expo\n"
                                    "Ask AI Anything",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),

                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => ImageScreen()),
                            );
                          },
                          child: Container(
                            height: 90,
                            width: 150,
                            decoration: BoxDecoration(
                              color: Colors.green,
                            ),
                            child: Center(
                              child: Text(
                                "Start Image Expo\n"
                                    "Generate Any Image",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 20,),

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
                      height: 170,
                      width: getDeviceWidth(context),
                      decoration: BoxDecoration(
                        color: Colors.red,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "What is the third law of thermodynamics?",
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 20,),

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
          ),
        ),
      ),
    );
  }
}