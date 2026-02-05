import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; // <-- ADDED: For launching URLs
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
  bool _isSigningIn = false; // <-- RENAMED for clarity
  final FirebaseServices _firebaseServices = FirebaseServices();

  BannerAd? loginBottomBanner;
  bool _bannerIsLoaded = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    loginBottomBanner?.dispose(); // <-- ADDED: Dispose banner ad
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load banner only once
    if (loginBottomBanner == null) {
      final adState = Provider.of<AdState>(context, listen: false);
      adState.initialization.then((status) {
        if (!mounted) return;
        setState(() {
          loginBottomBanner = BannerAd(
              size: AdSize.banner,
              adUnitId: adState.loginBottomBannerAdUnitId,
              request: const AdRequest(),
              listener: BannerAdListener(
                onAdLoaded: (ad) {
                  if (mounted) {
                    setState(() => _bannerIsLoaded = true);
                  }
                },
                onAdFailedToLoad: (ad, error) {
                  ad.dispose();
                },
              ))
            ..load();
        });
      });
    }
  }

  // --- ADDED: Method to launch URL ---
  void _launchPolicySite() async {
    // IMPORTANT: Replace with your actual policy URL
    final Uri url = Uri.parse("https://sites.google.com/view/ai-clopedia/home");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the policy page.')),
      );
    }
  }

  // --- ADDED: Method to handle login logic ---
  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSigningIn = true);

    bool success = await _firebaseServices.signIn(
      context,
      _emailController.text,
      _passwordController.text,
    );

    if (!mounted) return;

    setState(() => _isSigningIn = false);

    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => BottomNavBar()),
            (Route<dynamic> route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed. Please check your credentials.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
      ),
      body: SingleChildScrollView( // <-- MODIFIED: To prevent overflow
        child: Padding(
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
                  style: TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                    labelStyle: TextStyle(color: Colors.white),
                  ),
                  validator: (value) =>
                  value == null || value.isEmpty ? 'Please enter your email' : null,
                ),
                SizedBox(height: 25.0),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  style: TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                    labelStyle: TextStyle(color: Colors.white),
                  ),
                  validator: (value) =>
                  value == null || value.isEmpty ? 'Please enter your password' : null,
                ),
                SizedBox(height: 15.0),
                // Removed 'Forgot Password' as it wasn't implemented
                SizedBox(height: 50.0),

                // --- MODIFIED: Login Button Logic ---
                if (_isSigningIn)
                  CircularProgressIndicator()
                else
                  DefaultButton(
                    text: 'Login',
                    press: _handleLogin,
                  ),

                SizedBox(height: 30.0),
                DefaultButton(
                  text: 'Register',
                  press: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SignupPage()),
                    );
                  },
                ),
                SizedBox(height: 20.0), // <-- ADJUSTED: Spacing

                // --- ADDED: Terms and Policy Widget ---
                _buildTermsAndPolicyText(),
                SizedBox(height: 20.0), // <-- ADJUSTED: Spacing

                if (_bannerIsLoaded && loginBottomBanner != null)
                  SizedBox(
                    height: loginBottomBanner!.size.height.toDouble(),
                    child: AdWidget(ad: loginBottomBanner!),
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

  // --- ADDED: Widget for Terms and Policy ---
  Widget _buildTermsAndPolicyText() {
    return Column(
      children: [
        Text(
          "By signing in, you are accepting Ai Clopedia's Terms Of Use and Privacy Policy",
          textAlign: TextAlign.center,
          style: GoogleFonts.lato(fontSize: 12.0, color: Colors.white.withOpacity(0.7)),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: _launchPolicySite,
          child: Text(
            "Tap to view Terms & Policy",
            style: GoogleFonts.lato(
              fontSize: 12.0,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
              decorationColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
