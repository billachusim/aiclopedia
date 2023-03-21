import 'package:AiClopedia/widgets/bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
            child: Stack(
              children: [
                Container(
                  child: Image.asset(
                    "assets/images/amy.jpeg",
                    fit: BoxFit.fill,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(height: 20.0),
                    Text(
                      'Register',
                      style: TextStyle(
                        fontSize: 24.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 50.0),
                    TextFormField(
                      controller: _nicknameController,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        labelText: 'Nickname',
                        border: OutlineInputBorder(),
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
                        border: OutlineInputBorder(),
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
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
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
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
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
                    SizedBox(height: 16.0),

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
