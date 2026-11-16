// Renders the answer and chat widgets in the light and dark app themes so
// formatting (headings, bold, bullets, links) can be checked without a device.
//
// Screenshots are written only when UI_SHOTS_DIR is set, e.g.
//   UI_SHOTS_DIR=/tmp/shots flutter test test/ui_render_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_clopedia/app_theme.dart';
import 'package:ai_clopedia/widgets/chat_widget.dart';
import 'package:ai_clopedia/widgets/markdown_answer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const sampleAnswer = '''
## Photosynthesis

Plants turn **light energy** into chemical energy stored in *glucose*.

- Takes place in the **chloroplasts**
- Needs water, carbon dioxide and sunlight
- Releases oxygen as a by-product

Read more on [Wikipedia](https://en.wikipedia.org/wiki/Photosynthesis).
''';

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  if (!Directory(dir).existsSync()) return; // fall back to the test font
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final file = File('$dir/$f');
      if (file.existsSync()) {
        loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      }
    }
    await loader.load();
  }

  await load('Roboto', ['Roboto-Regular.ttf', 'Roboto-Bold.ttf', 'Roboto-Italic.ttf', 'Roboto-Medium.ttf']);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

/// Mirrors AppTheme's light/dark colours with Roboto in place of Google Fonts
/// (AppTheme's static themes would try to download Outfit, and tests have no
/// network).
ThemeData _theme(Brightness b) {
  final light = b == Brightness.light;
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    fontFamily: 'Roboto',
    primaryColor: AppTheme.primaryGreen,
    scaffoldBackgroundColor: light ? AppTheme.lightBackground : AppTheme.darkBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppTheme.primaryGreen,
      brightness: b,
      primary: AppTheme.primaryGreen,
      secondary: AppTheme.accentPink,
      surface: light ? Colors.white : const Color(0xFF1E293B),
      onSurface: light ? const Color(0xFF1E293B) : Colors.white,
    ),
  );
}

Widget _host(Brightness b, Widget child, GlobalKey key) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _theme(b),
      home: Scaffold(
        body: RepaintBoundary(
          key: key,
          child: Container(
            color: _theme(b).scaffoldBackgroundColor,
            child: SingleChildScrollView(child: child),
          ),
        ),
      ),
    );

Future<void> _shot(WidgetTester tester, GlobalKey key, String name) async {
  final dir = Platform.environment['UI_SHOTS_DIR'];
  if (dir == null || dir.isEmpty) return;
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(dir).createSync(recursive: true);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(_loadFonts);

  for (final b in Brightness.values) {
    final mode = b == Brightness.light ? 'light' : 'dark';

    testWidgets('MarkdownAnswer renders formatted text ($mode)', (tester) async {
      tester.view.physicalSize = const Size(780, 1200);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(_host(
          b, const Padding(padding: EdgeInsets.all(16), child: MarkdownAnswer(data: sampleAnswer)), key));
      await tester.pumpAndSettle();

      expect(find.textContaining('**'), findsNothing);
      expect(find.textContaining('##'), findsNothing);
      expect(find.textContaining('Photosynthesis', findRichText: true), findsWidgets);
      expect(find.textContaining('Wikipedia', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _shot(tester, key, 'markdown_answer_$mode');
    });

    testWidgets('ChatWidget shows question and formatted reply ($mode)', (tester) async {
      tester.view.physicalSize = const Size(780, 1400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(_host(
          b,
          const Column(children: [
            ChatWidget(msg: 'How does photosynthesis work?', chatIndex: 0),
            ChatWidget(msg: sampleAnswer, chatIndex: 1, prompt: 'How does photosynthesis work?'),
          ]),
          key));
      await tester.pumpAndSettle();

      expect(find.textContaining('**'), findsNothing);
      expect(find.byTooltip('Copy'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _shot(tester, key, 'chat_$mode');

      // Copy puts plain text (no markdown symbols) on the clipboard.
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      await tester.tap(find.byTooltip('Copy'));
      await tester.pumpAndSettle();
      expect(copied, isNotNull);
      expect(copied, contains('Photosynthesis'));
      expect(copied, isNot(contains('**')));
      expect(find.text('Answer copied.'), findsOneWidget);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });
  }
}
