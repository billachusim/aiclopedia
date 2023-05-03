import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/questionModel.dart';

class QuestionWidget extends StatefulWidget {
  final Question question;

  const QuestionWidget({Key? key, required this.question}) : super(key: key);

  @override
  _QuestionWidgetState createState() => _QuestionWidgetState();
}

class _QuestionWidgetState extends State<QuestionWidget> {
  int thumbsUpCount = 0;
  int thumbsDownCount = 0;

  Future<void> _updateLikesDislikes(int count, String field) async {
    final docRef = FirebaseFirestore.instance
        .collection('questions')
        .doc(widget.question.questionId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final docSnapshot = await transaction.get(docRef);
      if (!docSnapshot.exists) {
        throw Exception('Document does not exist!');
      }

      final currentCount = docSnapshot.get(field) ?? 0;
      final newCount = currentCount + count;

      transaction.update(docRef, {field: newCount});
    });
  }

  void incrementThumbsUp() {
    setState(() {
      thumbsUpCount++;
    });
    _updateLikesDislikes(1, 'thumbsUpCount');
  }

  void incrementThumbsDown() {
    setState(() {
      thumbsDownCount++;
    });
    _updateLikesDislikes(1, 'thumbsDownCount');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.9),
            spreadRadius: 2,
            blurRadius: 3,
            offset: Offset(0, 3), // changes position of shadow
          ),
        ],
        borderRadius: BorderRadius.circular(10),
        color: Colors.white70,
      ),
      margin: EdgeInsets.symmetric(vertical: 7.0, horizontal: 8.0),
      padding: EdgeInsets.all(4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.question.question,
            style: TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 2.0),
          Text(
            "${widget.question.nickname}, ${widget.question.nameOfSchool}. | ${widget.question.timestamp}",
            style: TextStyle(
              fontSize: 12.0,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(onTap: () {incrementThumbsUp();}, child: Icon(Icons.thumb_up, size: 18,)),
              SizedBox(width: 4,),
              Text('${widget.question.thumbsUpCount}'),
              SizedBox(width: 6,),
              GestureDetector(onTap: () {incrementThumbsDown();}, child: Icon(Icons.thumb_down, size: 18,)),
              SizedBox(width: 4,),
              Text('${widget.question.thumbsDownCount}'),
            ],
          ),
        ],
      ),
    );
  }
}
