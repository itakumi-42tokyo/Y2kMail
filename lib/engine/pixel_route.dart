import 'package:flutter/widgets.dart';

// Material を使わない、トランジションなしの画面遷移ルート。
Route<T> pixelRoute<T>(WidgetBuilder builder) => PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
