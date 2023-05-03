import 'dart:math';

import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

final List<String> poems = [
  // Add the 20 poems here
  "When the going gets tough, don't give up the fight,\n"
      "Believe in yourself and keep pushing with all your might,\n"
      "Your dreams are worth fighting for, so keep hustling on,\n"
      "With hard work and perseverance, you'll reach where you belong.\n"
      "\n"
      "So keep on hustling, keep on striving,\n"
      "Never give up, keep on thriving,\n"
      "You have the power to make your dreams come true,\n"
      "So keep pushing forward, and success will come to you.\n",

  "Success comes to those who hustle,\n"
      "Who work hard and never rustle.\n"
      "Keep pushing forward every day,\n"
      "And soon enough, you'll find a way.\n"
      "So don't give up or let it go,\n"
      "Hustle hard and let it show.",

  "Keep your mind sharp and your body strong,\n"
      "And you'll find success won't take too long.\n"
      "Study hard and keep your dreams in sight,\n"
      "And you'll build a future that's bright.\n"
      "So push yourself to be the best you can be,\n"
      "And you'll achieve anything you want to see.",

  "Every journey begins with a step,\n"
      "And every success starts with a prep.\n"
      "So take a step forward and keep pushing on,\n"
      "And soon enough, you'll find your dawn.\n"
      "Hustle hard and don't give up,\n"
      "And you'll find your way to the top.",

  "It's not about where you start,\n"
      "But where you end up that sets you apart.\n"
      "So dream big and hustle hard,\n"
      "And you'll find your way to your reward.\n"
      "Stay focused and never give up the fight,\n"
      "And you'll achieve everything in sight.",

  "Chase your dreams and never give in,\n"
      "Hustle hard and let your work begin.\n"
      "Take that first step and don't look back,\n"
      "And you'll find success won't take too long to track.\n"
      "So keep pushing forward and never give up,\n"
      "And you'll achieve anything you want, yup.",

  "Success is not for those who wait,\n"
      "But for those who hustle and never hesitate.\n"
      "So keep pushing forward and never give up,\n"
      "And you'll find your way to the top.\n"
      "Stay focused and work hard each day,\n"
      "And you'll achieve everything you want, hooray.",

  "It's not about the destination, it's about the journey,\n"
      "So keep pushing forward and don't you worry.\n"
      "Hustle hard and let your work speak,\n"
      "And soon enough, you'll achieve your peak.\n"
      "So keep your head up and never give in,\n"
      "And you'll find your way to your win.",

  "Success is not given, it's earned through hard work,\n"
      "When you're hustling, don't be afraid to go berserk,\n"
      "Keep pushing forward, and don't give up the fight,\n"
      "Your dreams are worth it, so keep them in sight.\n"
      "\n"
      "Every small victory is a step towards the goal,\n"
      "So keep hustling, and you'll achieve your role,\n"
      "Success is a journey, not a destination,\n"
      "So keep grinding, and reach your destination.\n",

  "When things get tough, and you feel like giving up,\n"
      "Remember why you started, and don't let the dream stop,\n"
      "Hustling is not easy, but it's worth the price,\n"
      "When you're doing what you love, it feels so nice.\n"
      "\n"
      "So keep pushing, keep working hard,\n"
      "Believe in yourself, and never let down your guard,\n"
      "You have the power to make your dreams come true,\n"
      "So keep hustling, and success will come to you.\n",

  "Life is a journey with twists and turns,\n"
      "But with hard work and dedication, you'll soon learn,\n"
      "That nothing worth having comes easy in life,\n"
      "So keep on pushing, even through the strife.\n"
      "\n"
      "Every setback is just a stepping stone,\n"
      "To greater things that are yet unknown,\n"
      "So keep hustling, keep working hard,\n"
      "And your dreams will take you far.\n",

];


class AutoScrollContainer extends StatefulWidget {
  final String nickname;
  const AutoScrollContainer({Key? key, required this.nickname}) : super(key: key);

  @override
  _AutoScrollContainerState createState() => _AutoScrollContainerState();
}

class _AutoScrollContainerState extends State<AutoScrollContainer> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _textHeight = ValueNotifier<double>(0);

  @override
  void dispose() {
    _scrollController.dispose();
    _textHeight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _nickname = widget.nickname;
    final Random random = Random();
    final int index = random.nextInt(poems.length);
    return Container(
      margin: EdgeInsets.all(16),
      height: 170,
      width: MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.lightGreen.withOpacity(0.5),
            spreadRadius: 5,
            blurRadius: 7,
            offset: Offset(0, 3), // changes position of shadow
          ),
        ],
        borderRadius: BorderRadius.circular(20),
        color: Colors.green,
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                "Hello, $_nickname A fresh poem to encourage you.",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: ValueListenableBuilder<double>(
                valueListenable: _textHeight,
                builder: (context, textHeight, child) {
                  if (textHeight > 6 * 14) {
                    // If the text height exceeds 6 lines (assuming 14pt font size)
                    _scrollController.animateTo(
                      _scrollController.initialScrollOffset,
                      duration: Duration(milliseconds: 80),
                      curve: Curves.easeInOut,
                    );
                  }
                  return SingleChildScrollView(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        AnimatedTextKit(
                          animatedTexts: [
                            TypewriterAnimatedText(
                              poems[index],
                              textStyle: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                fontStyle: FontStyle.italic
                              ),
                              speed: Duration(milliseconds: 80),
                            ),
                          ],
                          totalRepeatCount: 1,
                          //pause: Duration(seconds: 1),
                          onFinished: () {
                            // After the text animation finishes, reset the scroll position and text height
                            _scrollController.jumpTo(1);
                            _textHeight.value = 0;
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

