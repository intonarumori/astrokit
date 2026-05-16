import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../popup/popup_scope.dart';

/// Abstract class representing an entry in the context menu.
abstract class ContextMenuEntry {
  const ContextMenuEntry();
}

/// A menu item with an icon, label, and tap action.
final class ContextMenuItem extends ContextMenuEntry {
  final String title;
  final Widget icon;
  final VoidCallback onTap;
  final bool destructive;

  const ContextMenuItem({required this.title, required this.icon, required this.onTap, this.destructive = false});
}

/// A divider used to separate groups of context menu items.
final class ContextMenuDivider extends ContextMenuEntry {
  const ContextMenuDivider();
}

/// A widget that displays a context menu with a list of items.
class ContextMenu extends StatelessWidget {
  const ContextMenu({super.key, required this.itemsBuilder, this.semanticLabel});

  final List<ContextMenuEntry> Function(BuildContext context) itemsBuilder;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final items = itemsBuilder(context);
    return Semantics(
      role: SemanticsRole.menu,
      explicitChildNodes: true,
      label: semanticLabel,
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: items.map<Widget>((item) {
            switch (item) {
              case ContextMenuDivider():
                return Divider(height: 10, endIndent: 12, indent: 12);
              case ContextMenuItem():
                return _MenuItem(
                  icon: item.icon,
                  label: item.title,
                  destructive: item.destructive,
                  onTap: () {
                    item.onTap();
                    PopupScope.of(context).dismiss();
                  },
                );
              default:
                return SizedBox.shrink();
            }
          }).toList(),
        ),
      ),
    );
  }
}

/// Internal widget representing a single menu item in the context menu.
class _MenuItem extends StatefulWidget {
  final Widget icon;
  final String label;
  final bool destructive;
  final VoidCallback onTap;

  const _MenuItem({required this.icon, required this.label, this.destructive = false, required this.onTap});

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  final _key = GlobalKey();
  final _focusNode = FocusNode();
  bool _hovered = false;
  bool _focused = false;
  PopupScope? _scope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newScope = PopupScope.maybeOf(context);
    if (newScope != _scope) {
      _scope?.pointerPosition.removeListener(_onPointerMove);
      _scope?.selectTriggered.removeListener(_onSelect);
      _scope = newScope;
      _scope?.pointerPosition.addListener(_onPointerMove);
      _scope?.selectTriggered.addListener(_onSelect);
    }
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _scope?.pointerPosition.removeListener(_onPointerMove);
    _scope?.selectTriggered.removeListener(_onSelect);
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus != _focused) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  void _onPointerMove() {
    final scope = PopupScope.maybeOf(context);
    final pos = scope?.pointerPosition.value;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final topLeft = box.localToGlobal(Offset.zero);
    final rect = topLeft & box.size;
    final isHovered = pos != null && rect.contains(pos);
    if (isHovered != _hovered) {
      setState(() => _hovered = isHovered);
      if (isHovered && (_scope?.hapticFeedback ?? false)) HapticFeedback.selectionClick();
    }
  }

  void _onSelect() {
    final scope = PopupScope.maybeOf(context);
    if (scope?.selectTriggered.value == true && _hovered) {
      widget.onTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.destructive ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurface;
    final highlighted = _hovered || _focused;
    final bgColor = highlighted ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1) : Colors.transparent;
    return Semantics(
      role: SemanticsRole.menuItem,
      enabled: true,
      button: true,
      child: InkWell(
        key: _key,
        focusNode: _focusNode,
        canRequestFocus: true,
        borderRadius: BorderRadius.circular(30),
        splashFactory: NoSplash.splashFactory,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(30)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 12,
            children: [
              ExcludeSemantics(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Center(
                    child: ColorFiltered(colorFilter: ColorFilter.mode(color, BlendMode.srcIn), child: widget.icon),
                  ),
                ),
              ),
              Text(widget.label, style: TextStyle(fontSize: 16, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
