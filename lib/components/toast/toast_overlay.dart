import 'dart:async';
import 'package:flutter/material.dart';

import 'toast_widget.dart';

// NOTE: Vibe-coded with Claude.

const _defaultToastCurve = ElasticOutCurve(0.8);
const _defaultAnimationDuration = Duration(milliseconds: 400);
const _defaultPresentationDuration = Duration(milliseconds: 2000);

/// Controller interface for showing and dismissing toasts.
abstract class ToastOverlayController {
  /// Show a toast and return its ID, or return null if a toast with the same ID already exists.
  String? show({
    String? id,
    required Widget child,
    Duration duration = _defaultPresentationDuration,
    Curve curve = _defaultToastCurve,
    Duration animationDuration = _defaultAnimationDuration,
  });

  /// Dismiss a toast by its ID.
  Future<bool> dismiss(String id);

  /// Dismiss all toasts.
  Future<void> dismissAll();
}

class ToastOverlay extends StatefulWidget {
  const ToastOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<ToastOverlay> createState() => _ToastOverlayState();

  /// Look up the nearest [ToastOverlayController], or throw.
  static ToastOverlayController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(
      controller != null,
      'No ToastOverlay found in widget tree. Insert a ToastOverlay widget above this context, typically via MaterialApp.builder.',
    );
    return controller!;
  }

  /// Look up the nearest [ToastOverlayController], or return null.
  static ToastOverlayController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ToastInherited>()?.controller;
  }
}

class _ToastOverlayState extends State<ToastOverlay> with TickerProviderStateMixin implements ToastOverlayController {
  final List<_ToastEntry> _toasts = [];
  final GlobalKey<OverlayState> _overlayKey = GlobalKey<OverlayState>();
  int _idCounter = 0;

  OverlayState get _overlay => _overlayKey.currentState!;

  @override
  Widget build(BuildContext context) {
    return _ToastInherited(
      controller: this,
      child: Stack(
        children: [
          widget.child,
          Overlay(key: _overlayKey),
        ],
      ),
    );
  }

  @override
  String? show({
    String? id,
    required Widget child,
    Duration duration = _defaultPresentationDuration,
    Curve curve = _defaultToastCurve,
    Duration animationDuration = _defaultAnimationDuration,
  }) {
    final config = _ToastConfig(id: id, child: child, duration: duration, curve: curve, animationDuration: animationDuration);
    return _showToast(config);
  }

  String? _showToast(_ToastConfig config) {
    final toastId = config.id ?? 'toast_${_idCounter++}';

    // Check for existing toast with same ID, and return if it's already present
    final index = _toasts.indexWhere((e) => e.id == toastId);
    if (index > -1) return null;

    late final _ToastEntry entry;
    late final AnimationController controller;

    final overlayEntry = OverlayEntry(
      builder: (context) => _ToastOverlayWidget(
        entry: entry,
        index: _toasts.indexOf(entry),
        totalCount: _toasts.length,
        onSwipeDismiss: () => _removeEntry(toastId),
        onDismiss: () => dismiss(toastId),
      ),
    );

    controller = AnimationController(vsync: this, duration: config.animationDuration);

    entry = _ToastEntry(id: toastId, config: config, controller: controller, overlayEntry: overlayEntry);

    _toasts.add(entry);
    _overlay.insert(overlayEntry);
    _rebuildAllToasts();

    controller.forward();

    // Set up auto-dismiss timer
    if (config.duration > Duration.zero) {
      entry.dismissTimer = Timer(config.duration, () {
        dismiss(toastId);
      });
    }

    return toastId;
  }

  @override
  Future<bool> dismiss(String id) async {
    final index = _toasts.indexWhere((e) => e.id == id);
    if (index == -1) return false;

    final entry = _toasts[index];
    entry.dismissTimer?.cancel();

    await entry.controller.reverse();

    _removeEntry(id);
    return true;
  }

  /// Remove an entry immediately without reverse animation (used after swipe fling).
  void _removeEntry(String id) {
    final index = _toasts.indexWhere((e) => e.id == id);
    if (index == -1) return;

    final entry = _toasts.removeAt(index);
    entry.dismissTimer?.cancel();
    entry.overlayEntry.remove();
    entry.controller.dispose();
    _rebuildAllToasts();
  }

  @override
  Future<void> dismissAll() async {
    final ids = _toasts.map((e) => e.id).toList();
    await Future.wait(ids.map((id) => dismiss(id)));
  }

  @override
  void dispose() {
    for (final toast in _toasts) {
      toast.dismissTimer?.cancel();
      toast.controller.dispose();
      toast.overlayEntry.remove();
    }
    _toasts.clear();
    super.dispose();
  }

  void _rebuildAllToasts() {
    for (final toast in _toasts) {
      toast.overlayEntry.markNeedsBuild();
    }
  }
}

class _ToastInherited extends InheritedWidget {
  final ToastOverlayController controller;

  const _ToastInherited({required this.controller, required super.child});

  @override
  bool updateShouldNotify(_ToastInherited oldWidget) => controller != oldWidget.controller;
}

/// Configuration for a toast notification
class _ToastConfig {
  final String? id;
  final Widget child;
  final Duration duration;
  final Curve curve;
  final Duration animationDuration;

  const _ToastConfig({
    this.id,
    required this.child,
    this.duration = _defaultPresentationDuration,
    this.curve = _defaultToastCurve,
    this.animationDuration = _defaultAnimationDuration,
  });
}

