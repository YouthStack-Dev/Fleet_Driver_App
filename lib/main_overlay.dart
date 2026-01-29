import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

// Entry point for the overlay
@pragma("vm:entry-point")
void overlayMain() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlayWidget(),
  ));
}

class OverlayWidget extends StatelessWidget {
  const OverlayWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: GestureDetector(
          onTap: () async {
            // On tap, open the app and close the overlay (optional, or keep generic)
            // Note: flutter_overlay_window specific sharing might differ.
            // Usually tapping the overlay brings app to front if configured or via intent.
            // Using a simple method provided by the plugin if available, mostly it is implicit for focus.
            // We can try to resize or just listen to events.
            // Standard behavior: 
             await FlutterOverlayWindow.shareData('open_app');
          },
          onDoubleTap: () {
             // Example action
          },
          child: Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF), // App Primary Color
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: const Icon(
              Icons.directions_car,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }
}
