import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../popup/popup_scope.dart';

/// A grid menu item with an icon, label, and tap action.
final class GridMenuItem {
  final String title;
  final Widget icon;
  final VoidCallback onTap;
  final bool destructive;

  const GridMenuItem({required this.title, required this.icon, required this.onTap, this.destructive = false});
}

/// A widget that displays a menu with items arranged in a grid.
///
/// The number of columns is configurable via [columns]. Items flow left-to-right,
/// top-to-bottom; the last row is left-aligned and padded with empty cells.
class GridMenu extends StatelessWidget {
  const GridMenu({super.key, required this.columns, required this.itemsBuilder, this.semanticLabel})
    : assert(columns > 0, 'columns must be greater than 0');

  final int columns;
  final List<GridMenuItem> Function(BuildContext context) itemsBuilder;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final items = itemsBuilder(context);
    final tableRows = <TableRow>[];
    for (var i = 0; i < items.length; i += columns) {
      final cells = <Widget>[];
      for (var j = 0; j < columns; j++) {
        final index = i + j;
        if (index < items.length) {
          final item = items[index];
          cells.add(
            _GridMenuItem(
              icon: item.icon,
              label: item.title,
              destructive: item.destructive,
              onTap: () {
                item.onTap();
                PopupScope.of(context).dismiss();
              },
            ),
          );
        } else {
          cells.add(const SizedBox.shrink());
        }
      }
      tableRows.add(TableRow(children: cells));
    }

    return Semantics(
      role: SemanticsRole.menu,
      explicitChildNodes: true,
      label: semanticLabel,
      child: IntrinsicWidth(
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: tableRows,
        ),
      ),
    );
  }
}

/// Internal widget representing a single cell in the grid menu.
class _GridMenuItem extends StatefulWidget {
  final Widget icon;
  final String label;
  final bool destructive;
  final VoidCallback onTap;

  const _GridMenuItem({required this.icon, required this.label, this.destructive = false, required this.onTap});

  @override
  State<_GridMenuItem> createState() => _GridMenuItemState();
}

class _GridMenuItemState extends State<_GridMenuItem> {
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
        borderRadius: BorderRadius.circular(16),
        splashFactory: NoSplash.splashFactory,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 8,
            children: [
              ExcludeSemantics(
                child: SizedBox(
                  height: 28,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: ColorFiltered(colorFilter: ColorFilter.mode(color, BlendMode.srcIn), child: widget.icon),
                  ),
                ),
              ),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
