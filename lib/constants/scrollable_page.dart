import 'package:flutter/material.dart';

/// An abstract class defining the contract for a page that can be scrolled to the top.
abstract class ScrollablePage extends StatefulWidget {
  const ScrollablePage({super.key});
}

abstract class ScrollablePageState<T extends ScrollablePage> extends State<T> {
  /// A method that scrolls the content of the page to the top.
  void scrollToTop();
}
