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
}
