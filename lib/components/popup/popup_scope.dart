import 'package:flutter/material.dart';

class PopupScope extends InheritedWidget {
  final VoidCallback dismiss;
  final ValueNotifier<Offset?> pointerPosition;
  final ValueNotifier<bool> selectTriggered;
  final bool hapticFeedback;
  final FocusScopeNode? focusScopeNode;

  const PopupScope({
    super.key,
    required this.dismiss,
    required this.pointerPosition,
    required this.selectTriggered,
    this.hapticFeedback = true,
    this.focusScopeNode,
    required super.child,
  });

  static PopupScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PopupScope>();
  }

  static PopupScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'No ExpandingPopupScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(PopupScope oldWidget) => dismiss != oldWidget.dismiss;
}
