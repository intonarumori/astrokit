import 'dart:math';
import 'popup_scope.dart';
import '../utilities/curves.dart';
import '../utilities/screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

class DropdownPopup extends StatefulWidget {
  final GlobalKey? anchorKey;
  final WidgetBuilder contentBuilder;
  final Widget Function(BuildContext context, VoidCallback showPopup) buttonBuilder;
  final Color? backgroundColor;
  final EdgeInsets contentPadding;
  final double contentRadius;
  final BoxDecoration? contentDecoration;
  final VoidCallback? onBeforePopup;
  final VoidCallback? onAfterPopup;

  /// Preferred placement of the popup relative to the source button. The `x`
  /// component selects horizontal alignment (`-1` start, `0` center, `+1` end)
  /// and the `y` component selects vertical placement (`< 0` above, `>= 0`
  /// below). The popup falls back to the opposite side when the preferred
  /// placement would overflow the viewport.
  final AlignmentGeometry preferredAlignment;

  final Duration animationDuration;
  final Duration dismissDuration;
  final Curve animationCurve;
  final Curve dismissCurve;
  final bool hapticFeedback;
  final bool longPressToOpen;
  final String? semanticLabel;

  const DropdownPopup({
    super.key,
    required this.contentBuilder,
    required this.buttonBuilder,
    this.anchorKey,
    this.backgroundColor,
    this.contentPadding = const EdgeInsets.all(8),
    this.contentRadius = 16,
    this.contentDecoration,
    this.onBeforePopup,
    this.onAfterPopup,
    this.preferredAlignment = AlignmentDirectional.bottomStart,
    this.animationDuration = const Duration(milliseconds: 300),
    this.dismissDuration = const Duration(milliseconds: 200),
    this.animationCurve = const SpringCurve(),
    this.dismissCurve = Curves.easeIn,
    this.hapticFeedback = true,
    this.longPressToOpen = false,
    this.semanticLabel,
  });

  @override
  State<DropdownPopup> createState() => DropdownPopupState();
}

