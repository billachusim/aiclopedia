import 'package:flutter/material.dart';
import 'helper.dart';

class DefaultButton extends StatelessWidget {
  const DefaultButton({
    Key? key,
    this.text,
    this.press,
    this.disabled = false, // Add a disabled property to track the button's state
  }) : super(key: key);

  final String? text;
  final Function? press;
  final bool disabled; // Add a disabled property to track the button's state

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: getDeviceWidth(context),
      height: 50,
      child: TextButton(
        style: TextButton.styleFrom(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          primary: Colors.black12,
          backgroundColor: disabled ? Colors.black12 : Colors.green, // Set the button's background color
        ),
        onPressed: disabled ? null : press as void Function()?, // Disable the button if it's disabled
        child: Text(
          text!,
          style: TextStyle(
            fontSize: 18,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
