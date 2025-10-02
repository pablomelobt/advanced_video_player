import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:advanced_video_player/advanced_video_player.dart';

void main() {
  testWidgets('AdvancedVideoPlayer widget test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdvancedVideoPlayer(
            videoSource: 'https://example.com/test.mp4',
          ),
        ),
      ),
    );

    // Verify that the widget builds without errors
    expect(find.byType(AdvancedVideoPlayer), findsOneWidget);
  });
}
