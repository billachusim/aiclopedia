import 'package:AiClopedia/screens/login/login.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/userModel.dart';


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
    try {
      // 1. Create user in Firebase Auth
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user;
      if (user == null) {
        throw Exception("User creation failed, user is null.");
      }

      // 2. Create the user document in Firestore with all required fields
      await _firebaseFirestore.collection("users").doc(user.uid).set({
        "userId": user.uid,
        "email": email,
        "nickname": nickname,
        "nameOfSchool": nameOfSchool,
        "password": password,
        "timeRegistered": FieldValue.serverTimestamp(),
        "timeLastUnlocked": FieldValue.serverTimestamp(),
        "userType": "REGULAR",
        "credits": 50,
        "isPremium": false,
        "premiumExpiryDate": null,
        "blockedUsers": [],
        "hasConsentedToDataSharing": false,
      });

      logger.d('Successfully created user document for ${user.uid}');

      // 3. Cache the user ID locally and sign them in
      setUsersId(user.uid);

      return true;

    } on FirebaseAuthException catch (e) {
      // It's better to show feedback to the user via UI state than using Toasts here.
      logger.e('FirebaseAuthException during registration: ${e.code}');
      // Consider re-throwing a custom exception to be handled by the UI.
      return false;
    } catch (e) {
      logger.e('An unexpected error occurred during registration: $e');
      return false;
    }
  }



  /// Authenticate the user in
  Future<bool> signIn(
      BuildContext context, String email, String password) async {
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password)
          .then((value) => {
        setUsersId(value.user!.uid),
        //showToast("Showing user UID ${value.user!.uid}")
      });
      //Fluttertoast.showToast(msg: 'You can continue shopping');
      // Navigator.of(context).pop(); // Let the caller handle navigation
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
    if (_usersID == null || _usersID!.isEmpty) {
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
    prefs = await SharedPreferences.getInstance();
    prefs!.setString(usersKey, id);
    notifyListeners();
  }


  /// get users id
  Future<String?> getUsersId() async {
    prefs = await SharedPreferences.getInstance();
    return prefs!.getString(usersKey);
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
    _usersID = currentUser?.uid;
    DocumentSnapshot response = await _firebaseFirestore
        .collection("users")
        .doc(_usersID)
        .get();

    var user = UserModel.fromJson(response.data() as Map<String, dynamic>);
    return user;
  }

  // Get a user document
  Stream<UserModel> streamUser(String uid) {
    return _firebaseFirestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) => UserModel.fromJson(snap.data()!));
  }

  /// START: DATA SHARING CONSENT
  Future<void> updateConsentStatus(String userId, bool consent) async {
    try {
      await _firebaseFirestore
          .collection('users')
          .doc(userId)
          .update({'hasConsentedToDataSharing': consent});
      logger.d('User $userId consent updated to $consent');
    } catch (e) {
      logger.e('Error updating user consent status: $e');
    }
  }


  Future<bool> checkAndRequestDataSharingConsent(
      BuildContext context, UserModel user) async {
    if (user.hasConsentedToDataSharing) {
      return true; // User has already consented
    }

    // Show the disclosure dialog
    final bool? userGaveConsent = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must make a choice
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Data & Privacy'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                    'To provide AI-powered answers, we need to share some of your data with our AI service partner (e.g., OpenAI).'),
                SizedBox(height: 16),
                Text('What we share:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('• Your question content.'),
                Text('• Your nickname and school name for context.'),
                SizedBox(height: 16),
                Text(
                    'This data is used solely to generate an answer and is handled according to our Privacy Policy.'),
                SizedBox(height: 16),
                Text('Do you agree to share this data?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('DECLINE'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false); // User declined
              },
            ),
            TextButton(
              child: const Text('AGREE'),
              onPressed: () {
                Navigator.of(dialogContext).pop(true); // User agreed
              },
            ),
          ],
        );
      },
    );

    if (userGaveConsent == true) {
      // User agreed, update their profile
      await updateConsentStatus(user.userId, true);
      return true;
    } else {
      // User declined
      return false;
    }
  }

  /// END: DATA SHARING CONSENT

  Future<bool> saveQuestion(UserModel user, String question) async {
    if (!user.hasConsentedToDataSharing) {
      logger.i('User has not consented to data sharing. Question not saved.');
      return false; // Indicate that saving was blocked by lack of consent.
    }
    final String nickname = user.nickname;
    final String nameOfSchool = user.nameOfSchool;
    final String questionId = uuid.v1();

    try {
      await FirebaseFirestore.instance
          .collection('questions')
          .doc(questionId)
          .set({
        'userId': user.userId,
        'nickname': nickname,
        'nameOfSchool': nameOfSchool,
        'question': question,
        'answer': '',
        'imageUrl': '',
        'questionId': questionId,
        'isFeatured': false,
        'thumbsUpCount': 0,
        'thumbsDownCount': 0,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      prefs = await SharedPreferences.getInstance();
      await prefs!.setString('questionId', questionId);

      logger.d('Successfully saved question $questionId for user ${user.userId}');
      return true; // Indicate success

    } catch (e) {
      logger.d('Error sending question: $e');
      return false; // Indicate failure
    }
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

  Future<String?> getAnswer(String questionId) async {
    final doc = await FirebaseFirestore.instance
        .collection('questions')
        .doc(questionId)
        .get();

    return doc.data()?['answer'];
  }


  // Update user credits
  Future<void> updateUserCredits(String uid, int amount) async {
    try {
      await _firebaseFirestore.collection('users').doc(uid).update({
        'credits': FieldValue.increment(amount),
      });
    } catch (e) {
      // print(e.toString());
    }
  }

  // Activate premium subscription
  Future<void> activatePremiumSubscription(String uid) async {
    try {
      await _firebaseFirestore.collection('users').doc(uid).update({
        'isPremium': true,
        'premiumExpiryDate':
        Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
      });
    } catch (e) {
      // print(e.toString());
    }
  }




  // --- START: UGC MODERATION METHODS ---

  /// Reports a question and its owner.
  Future<bool> reportQuestion(String questionId, String questionOwnerId) async {
    final reporterId = currentUser?.uid;
    if (reporterId == null) return false;

    try {
      await _firebaseFirestore.collection('reports').add({
        'type': 'question',
        'questionId': questionId,
        'reportedUserId': questionOwnerId,
        'reporterId': reporterId,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending', // pending, reviewed
      });
      logger.d('Successfully reported question $questionId');
      return true;
    } catch (e) {
      logger.e('Error reporting question: $e');
      return false;
    }
  }

  /// Blocks a user, preventing their content from being seen.
  Future<bool> blockUser(String userIdToBlock) async {
    final currentUserId = currentUser?.uid;
    if (currentUserId == null) return false;

    try {
      await _firebaseFirestore.collection('users').doc(currentUserId).update({
        'blockedUsers': FieldValue.arrayUnion([userIdToBlock])
      });
      logger.d('Successfully blocked user $userIdToBlock');
      return true;
    } catch (e) {
      logger.e('Error blocking user: $e');
      return false;
    }
  }

  // --- END: UGC MODERATION METHODS ---


  /// [signOut] user
  void signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    await prefs?.clear(); // Use null-aware call
    logger.d('Successfully signed out');
    // Use pushAndRemoveUntil to clear the navigation stack
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
            (Route<dynamic> route) => false,
      );
    }
  }

  /// [delete] all users informations
  void deleteUserAccount(BuildContext context, String userId) async {
    await FirebaseAuth.instance.signOut();
    await prefs?.clear(); // Use null-aware call
    final userId0 = userId;
    final collection = FirebaseFirestore.instance
        .collection('users');
    await collection.doc(userId0).delete();
    logger.d('Successfully deleted an account');
    // Use pushAndRemoveUntil to clear the navigation stack
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
            (Route<dynamic> route) => false,
      );
    }
  }
}