/// Internal toast entry with animation controller
class _ToastEntry {
  final String id;
  final _ToastConfig config;
  final AnimationController controller;
  final OverlayEntry overlayEntry;
  Timer? dismissTimer;

  _ToastEntry({required this.id, required this.config, required this.controller, required this.overlayEntry});
}

class _ToastOverlayWidget extends StatefulWidget {
  final _ToastEntry entry;
  final int index;
  final int totalCount;
  final VoidCallback onSwipeDismiss;
  final VoidCallback onDismiss;

  const _ToastOverlayWidget({
    required this.entry,
    required this.index,
    required this.totalCount,
    required this.onSwipeDismiss,
    required this.onDismiss,
  });

  @override
  State<_ToastOverlayWidget> createState() => _ToastOverlayWidgetState();
}

class _ToastOverlayWidgetState extends State<_ToastOverlayWidget> with SingleTickerProviderStateMixin {
  double _dragOffsetY = 0;
  double _rawDragY = 0;
  late final AnimationController _flingController;
  double _flingStartY = 0;
  double _flingEndY = 0;
  Curve _flingCurve = Curves.linear;

  @override
  void initState() {
    super.initState();
    _flingController = AnimationController(vsync: this);
    _flingController.addListener(() {
      final t = _flingCurve.transform(_flingController.value);
      setState(() {
        _dragOffsetY = _flingStartY + (_flingEndY - _flingStartY) * t;
      });
    });
  }

  @override
  void dispose() {
    _flingController.dispose();
    super.dispose();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    _rawDragY += details.delta.dy;
    setState(() {
      if (_rawDragY <= 0) {
        _dragOffsetY = _rawDragY;
      } else {
        // Dampened downward drag: approaches 8pt asymptotically
        _dragOffsetY = 8.0 * _rawDragY / (_rawDragY + 40.0);
      }
    });
    // Cancel auto-dismiss timer on first drag
    widget.entry.dismissTimer?.cancel();
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dy;

    if (velocity < -200 || _dragOffsetY < -40) {
      // Fling dismiss
      final distance = (300 + _dragOffsetY).abs();
      final speed = velocity.abs().clamp(500.0, 3000.0);
      final durationMs = (distance / speed * 1000).clamp(100, 300).round();

      _flingStartY = _dragOffsetY;
      _flingEndY = -300;
      _rawDragY = 0;
      _flingCurve = Curves.easeIn;
      _flingController.duration = Duration(milliseconds: durationMs);
      _flingController.forward(from: 0).then((_) {
        widget.onSwipeDismiss();
      });
    } else {
      // Snap back with bounce
      _flingStartY = _dragOffsetY;
      _flingEndY = 0;
      _rawDragY = 0;
      _flingCurve = const ElasticOutCurve(0.8);
      _flingController.duration = const Duration(milliseconds: 400);
      _flingController.forward(from: 0).then((_) {
        _restartDismissTimer();
      });
    }
  }

  void _restartDismissTimer() {
    final entry = widget.entry;
    if (entry.config.duration > Duration.zero) {
      entry.dismissTimer = Timer(entry.config.duration, () {
        widget.onDismiss();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final stackOffset = widget.index * 8.0;

    return AnimatedPositioned(
      duration: widget.entry.config.animationDuration,
      curve: Curves.easeOutCubic,
      top: topPadding + 2 + stackOffset,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: widget.entry.controller,
        builder: (context, child) {
          final curvedAnimation = CurvedAnimation(parent: widget.entry.controller, curve: widget.entry.config.curve);

          final slideOffset = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(curvedAnimation);

          return GestureDetector(
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onVerticalDragEnd,
            child: Transform.translate(
              offset: Offset(0, _dragOffsetY),
              child: Center(
                child: IntrinsicWidth(
                  child: SlideTransition(position: slideOffset, child: child),
                ),
              ),
            ),
          );
        },
        child: _ToastContainer(child: widget.entry.config.child),
      ),
    );
  }
}

class _ToastContainer extends StatelessWidget {
  final Widget child;

  const _ToastContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceBright,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      elevation: 4,
      shadowColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.black.withValues(alpha: 0.6)
          : Colors.black.withValues(alpha: 0.25),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: child),
    );
  }
}

/// Extension to present toasts from any BuildContext with convenience methods.
extension ToastExtension on BuildContext {
  /// Show a toast notification
  String? showToast({
    String? id,
    required Widget title,
    Widget? leading,
    Widget? trailing,
    Duration duration = _defaultPresentationDuration,
    Curve curve = _defaultToastCurve,
  }) => ToastOverlay.of(this).show(
    id: id,
    child: ToastWidget(title: title, leading: leading, trailing: trailing),
    duration: duration,
    curve: curve,
  );

  String? showCustomToast({
    String? id,
    required Widget widget,
    Duration duration = _defaultPresentationDuration,
    Curve curve = _defaultToastCurve,
  }) => ToastOverlay.of(this).show(id: id, child: widget, duration: duration, curve: curve);

  /// Dismiss a toast by ID
  Future<bool> dismissToast(String id) => ToastOverlay.of(this).dismiss(id);

  /// Dismiss all toasts
  Future<void> dismissAllToasts() => ToastOverlay.of(this).dismissAll();
}
