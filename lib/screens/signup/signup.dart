import 'dart:io';

import 'package:AiClopedia/widgets/bottom_nav.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; // <-- ADDED: For launching URLs
import '../../services/ad_state.dart';
import '../../services/button.dart';
import '../../services/firebaseServices.dart';

class SignupPage extends StatefulWidget {
  SignupPage();

  @override
  _SignupPageState createState() => _SignupPageState();
}

const int maxFailedLoadAttempts = 3;

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _nameOfSchoolController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSigningIn = false;
  bool _termsAccepted = false; // <-- ADDED: State for checkbox
  final FirebaseServices _firebaseServices = FirebaseServices();


  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nicknameController.dispose();
    _nameOfSchoolController.dispose();
    _passwordController.dispose();
    super.dispose();
  }


  BannerAd? signupBottomBanner;
  bool _bannerIsLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final adState = Provider.of<AdState>(context);

    adState.initialization.then((status) {
      if (mounted && signupBottomBanner == null) {
        setState(() {
          signupBottomBanner = BannerAd(
              size: AdSize.banner,
              adUnitId: adState.signupBottomBannerAdUnitId,
              request: const AdRequest(),
              listener: BannerAdListener(
                onAdLoaded: (ad) => setState(() => _bannerIsLoaded = true),
                onAdFailedToLoad: (ad, error) {
                  ad.dispose();
                },
              ))
            ..load();
        });
      }
    });
  }

  // --- ADDED: Method to launch URL ---
  void _launchPolicySite() async {
    // IMPORTANT: Replace with your actual policy URL
    final Uri url = Uri.parse("https://sites.google.com/view/ai-clopedia/home");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the policy page.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Register'),
      ),
      body: _isSigningIn
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(height: 20.0),
                Center(
                  child: Image.asset("assets/images/aiclopedia.png",
                      width: 120, height: 120),
                ),
                SizedBox(height: 20.0),
                Center(
                  child: Text(
                    'Welcome To AI Clopedia',
                    style: TextStyle(
                      fontSize: 25.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(height: 50.0),
                TextFormField(
                  controller: _nicknameController,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: 'Nickname',
                    border: OutlineInputBorder(),
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  validator: (value) =>
                  value == null || value.isEmpty ? 'Please enter your nickname' : null,
                ),
                SizedBox(height: 25.0),
                TextFormField(
                  controller: _nameOfSchoolController,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: 'Name Of School Or City',
                    border: OutlineInputBorder(),
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  validator: (value) =>
                  value == null || value.isEmpty ? 'Please enter your school or city name' : null,
                ),
                SizedBox(height: 25.0),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  validator: (value) =>
                  value == null || value.isEmpty ? 'Please enter your email' : null,
                ),
                SizedBox(height: 25.0),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  validator: (value) =>
                  value == null || value.isEmpty ? 'Please enter your password' : null,
                ),
                SizedBox(height: 25.0),
                // --- ADDED: Terms and Policy Widget ---
                _buildTermsAndPolicyText(),
                SizedBox(height: 25.0),
                DefaultButton(
                  text: 'Register',
                  press: _handleRegistration, // <-- MODIFIED: Extracted to a method
                ),
                SizedBox(height: 20.0),
                if (_bannerIsLoaded && signupBottomBanner != null)
                  SizedBox(
                    height: signupBottomBanner!.size.height.toDouble(),
                    child: AdWidget(ad: signupBottomBanner!),
                  )
                else
                  SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- ADDED: Method to handle registration logic ---
  void _handleRegistration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You must accept the Terms & Policy to register.')),
      );
      return;
    }

    setState(() => _isSigningIn = true);

    bool success = await _firebaseServices.register(
      context,
      _emailController.text,
      _passwordController.text,
      _nicknameController.text,
      _nameOfSchoolController.text,
    );

    if (!mounted) return;

    setState(() => _isSigningIn = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration successful! An ad might appear.')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => BottomNavBar()),
            (Route<dynamic> route) => false,
      );
    } else {
      // The error message is shown by firebaseServices, but you could add a generic one here
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed. Please try again.')),
      );
    }
  }

  // --- ADDED: Widget for Terms and Policy ---
  Widget _buildTermsAndPolicyText() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Checkbox(
              value: _termsAccepted,
              onChanged: (bool? value) {
                setState(() {
                  _termsAccepted = value ?? false;
                });
              },
              checkColor: Colors.black, // Color of the check mark
              activeColor: Colors.white,
              side: BorderSide(color: Colors.white, width: 2),
            ),
            Flexible(
              child: Text.rich(
                TextSpan(
                  text: "I agree to Ai Clopedia's ",
                  style: GoogleFonts.lato(
                    fontSize: 13.0,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  children: [
                    TextSpan(
                      text: "Terms & Policy",
                      style: GoogleFonts.lato(
                        fontSize: 13.0,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = _launchPolicySite,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          "By creating an account, you agree to our Terms of Use. You confirm that you will not post objectionable content, such as nudity, hate speech, or spam, and you understand that abusive users will be banned.",
          textAlign: TextAlign.center,
          style: GoogleFonts.lato(
            fontSize: 12.0,
            color: Colors.white.withOpacity(0.7),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
