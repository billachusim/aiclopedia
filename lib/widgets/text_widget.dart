import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

class TextWidget extends StatelessWidget {
  const TextWidget(
      {Key? key,
      required this.label,
      this.fontSize = 18,
      this.color,
      this.fontWeight})
      : super(key: key);

  final String label;
  final double fontSize;
  final Color? color;
  final FontWeight? fontWeight;
  @override
  Widget build(BuildContext context) {
    return SelectableLinkify(
      text: label,
      onOpen: (link) async {
        final Uri url = Uri.parse("${link.url}");
        if (await canLaunchUrl(url)) {
          await launchUrl(url);
        } else {
          throw 'Could not launch $link';
        }
      },
      linkStyle: TextStyle(color: Colors.blue),
      style: TextStyle(
        color: color ?? Colors.white,
        fontSize: fontSize,
        fontWeight: fontWeight ?? FontWeight.w500,
      ),
    );
  }
}
