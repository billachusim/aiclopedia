import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ImageWidget extends StatelessWidget {
  final String msg;

  const ImageWidget({
    Key? key, required this.msg,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {

    return CachedNetworkImage(
        imageUrl: msg,
        imageBuilder: (context, imageProvider) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            image: DecorationImage(
              image: imageProvider,
              //fit: BoxFit.fill,
            ),
          ),
        ),
        placeholder: (context, url) =>
            Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => Image.asset(
          "assets/images/Speak_No_Evil_Monkey_Emoji.png",
          width: 48,
          height: 48,
        ) //Icon(Icons.error),
    );
  }

}