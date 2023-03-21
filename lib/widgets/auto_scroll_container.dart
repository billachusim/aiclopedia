import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

class AutoScrollContainer extends StatefulWidget {
  const AutoScrollContainer({Key? key}) : super(key: key);

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
    return Container(
      margin: EdgeInsets.all(16),
      height: 130,
      width: MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Colors.green,
      ),
      child: Padding(
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
              controller: _scrollController,
              child: AnimatedTextKit(
                animatedTexts: [
                  TypewriterAnimatedText(
                    "Verse 1:\n"
                        "You may be grinding hard every day,\n"
                        "Wondering if the hustle will ever pay,\n"
                        "But keep pushing, keep grinding,\n"
                        "'Cause the big payday is just behind it.\n"
                        "\n"
                        "Chorus:\n"
                        "Hustle and grind, every single day,\n"
                        "It may seem small now, but it'll pay,\n"
                        "Keep pushing forward, don't back down,\n"
                        "The big payday is just around the town.\n"
                        "\n"
                        "Verse 2:\n"
                        "Small beginnings lead to bigger things,\n"
                        "So don't let the little stuff hold you back,\n"
                        "Keep grinding and pushing forward,\n"
                        "Soon enough, you'll be on the track.\n"
                        "\n"
                        "Chorus:\n"
                        "Hustle and grind, every single day,\n"
                        "It may seem small now, but it'll pay,\n"
                        "Keep pushing forward, don't back down,\n"
                        "The big payday is just around the town.\n"
                        "\n",
                    textStyle: TextStyle(fontSize: 14),
                    speed: Duration(milliseconds: 80),
                  ),
                ],
                totalRepeatCount: 1,
                //pause: Duration(seconds: 1),
                onFinished: () {
                  // After the text animation finishes, reset the scroll position and text height
                  _scrollController.jumpTo(0);
                  _textHeight.value = 0;
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