class DropdownPopupState extends State<DropdownPopup> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const double _dragThreshold = 5.0;
  bool _openedViaLongPress = false;
  bool _dragActive = false;
  Offset? _longPressOrigin;
  OverlayEntry? _barrierEntry;
  OverlayEntry? _popupEntry;
  late final AnimationController _animationController;
  final _focusScopeNode = FocusScopeNode(debugLabel: 'DropdownPopup');
  final _pointerPosition = ValueNotifier<Offset?>(null);
  final _selectTriggered = ValueNotifier<bool>(false);
  FocusNode? _previousFocus;
  Size _lastKnownSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: widget.animationDuration, reverseDuration: widget.dismissDuration);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _barrierEntry?.remove();
    _barrierEntry?.dispose();
    _barrierEntry = null;
    _popupEntry?.remove();
    _popupEntry?.dispose();
    _popupEntry = null;
    _animationController.dispose();
    _focusScopeNode.dispose();
    _pointerPosition.dispose();
    _selectTriggered.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final newSize = MediaQuery.of(context).size;
      if (newSize == _lastKnownSize) return;

      _lastKnownSize = newSize;
      if (isOpen && mounted) _dismiss(animate: false);
    });
  }

  bool get isOpen => _popupEntry != null;

  void show() {
    if (isOpen) return;

    final anchor = widget.anchorKey?.currentContext ?? context;
    final renderBox = anchor.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(renderBox.paintBounds.topLeft);
    final targetRect = offset & renderBox.paintBounds.size;

    _previousFocus = FocusManager.instance.primaryFocus;
    widget.onBeforePopup?.call();
    if (widget.hapticFeedback) HapticFeedback.mediumImpact();

    final overlay = Overlay.of(context);
    final popupKey = GlobalKey();

    _barrierEntry = OverlayEntry(
      builder: (context) => ExcludeSemantics(
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            final popupRect = _getRect(popupKey);
            if (popupRect == null || !popupRect.contains(event.position)) {
              _dismiss();
            }
          },
          onPointerMove: (event) {
            _pointerPosition.value = event.position;
          },
          onPointerUp: (event) {
            if (_pointerPosition.value != null) {
              _selectTriggered.value = true;
              Future.microtask(() {
                _selectTriggered.value = false;
                _pointerPosition.value = null;
                if (_openedViaLongPress) _dismiss();
              });
            }
          },
          onPointerSignal: (_) => _dismiss(),
        ),
      ),
    );

    _popupEntry = OverlayEntry(
      builder: (context) => FocusScope(
        node: _focusScopeNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            _dismiss();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _dismiss();
          },
          child: PopupScope(
            dismiss: _dismiss,
            pointerPosition: _pointerPosition,
            selectTriggered: _selectTriggered,
            hapticFeedback: widget.hapticFeedback,
            focusScopeNode: _focusScopeNode,
            child: _DropdownPopupOverlay(
              popupKey: popupKey,
              targetRect: targetRect,
              preferredAlignment: widget.preferredAlignment,
              animation: _animationController,
              curve: widget.animationCurve,
              reverseCurve: widget.dismissCurve,
              backgroundColor: widget.backgroundColor,
              contentPadding: widget.contentPadding,
              contentRadius: widget.contentRadius,
              contentDecoration: widget.contentDecoration,
              pointerPosition: _pointerPosition,
              selectTriggered: _selectTriggered,
              semanticLabel: widget.semanticLabel ?? 'Menu',
              child: widget.contentBuilder(context),
            ),
          ),
        ),
      ),
    );

    overlay.insertAll([_barrierEntry!, _popupEntry!]);
    _animationController.forward();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _focusScopeNode.requestFocus();
    });
  }

  void _dismiss({bool animate = true}) {
    if (!isOpen) return;

    if (animate) {
      _animationController.reverse().then((_) => _removeEntries());
    } else {
      _animationController.reset();
      _removeEntries();
    }
  }

  void _removeEntries() {
    _barrierEntry?.remove();
    _barrierEntry?.dispose();
    _barrierEntry = null;
    _popupEntry?.remove();
    _popupEntry?.dispose();
    _popupEntry = null;
    _openedViaLongPress = false;
    _dragActive = false;
    _longPressOrigin = null;
    _pointerPosition.value = null;
    _previousFocus?.requestFocus();
    _previousFocus = null;
    widget.onAfterPopup?.call();
  }

  Rect? _getRect(GlobalKey key) {
    final currentContext = key.currentContext;
    final renderBox = currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || currentContext == null) return null;
    final offset = renderBox.localToGlobal(renderBox.paintBounds.topLeft);
    return offset & renderBox.paintBounds.size;
  }

  @override
  Widget build(BuildContext context) {
    Widget child = widget.buttonBuilder(context, show);

    if (widget.longPressToOpen) {
      child = GestureDetector(
        onLongPressStart: (details) {
          _openedViaLongPress = true;
          _dragActive = false;
          _longPressOrigin = details.globalPosition;
          show();
        },
        onLongPressMoveUpdate: (details) {
          if (!_dragActive && _longPressOrigin != null) {
            if ((details.globalPosition - _longPressOrigin!).distance >= _dragThreshold) {
              _dragActive = true;
            }
          }
          if (_dragActive) {
            _pointerPosition.value = details.globalPosition;
          }
        },
        onLongPressEnd: (details) {
          if (!isOpen) return;
          if (_dragActive) {
            _pointerPosition.value = details.globalPosition;
            _selectTriggered.value = true;
          }
          Future.microtask(() {
            _selectTriggered.value = false;
            _pointerPosition.value = null;
            _dismiss();
          });
        },
        child: child,
      );
    }

    return child;
  }
}

class _DropdownPopupOverlay extends StatefulWidget {
  final GlobalKey popupKey;
  final Rect targetRect;
  final AlignmentGeometry preferredAlignment;
  final Animation<double> animation;
  final Curve curve;
  final Curve reverseCurve;
  final Color? backgroundColor;
  final EdgeInsets contentPadding;
  final double contentRadius;
  final BoxDecoration? contentDecoration;
  final ValueNotifier<Offset?> pointerPosition;
  final ValueNotifier<bool> selectTriggered;
  final String semanticLabel;
  final Widget child;

  const _DropdownPopupOverlay({
    required this.popupKey,
    required this.targetRect,
    required this.preferredAlignment,
    required this.animation,
    required this.curve,
    required this.reverseCurve,
    this.backgroundColor,
    required this.contentPadding,
    required this.contentRadius,
    this.contentDecoration,
    required this.pointerPosition,
    required this.selectTriggered,
    required this.semanticLabel,
    required this.child,
  });

  @override
  State<_DropdownPopupOverlay> createState() => _DropdownPopupOverlayState();
}

class _DropdownPopupOverlayState extends State<_DropdownPopupOverlay> {
  static const double _margin = 10;
  static const double _gap = 4;
  static Rect get _viewportRect => Rect.fromLTWH(
    Screen.leftInset + _margin,
    Screen.statusBar + _margin,
    Screen.width - Screen.leftInset - Screen.rightInset - _margin * 2,
    Screen.height - Screen.statusBar - Screen.bottomBar - _margin * 2,
  );

