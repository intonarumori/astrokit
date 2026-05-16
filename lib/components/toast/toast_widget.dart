import 'package:flutter/material.dart';

/// Simple widget representing the content of a toast.
class ToastWidget extends StatelessWidget {
  const ToastWidget({super.key, required this.title, this.leading, this.trailing});

  final Widget title;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        ?leading,
        Expanded(child: title),
        ?trailing,
      ],
    );
  }
}
