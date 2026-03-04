// App/frontend/mobile/lib/app/main_tab_navigation.dart
import 'package:flutter/widgets.dart';

class NavigateToMainTabNotification extends Notification {
  final int index;

  NavigateToMainTabNotification(this.index);
}