  late double _maxHeight = _viewportRect.height;
  Alignment _scaleAlignment = Alignment.topLeft;
  double? _bottom;
  double? _top;
  double? _left;
  double? _right;
  bool _positioned = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _calculatePosition();
      setState(() => _positioned = true);
    });
  }

  void _calculatePosition() {
    final currentContext = widget.popupKey.currentContext;
    final renderBox = currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || currentContext == null) return;
    final offset = renderBox.localToGlobal(renderBox.paintBounds.topLeft);
    var childRect = offset & renderBox.paintBounds.size;

    final textDirection = Directionality.of(currentContext);
    if (textDirection == TextDirection.rtl) {
      childRect = Rect.fromLTRB(0, childRect.top, childRect.right - childRect.left, childRect.bottom);
    }

    final popupWidth = min(childRect.width, _viewportRect.width);
    final popupHeight = childRect.height;

    final preferred = widget.preferredAlignment.resolve(textDirection);

    // Vertical: try the preferred side, fall back when it overflows.
    final spaceBelow = _viewportRect.bottom - widget.targetRect.bottom - _gap;
    final spaceAbove = widget.targetRect.top - _gap - _viewportRect.top;
    final fitsBelow = popupHeight <= spaceBelow;
    final fitsAbove = popupHeight <= spaceAbove;
    final preferBelow = preferred.y >= 0;
    final placedBelow = preferBelow ? fitsBelow || spaceBelow >= spaceAbove : !fitsAbove && spaceBelow > spaceAbove;

    double popupTop;
    if (placedBelow) {
      _maxHeight = min(popupHeight, spaceBelow);
      popupTop = widget.targetRect.bottom + _gap;
    } else {
      _maxHeight = min(popupHeight, spaceAbove);
      popupTop = widget.targetRect.top - _gap - _maxHeight;
    }

    // Horizontal: try the preferred alignment first, fall back when it overflows.
    final startLeft = widget.targetRect.left;
    final endLeft = widget.targetRect.right - popupWidth;
    final centerLeft = widget.targetRect.center.dx - popupWidth / 2;

    bool fits(double left) => left >= _viewportRect.left && left + popupWidth <= _viewportRect.right;

    double popupLeft;
    if (preferred.x < 0) {
      popupLeft = fits(startLeft) ? startLeft : endLeft;
    } else if (preferred.x > 0) {
      popupLeft = fits(endLeft) ? endLeft : startLeft;
    } else if (fits(centerLeft)) {
      popupLeft = centerLeft;
    } else {
      popupLeft = widget.targetRect.center.dx > Screen.width / 2 ? endLeft : startLeft;
    }

    // Clamp final position so the popup stays at least _margin points from every viewport edge
    popupLeft = popupLeft.clamp(_viewportRect.left, _viewportRect.right - popupWidth);
    popupTop = popupTop.clamp(_viewportRect.top, _viewportRect.bottom - _maxHeight);

    _left = popupLeft;
    _top = popupTop;
    _right = null;
    _bottom = null;

    // Scale alignment: grow from the popup edge nearest the button, anchored
    // horizontally at the button's centre so the animation reads as coming
    // from the button itself even after viewport clamping.
    final horizontalAlignment = ((widget.targetRect.center.dx - popupLeft) / popupWidth * 2 - 1).clamp(-1.0, 1.0);
    final verticalAlignment = placedBelow ? -1.0 : 1.0;
    _scaleAlignment = Alignment(horizontalAlignment, verticalAlignment);
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(widget.contentRadius);
    final bgColor = widget.backgroundColor ?? Theme.of(context).colorScheme.surfaceBright;

    final content = Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: widget.semanticLabel,
      child: Material(
        key: widget.popupKey,
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
        elevation: 4,
        shadowColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.black.withValues(alpha: 0.6)
            : Colors.black.withValues(alpha: 0.25),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 50),
          child: Padding(padding: widget.contentPadding, child: widget.child),
        ),
      ),
    );

    if (!_positioned) {
      return Offstage(child: UnconstrainedBox(child: content));
    }

    final curvedAnimation = CurvedAnimation(parent: widget.animation, curve: widget.curve, reverseCurve: widget.reverseCurve);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerMove: (event) {
        widget.pointerPosition.value = event.position;
      },
      onPointerUp: (event) {
        if (widget.pointerPosition.value != null) {
          widget.selectTriggered.value = true;
          Future.microtask(() {
            widget.selectTriggered.value = false;
          });
        }
      },
      child: Stack(
        children: [
          Positioned(
            left: _left,
            right: _right,
            top: _top,
            bottom: _bottom,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _viewportRect.width, maxHeight: _maxHeight),
              child: FadeTransition(
                opacity: curvedAnimation,
                child: ScaleTransition(alignment: _scaleAlignment, scale: curvedAnimation, child: content),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
