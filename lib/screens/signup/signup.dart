import 'package:AiClopedia/widgets/bottom_nav.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/button.dart';
import '../../services/firebaseServices.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  SignupPageState createState() => SignupPageState();
}

const int maxFailedLoadAttempts = 3;

class SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _nameOfSchoolController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSigningIn = false;
  bool _termsAccepted = false;
  bool _openAIConsentAccepted = false;
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




  // --- ADDED: Method to launch URL ---
  void _launchPolicySite() async {
    final Uri url = Uri.parse("https://sites.google.com/view/claire-diary/ai-clopedia-privacy-policy");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the policy page.')),
      );
    }
  }

  // --- ADDED: Method to handle Google login logic ---
  void _handleGoogleLogin() async {
    setState(() => _isSigningIn = true);

    bool success = await _firebaseServices.signInWithGoogle(context);

    if (!mounted) return;

    setState(() => _isSigningIn = false);

    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => BottomNavBar()),
        (Route<dynamic> route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-In failed or was cancelled.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final hintColor = isDarkMode ? Colors.white70 : Colors.black54;

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
                      color: textColor, // Adjusted for theme
                    ),
                  ),
                ),
                SizedBox(height: 50.0),
                TextFormField(
                  controller: _nicknameController,
                  keyboardType: TextInputType.text,
                  style: TextStyle(color: textColor), // Added for theme
                  decoration: InputDecoration(
                    labelText: 'Nickname',
                    border: OutlineInputBorder(),
                    labelStyle: TextStyle(color: hintColor), // Adjusted for theme
                  ),
                  validator: (value) =>
                  value == null || value.isEmpty ? 'Please enter your nickname' : null,
                ),
                SizedBox(height: 25.0),
                TextFormField(
                  controller: _nameOfSchoolController,
                  keyboardType: TextInputType.text,
                  style: TextStyle(color: textColor), // Added for theme
                  decoration: InputDecoration(
                    labelText: 'Name Of School Or City',
                    border: OutlineInputBorder(),
                    labelStyle: TextStyle(color: hintColor), // Adjusted for theme
                  ),
                  validator: (value) =>
                  value == null || value.isEmpty ? 'Please enter your school or city name' : null,
                ),
                SizedBox(height: 25.0),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: textColor), // Added for theme
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    labelStyle: TextStyle(color: hintColor), // Adjusted for theme
                  ),
                  validator: (value) =>
                  value == null || value.isEmpty ? 'Please enter your email' : null,
                ),
                SizedBox(height: 25.0),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  style: TextStyle(color: textColor), // Added for theme
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    labelStyle: TextStyle(color: hintColor), // Adjusted for theme
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
                const SizedBox(height: 20.0),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text("OR"),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 20.0),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _isSigningIn ? null : _handleGoogleLogin,
                    icon: Image.asset("assets/images/google.png", height: 24),
                    label: Text(
                      "Continue with Google",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: textColor.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
                const SizedBox(height: 20.0),
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

    if (!_openAIConsentAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You must confirm AI processing consent to register.')),
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

  Widget _buildTermsAndPolicyText() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subTextColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.black.withValues(alpha: 0.7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        /// TERMS CHECKBOX
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _termsAccepted,
              onChanged: (bool? value) {
                setState(() {
                  _termsAccepted = value ?? false;
                });
              },
              checkColor: isDarkMode ? Colors.black : Colors.white,
              activeColor: textColor,
              side: BorderSide(color: textColor, width: 2),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: "I agree to AI Clopedia's ",
                  style: GoogleFonts.lato(
                    fontSize: 13.0,
                    color: subTextColor,
                  ),
                  children: [
                    TextSpan(
                      text: "Terms & Privacy Policy",
                      style: GoogleFonts.lato(
                        fontSize: 13.0,
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
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

        SizedBox(height: 12),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _openAIConsentAccepted,
              onChanged: (bool? value) {
                setState(() {
                  _openAIConsentAccepted = value ?? false;
                });
              },
              checkColor: isDarkMode ? Colors.black : Colors.white,
              activeColor: textColor,
              side: BorderSide(color: textColor, width: 2),
            ),
            Expanded(
              child: Text(
                "I understand that my questions and prompts will be sent securely "
                    "to OpenAI for processing to generate answers and images. "
                    "No personal information such as my email or account details "
                    "will be shared with OpenAI.",
                style: GoogleFonts.lato(
                  fontSize: 12.5,
                  color: subTextColor,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: 10),

        Text(
          "By creating an account, you confirm that you will not post objectionable content, including nudity, hate speech, harassment, or spam. Violations may result in account suspension or permanent ban.",
          textAlign: TextAlign.left,
          style: GoogleFonts.lato(
            fontSize: 12.0,
            color: subTextColor,
            height: 1.4,
          ),
        ),
      ],
    );
  }

}
