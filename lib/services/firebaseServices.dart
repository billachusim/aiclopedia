import 'package:AiClopedia/screens/login/login.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/userModel.dart';
import 'helper.dart';


Logger logger = Logger();
SharedPreferences? prefs;

class FirebaseServices extends ChangeNotifier {
  /// create instance of Firestore
  FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;

  User? currentUser = FirebaseAuth.instance.currentUser;
  final String usersKey = 'user';
  final String alterEgoKey = 'alterEgo';
  final String alterEgoAccessCodeKey = 'alterEgoAccessCodeKey';
  String? _usersID;


//used for generating random id for each session
  var uuid = Uuid();

  //UserModel? user;


  /// SignUp user
  Future<bool> register(
      BuildContext context, String email, String password, String nickname, String nameOfSchool) async {
    final _user = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);
    final _email = email;
    final _password = password;
    final _nickname = nickname;
    final _nameOfSchool = nameOfSchool;
    try {
      final email = _email;
      final secretCode = _password;
      final timeLastUnlocked = FieldValue.serverTimestamp();
      final timeRegistered = FieldValue.serverTimestamp();
      final userType = "REGULAR";
      final nickname = _nickname;
      final userId = _user.user?.uid;
      final nameOfSchool = _nameOfSchool;
      FirebaseFirestore.instance
          .collection("users")
          .doc(_user.user!.uid)
          .set({
        "nickname": nickname,
        "userId": userId,
        "nameOfSchool": nameOfSchool,
        "email": email,
        "password": password,
        "timeLastUnlocked": timeLastUnlocked,
        "timeRegistered": timeRegistered,
        "userType": userType,
      },
      );
      logger.d('Completely created new ego');
      if (kDebugMode) {
        print('Email: $email');
      }

      setUsersId(_user.user!.uid);

      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: secretCode)
          .then((value) => {
        setUsersId(value.user!.uid),
      });

      //Fluttertoast.showToast(msg: 'Welcome To Ime Afia');
      Navigator.of(context).pop();
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        //Fluttertoast.showToast(msg:'The password provided is too weak.');
      } else if (e.code.length < 4) {
        //Fluttertoast.showToast(msg:'secret code should be up to 4 digits');
      } else if (e.code == 'email-already-in-use') {
        //Fluttertoast.showToast(msg:'The account already exists for that email.');
      } else if (!isValidEmail(email)) {
        //Fluttertoast.showToast(msg:'email is not invalid');
      }
      logger.e(e);
      //Fluttertoast.showToast(msg: 'error');
      return false;
    } catch (e) {
      logger.e(e);
      return false;
    }
  }


  /// Authenticate the user in
  Future<bool> signIn(
      BuildContext context, String email, String password) async {
    final _user;
    try {
      _user = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password)
          .then((value) => {
        setUsersId(value.user!.uid),
        //showToast("Showing user UID ${value.user!.uid}")
      });
      //Fluttertoast.showToast(msg: 'You can continue shopping');
      Navigator.of(context).pop();
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        //Fluttertoast.showToast(msg: 'The ego code is invalid or the ego does not have an ego code.');
      } else if (e.code == 'wrong-email') {
        //Fluttertoast.showToast(msg:'The email is invalid or the user does not have an email.');
      }
      //Fluttertoast.showToast(msg: 'error');
      return false;
    } catch (e) {
      print(e);
      return false;
    }
  }


  /// checks if a user is signed in or not
  /// if the use is not signed in
  /// then request them to sign in
  Future<bool> isUserSignIn(BuildContext context) async {
    _usersID = await getUsersId();
    if (_usersID!.isEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => LoginPage()),
      );      return false;
    }
    return true;
  }


  /// cache user id
  void setUsersId(String id) async {
    //await getUserWithId(id: id);
    prefs = await SharedPreferences.getInstance();
    prefs!.setString(usersKey, id);
    notifyListeners();
  }


  /// get users id
  Future<String> getUsersId() async {
    prefs = await SharedPreferences.getInstance();
    return prefs!.getString(usersKey) ?? '';
  }



  /// Update a user's last time unlocked

  Future<void> updateUserLastTimeUnlocked(String id) async {
    FirebaseFirestore.instance
        .collection('users')
        .doc(id)
        .update(
      {
        "timeLastUnlocked": FieldValue.serverTimestamp(),
      },
    );
    logger.d('Successfully updated user last time unlocked');
  }




  /// Get user info

  Future<UserModel> getUserInfo() async {
    _usersID = await getUsersId();
    DocumentSnapshot response = await _firebaseFirestore
        .collection("users")
        .doc(_usersID)
        .get();

    var user = UserModel.fromJson(response.data() as Map<String, dynamic>);
    return user;
  }


  Future<void> saveQuestion(UserModel user, String question) async {
    final String nickname = user.nickname;
    final String nameOfSchool = user.nameOfSchool;
    final String questionId = uuid.v1();

    try {
      await FirebaseFirestore.instance.collection('questions').doc(questionId).set({
        'userId': user.userId,
        'nickname': nickname,
        'nameOfSchool': nameOfSchool,
        'question': question,
        'answer': 'Tap open to load answer',
        'questionId': questionId,
        'isFeatured': false,
        'thumbsUpCount': 0,
        'thumbsDownCount': 0,
        'timestamp': FieldValue.serverTimestamp(),
      },SetOptions(merge: true));
    } catch (e) {
      print('Error sending question: $e');
    }

    prefs = await SharedPreferences.getInstance();
    prefs!.setString('questionId', questionId);
  }




  /// Update answer to question

  Future<void> saveAnswer(String questionId, String answer) async {
    final String newQuestionId = questionId;
    final String newAnswer = answer;
    FirebaseFirestore.instance
        .collection('questions')
        .doc(newQuestionId)
        .set(
      {
        "answer": newAnswer,
      },
      SetOptions(merge: true),
    );
    logger.d('Successfully updated answer to question');
  }


  /// Update image Url to question

  Future<void> saveImageUrl(String questionId, String url) async {
    final String newQuestionId = questionId;
    final String newUrl = url;
    FirebaseFirestore.instance
        .collection('questions')
        .doc(newQuestionId)
        .set(
      {
        "imageUrl": newUrl,
      },
      SetOptions(merge: true),
    );
    logger.d('Successfully updated image Url to question');
  }


  /// [delete] all users informations
  void deleteUserAccount(BuildContext context, String userId) async {
    await FirebaseAuth.instance.signOut();
    await prefs!.clear();
    final _userId = userId;
    final collection = FirebaseFirestore.instance
        .collection('users');
    await collection.doc(_userId).delete();
    logger.d('Successfully deleted an account');
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => LoginPage()),
    );  }


}



