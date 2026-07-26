import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/button.dart';
import '../../services/firebaseServices.dart';
import '../../widgets/bottom_nav.dart';
import '../signup/signup.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSigningIn = false; // <-- RENAMED for clarity
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
      _emailController.text.trim(),
      _passwordController.text, // Do NOT trim passwords
    );

    if (!mounted) return;

    setState(() => _isSigningIn = false);

    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const BottomNavBar()),
            (Route<dynamic> route) => false,
      );
    } else {
      // Logic for failed login is handled by the result.
      // FirebaseServices should ideally throw exceptions or return messages.
      // For now, let's just show a general error.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login failed. Please check your email and password.')),
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
                      color: textColor, // Adjusted for theme
                    ),
                  ),
                ),
                SizedBox(height: 50.0),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: textColor), // Adjusted for theme
                  cursorColor: textColor, // Adjusted for theme
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(borderSide: BorderSide(color: textColor)),
                    labelStyle: TextStyle(color: hintColor), // Adjusted for theme
                  ),
                  validator: (value) =>
                  value == null || value.isEmpty ? 'Please enter your email' : null,
                ),
                SizedBox(height: 25.0),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  style: TextStyle(color: textColor), // Adjusted for theme
                  cursorColor: textColor, // Adjusted for theme
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(borderSide: BorderSide(color: textColor)),
                    labelStyle: TextStyle(color: hintColor), // Adjusted for theme
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
                    icon: Image.asset("assets/images/google.png", height: 24), // Ensure you have this asset
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
                SizedBox(height: 20.0), // <-- ADJUSTED: Spacing

                // --- ADDED: Terms and Policy Widget ---
                _buildTermsAndPolicyText(),
                SizedBox(height: 20.0), // <-- ADJUSTED: Spacing

              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- ADDED: Widget for Terms and Policy ---
  Widget _buildTermsAndPolicyText() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subTextColor = isDarkMode ? Colors.white.withValues(alpha: 0.7) : Colors.black.withValues(alpha: 0.7);

    return Column(
      children: [
        Text(
          "By signing in, you consent to your questions being sent to OpenAI to process and return answers.",
          textAlign: TextAlign.center,
          style: GoogleFonts.lato(fontSize: 12.0, color: subTextColor),
        ),
        SizedBox(height: 8),
        Text(
          "By signing in, you are accepting Ai Clopedia's Terms Of Use and Privacy Policy",
          textAlign: TextAlign.center,
          style: GoogleFonts.lato(fontSize: 12.0, color: subTextColor),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: _launchPolicySite,
          child: Text(
            "Tap to view Terms & Policy",
            style: GoogleFonts.lato(
              fontSize: 12.0,
              color: textColor,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
              decorationColor: textColor,
            ),
          ),
        ),
      ],
    );
  }
}
