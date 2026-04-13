import 'package:flutter/material.dart';

class AstroFloatingButton extends StatelessWidget {
  const AstroFloatingButton({super.key, required this.icon, required this.onPressed});

  final Widget icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(onPressed: onPressed, elevation: 2, shape: CircleBorder(), child: icon);
  }
}
