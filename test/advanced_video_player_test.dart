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
            videoSource:
                'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
            enableScreenSharing:
                false, // Disable to avoid timer issues in tests
            enablePictureInPicture:
                false, // Disable to avoid timer issues in tests
            enableAirPlay: false, // Disable to avoid timer issues in tests
          ),
        ),
      ),
    );

    // Wait for any async operations to complete
    await tester.pumpAndSettle();

    // Verify that the widget builds without errors
    expect(find.byType(AdvancedVideoPlayer), findsOneWidget);

    // Clean up by disposing the widget
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
