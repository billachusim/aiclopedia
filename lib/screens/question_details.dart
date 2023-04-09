import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:AiClopedia/widgets/image_widget.dart';
import 'package:http/http.dart' as http;
import 'package:AiClopedia/models/questionModel.dart';
import 'package:chat_gpt_flutter/chat_gpt_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/api_consts.dart';
import '../services/firebaseServices.dart';

class QuestionDetails extends StatefulWidget {
  final Question question;

  const QuestionDetails({Key? key, required this.question}) : super(key: key);

  @override
  _QuestionDetailsState createState() => _QuestionDetailsState();
}

class _QuestionDetailsState extends State<QuestionDetails> {
  final FirebaseServices firebaseServices = FirebaseServices();
  final chatGpt = ChatGpt(apiKey: '$API_KEY');
  String? _answer;
  String generatedImageUrl = '';
  StreamSubscription<StreamCompletionResponse>? streamSubscription;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _getAnswer();
    generateImage(widget.question.question);
  }

  @override
  void dispose() {
    streamSubscription?.cancel();
    super.dispose();
  }



  Future<void> _getAnswer() async {
    setState(() {
      _isLoading = true;
    });
    final String questionId = widget.question.questionId;
    final testPrompt = widget.question.question;
    final question = testPrompt;
    final request = CompletionRequest(
      maxTokens: 4000,
      messages: [Message(role: Role.user.name, content: question)],
    );
    try {
      final response = await chatGpt.createChatCompletion(request);
      setState(() {
        _answer = response!.choices?.first.message?.content;
        final String answer = _answer.toString();
        firebaseServices.saveAnswer(questionId, answer);
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      log("Error occurred: $error");
    }
  }


  Future<void> generateImage(String userInput) async {
    final String questionId = widget.question.questionId;
    final url = Uri.parse('https://api.openai.com/v1/images/generations');
    final headers = {
      'Authorization': 'Bearer $API_KEY',
      'Content-Type': 'application/json'
    };
    final body = {'model': 'image-alpha-001', 'prompt': userInput, 'num_images': 1, 'size': '512x512'};
    final response = await http.post(url, headers: headers, body: jsonEncode(body));
    final data = jsonDecode(response.body);
    if (data != null && data['data'] != null && data['data'].isNotEmpty) {
      setState(() {
        generatedImageUrl = data['data'][0]['url'];
        final String imageUrl = generatedImageUrl;
        firebaseServices.saveImageUrl(questionId, imageUrl);
      });
    } else {
      if (kDebugMode) {
        print('Error generating image: $data');
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final question = widget.question;

    return Scaffold(
      appBar: AppBar(
        title: Text('Question Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.question,
              style: TextStyle(
                fontSize: 22.0,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: 12.0),
            if (_isLoading)
              Center(
                child: CircularProgressIndicator(),
              )
            else
              Container(
                child: SelectableText(
                  _answer ?? '',
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Colors.white,
                  ),
                ),
              ),
            SizedBox(height: 20.0),
            Text(
              'Nickname: ${question.nickname}',
              style: TextStyle(
                fontSize: 15.0,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: 4.0),
            Text(
              'Name of School: ${question.nameOfSchool}',
              style: TextStyle(
                fontSize: 14.0,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: 4.0),
            Text(
              'Time: ${question.timestamp}',
              style: TextStyle(
                fontSize: 14.0,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: 20.0),
            Visibility(
              visible: generatedImageUrl.length>11,
              child: Container(
                child: Image.network(
                  generatedImageUrl,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
