import 'package:AiClopedia/widgets/bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../../services/ad_state.dart';
import '../../services/button.dart';
import '../../services/firebaseServices.dart';

class SignupPage extends StatefulWidget {

  SignupPage();

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _nameOfSchoolController = TextEditingController();
  final _passwordController = TextEditingController();
  bool isSigningIn = false;
  final FirebaseServices _firebaseServices = FirebaseServices();


  late BannerAd signupBottomBanner;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final adState = Provider.of<AdState>(context);

    // Implement a top location banner ad unit.
    adState.initialization.then((status) {
      setState(() {
        signupBottomBanner = BannerAd(
            size: AdSize.banner,
            adUnitId: adState.signupBottomBannerAdUnitId,
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
        title: Text('Register'),
      ),
      body: isSigningIn
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
                    'Welcome To AI',
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
                      return 'Please enter your nickname';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 25.0),TextFormField(
                  controller: _nameOfSchoolController,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: 'Name Of School Or City',
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
                      return 'Please enter your school or city name';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 25.0),
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
                DefaultButton(
                  text: 'Register',
                  press:  () async {
                      var validate = _formKey.currentState!.validate();
                      if (validate) {
                        isSigningIn = true;
                        setState(() {});
                        await _firebaseServices.register(
                            context,
                            _emailController.text,
                            _passwordController.text,
                            _nicknameController.text,
                            _nameOfSchoolController.text);
                      }
                      else {
                        //Fluttertoast.showToast(msg: 'error');
                        isSigningIn = false;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => BottomNavBar()),
                      );
                      },
                ),
                SizedBox(height: 10.0),
                // Top ad unit is here
                if(signupBottomBanner == null)
                  SizedBox(height: 70)
                else
                  SizedBox(
                    height: 60,
                    child: AdWidget(ad: signupBottomBanner),
                  ),
              ],
            ),
          ),
        ),
      ),

    );
  }
}
