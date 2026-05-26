import 'package:flutter/material.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static void navigateTo(String routeName) {
    if (navigatorKey.currentState != null) {
      print('🧭 NavigationService: Pushing named and remove until: $routeName');
      navigatorKey.currentState!.pushNamedAndRemoveUntil(routeName, (route) => false);
    } else {
      print('❌ NavigationService: navigatorKey.currentState is NULL!');
    }
  }

  // ---------------------------------------------------------------------------
  // Chat screen visibility tracker
  // ---------------------------------------------------------------------------
  // Tracks which booking IDs currently have their chat screen open.
  // Used by PushNotificationService to suppress redundant notification banners
  // when the Firebase RTDB listener is already showing messages live.

  static final Set<int> _openChatBookings = {};

  /// Call from ChatScreen.initState when the chat screen becomes visible.
  static void markChatOpen(int bookingId) => _openChatBookings.add(bookingId);

  /// Call from ChatScreen.dispose when the chat screen is closed.
  static void markChatClosed(int bookingId) => _openChatBookings.remove(bookingId);

  /// Returns true if a chat screen for [bookingId] is currently on screen.
  static bool isChatOpen(int bookingId) => _openChatBookings.contains(bookingId);
}
