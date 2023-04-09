import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../../services/ad_state.dart';
import '../../services/button.dart';
import '../../services/firebaseServices.dart';
import '../../widgets/bottom_nav.dart';
import '../signup/signup.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool isSigningIn = false;
  final FirebaseServices _firebaseServices = FirebaseServices();


  @override
  void initState() {
    super.initState();
  }


  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  late BannerAd loginBottomBanner;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final adState = Provider.of<AdState>(context);

    // Implement a bottom location banner ad unit.
    adState.initialization.then((status) {
      setState(() {
        loginBottomBanner = BannerAd(
            size: AdSize.banner,
            adUnitId: adState.loginBottomBannerAdUnitId,
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
      ),
      body: ListView(
            children: [
              Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: <Widget>[
                          SizedBox(height: 20.0),
                          Center(
                            child: Image.asset("assets/images/aiclopedia.png",
                                width: 120, height: 120),
                          ),
                          SizedBox(height: 20.0),
                          Center(
                            child: Text(
                              'Login To Your Account',
                              style: TextStyle(
                                fontSize: 25.0,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(height: 50.0),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(
                              color: Colors.white,
                            ),
                            cursorColor: Colors.white,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white,
                                ),
                              ),
                              labelStyle: TextStyle(
                                color: Colors.white,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 25.0),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            style: TextStyle(
                              color: Colors.white,
                            ),
                            cursorColor: Colors.white,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              border: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white,
                                ),
                              ),
                              labelStyle: TextStyle(
                                color: Colors.white,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 15.0),
                          Text(
                            'Forgot Password',
                            style: TextStyle(
                              fontSize: 13.0,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          SizedBox(height: 50.0),
                          isSigningIn != true?
                          DefaultButton(
                            text: 'Login',
                            press:  () async {
                              var validate = _formKey.currentState!.validate();
                              if (validate) {
                                isSigningIn = true;
                                setState(() {});
                                await _firebaseServices.signIn(
                                    context,
                                    _emailController.text,
                                    _passwordController.text);
                              }
                              else {
                                isSigningIn = false;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => BottomNavBar()),
                              );
                              },
                          )
                          : CircularProgressIndicator(),
                          SizedBox(height: 30.0),
                          DefaultButton(
                            text: 'Register',
                            press:  () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => SignupPage()),
                              );
                              },
                          ),
                          SizedBox(height: 10.0),
                          // Top ad unit is here
                          if(loginBottomBanner == null)
                            SizedBox(height: 70,
                            child: Text("Relevant ads only"),)
                          else
                            Container(
                              height: 60,
                              child: AdWidget(ad: loginBottomBanner),
                            ),

                        ],
                      ),
                    ),
              ),
            ],
          ),

    );
  }
}
