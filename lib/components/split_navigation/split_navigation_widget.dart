import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'split_navigation_controller.dart';

/// A responsive split navigation widget that adapts its layout and behavior based on available width.
///
/// Operates in three modes based on available width:
///
/// - **Wide** (≥ [breakpoint]): sidebar overlays the content from the left,
///   togglable via the [controller]. Starts open. The content's left safe-area
///   inset is adjusted so widgets are not hidden behind the sidebar.
/// - **Tablet** (≥ [tabletBreakpoint] and < [breakpoint]): same overlay
///   behaviour as wide, but starts closed and the sidebar is displayed in a
///   floating squircle container with a frosted-glass backdrop.
/// - **Phone** (< [tabletBreakpoint]): the sidebar pushes the content to the
///   right, filling the screen minus 80 pt, with a dimmed scrim.
///
/// ```dart
/// SplitNavigationWidget(
///   sidebar: NavigationList(),
///   child: Navigator(onGenerateRoute: ...),
/// )
/// ```
class SplitNavigationWidget extends StatefulWidget {
  const SplitNavigationWidget({
    super.key,
    required this.sidebar,
    required this.child,
    this.sidebarWidth = 304,
    this.breakpoint = 1024,
    this.tabletBreakpoint = 600,
    this.controller,
    this.scrimColor,
    this.animationDuration = const Duration(milliseconds: 350),
    this.edgeDragWidth = 20,
  });

  /// The sidebar content, displayed on the left.
  final Widget sidebar;

  /// The main content.
  final Widget child;

  /// The width of the sidebar panel. Defaults to 304.
  final double sidebarWidth;

  /// The minimum available width at which the sidebar starts open and uses the
  /// wide visual style. Defaults to 1024 (above all iPad portrait widths).
  final double breakpoint;

  /// The minimum available width at which the floating tablet style is used
  /// instead of the edge-aligned phone style. Defaults to 600.
  final double tabletBreakpoint;

  /// Optional controller for programmatic open/close.
  /// If null, an internal controller is created and disposed automatically.
  final SplitNavigationController? controller;

  /// The color of the scrim overlay when the sidebar is open (phone only).
  /// Defaults to `ColorScheme.scrim` with 0.32 alpha.
  final Color? scrimColor;

  /// Duration of the sidebar slide animation. Defaults to 350 ms.
  final Duration animationDuration;

  /// The width of the invisible left-edge region that responds to horizontal
  /// drag gestures to open the sidebar. Defaults to 20.
  final double edgeDragWidth;

  /// Look up the nearest [SplitNavigationController], or throw.
  static SplitNavigationController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(
      controller != null,
      'No SplitNavigationWidget found in widget tree. '
      'Ensure there is a SplitNavigationWidget ancestor above this context.',
    );
    return controller!;
  }

  /// Look up the nearest [SplitNavigationController], or return null.
  static SplitNavigationController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_SplitNavigationScope>()?.controller;
  }

  @override
  State<SplitNavigationWidget> createState() => _SplitNavigationWidgetState();
}

/// The margin around the floating sidebar in tablet mode.
const double _kFloatingMargin = 8;

/// Squircle border radius for the sidebar.
const _kSquircleRadius = BorderRadius.all(Radius.circular(25));

class _SplitNavigationWidgetState extends State<SplitNavigationWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late SplitNavigationController _controller;
  bool _ownsController = false;

  _LayoutMode? _previousMode;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: widget.animationDuration);
    _initController();
  }

  @override
  void didUpdateWidget(SplitNavigationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _disposeController();
      _initController();
    }
    if (widget.animationDuration != oldWidget.animationDuration) {
      _animationController.duration = widget.animationDuration;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _disposeController();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Controller ownership
  // ---------------------------------------------------------------------------

  void _initController() {
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      _controller = SplitNavigationController();
      _ownsController = true;
    }
    _controller.attach(onOpen: _open, onClose: _close);
  }

  void _disposeController() {
    _controller.detach();
    if (_ownsController) {
      _controller.dispose();
    }
  }

  // ---------------------------------------------------------------------------
  // Open / close
  // ---------------------------------------------------------------------------

  void _open() {
    _controller.setOpen(true);
    _animationController.animateTo(1.0, curve: Curves.easeOutCubic);
  }

  void _close() {
    _controller.setOpen(false);
    _animationController.animateTo(0.0, curve: Curves.easeOutCubic);
  }

  // ---------------------------------------------------------------------------
  // Gesture handling
  // ---------------------------------------------------------------------------

  bool _isDragging = false;
  double _effectiveDragWidth = 0;

  void _onEdgeDragStart(DragStartDetails details) {
    _isDragging = true;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || _effectiveDragWidth == 0) return;
    final delta = details.primaryDelta ?? 0;
    _animationController.value += delta / _effectiveDragWidth;
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 365) {
      _open();
    } else if (velocity < -365) {
      _close();
    } else if (_animationController.value > 0.5) {
      _open();
    } else {
      _close();
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return _SplitNavigationScope(
      controller: _controller,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final mode = width >= widget.breakpoint
              ? _LayoutMode.wide
              : width >= widget.tabletBreakpoint
              ? _LayoutMode.tablet
              : _LayoutMode.phone;

          final prev = _previousMode;
          if (prev == null) {
            // First build: open sidebar for tablet/wide, closed for phone.
            if (mode != _LayoutMode.phone) {
              _animationController.value = 1.0;
              _controller.setOpen(true);
            }
          } else if (prev == _LayoutMode.phone && mode != _LayoutMode.phone) {
            // Phone → tablet/wide: snap open.
            _animationController.value = 1.0;
            _controller.setOpen(true);
          } else if (prev != _LayoutMode.phone && mode == _LayoutMode.phone) {
            // Tablet/wide → phone: snap closed.
            _animationController.value = 0.0;
            _controller.setOpen(false);
          }
          // Tablet ↔ wide: preserve current state.
          _previousMode = mode;

          if (mode == _LayoutMode.phone) {
            return _buildPhoneLayout(context, availableWidth: width);
          }

          final style = mode == _LayoutMode.wide ? _SidebarStyle.wide : _SidebarStyle.tablet;
          return _buildOverlayLayout(context, style: style);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Overlay layout — iPad portrait & landscape
  // ---------------------------------------------------------------------------

  Widget _buildOverlayLayout(BuildContext context, {required _SidebarStyle style}) {
    final isTablet = style == _SidebarStyle.tablet || style == _SidebarStyle.wide;
    final margin = isTablet ? _kFloatingMargin : 0.0;
    final contentInset = margin + widget.sidebarWidth;
    _effectiveDragWidth = widget.sidebarWidth;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, _) {
        final value = _animationController.value;

        final mq = MediaQuery.of(context);
        final adjustedPadding = mq.padding.copyWith(left: mq.padding.left + contentInset * value);

        final sidebarOffset = (widget.sidebarWidth + 2 * margin) * (value - 1);

        return Stack(
          children: [
            // Content — stays in place, with adjusted safe-area inset.
            MediaQuery(
              data: mq.copyWith(padding: adjustedPadding),
              child: SizedBox.expand(child: widget.child),
            ),

            // Sidebar — slides in from the left.
            Positioned(
              left: margin + sidebarOffset,
              top: max(MediaQuery.of(context).padding.top, margin),
              bottom: margin,
              width: widget.sidebarWidth,
              child: MediaQuery(
                data: mq.copyWith(padding: EdgeInsets.zero),
                child: GestureDetector(
                  onHorizontalDragStart: (_) => _isDragging = true,
                  onHorizontalDragUpdate: _onDragUpdate,
                  onHorizontalDragEnd: _onDragEnd,
                  child: _decoratedSidebar(context, style),
                ),
              ),
            ),

            // Edge drag target.
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: widget.edgeDragWidth,
              child: GestureDetector(
                onHorizontalDragStart: _onEdgeDragStart,
                onHorizontalDragUpdate: _onDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
                behavior: HitTestBehavior.translucent,
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Phone layout — push content + scrim
  // ---------------------------------------------------------------------------

  static const _kPhoneContentPeek = 80.0;

  Widget _buildPhoneLayout(BuildContext context, {required double availableWidth}) {
    final colorScheme = Theme.of(context).colorScheme;
    final scrimColor = widget.scrimColor ?? colorScheme.scrim.withValues(alpha: 0.32);

    final effectiveSidebarWidth = (availableWidth - _kPhoneContentPeek).clamp(0.0, availableWidth);
    _effectiveDragWidth = effectiveSidebarWidth;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, _) {
        final value = _animationController.value;
        final offset = effectiveSidebarWidth * value;
        final sidebarVisible = value > 0;

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Sidebar — slides in from the left.
            Positioned(
              left: effectiveSidebarWidth * (value - 1),
              top: 0,
              bottom: 0,
              width: effectiveSidebarWidth,
              child: GestureDetector(
                onHorizontalDragStart: (_) => _isDragging = true,
                onHorizontalDragUpdate: _onDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
                child: _decoratedSidebar(context, _SidebarStyle.phone),
              ),
            ),

            // Content — pushed to the right.
            Transform.translate(
              offset: Offset(offset, 0),
              child: SizedBox.expand(child: widget.child),
            ),

            // Scrim — covers the content, follows its position.
            Transform.translate(
              offset: Offset(offset, 0),
              child: IgnorePointer(
                ignoring: !sidebarVisible,
                child: GestureDetector(
                  onTap: _close,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox.expand(
                    child: ColoredBox(color: scrimColor.withValues(alpha: scrimColor.a * value)),
                  ),
                ),
              ),
            ),

            // Edge drag target.
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: widget.edgeDragWidth,
              child: GestureDetector(
                onHorizontalDragStart: _onEdgeDragStart,
                onHorizontalDragUpdate: _onDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
                behavior: HitTestBehavior.translucent,
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Sidebar decoration
  // ---------------------------------------------------------------------------

  Widget _decoratedSidebar(BuildContext context, _SidebarStyle style) {
    final colorScheme = Theme.of(context).colorScheme;
    final border = BorderSide(color: colorScheme.onSurface.withAlpha(50), width: 1);

    final shadows = [BoxShadow(color: colorScheme.shadow.withValues(alpha: 0.16), blurRadius: 24, offset: const Offset(4, 0))];

    final shape = RoundedRectangleBorder(borderRadius: _kSquircleRadius, side: style == _SidebarStyle.phone ? BorderSide.none : border);

    Widget content = widget.sidebar;
    Widget sidebar;

    if (style == _SidebarStyle.phone) {
      sidebar = DecoratedBox(
        decoration: ShapeDecoration(color: colorScheme.surface, shape: shape, shadows: shadows),
        child: content,
      );
    } else {
      // iPad (portrait & landscape): frosted glass blur with border on top.
      // Background decoration draws the fill + shadows behind the content.
      // Foreground decoration draws only the border over the blur.
      final bgDecoration = ShapeDecoration(
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: _kSquircleRadius, side: BorderSide.none),
        shadows: shadows,
      );
      final fgDecoration = ShapeDecoration(shape: shape);

      sidebar = DecoratedBox(
        decoration: bgDecoration,
        child: DecoratedBox(
          decoration: fgDecoration,
          position: DecorationPosition.foreground,
          child: ClipPath(
            clipper: ShapeBorderClipper(shape: shape),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: ColoredBox(color: colorScheme.surface.withValues(alpha: 0.7), child: content),
            ),
          ),
        ),
      );
    }

    return sidebar;
  }
}

enum _SidebarStyle { wide, phone, tablet }

enum _LayoutMode { phone, tablet, wide }

class _SplitNavigationScope extends InheritedWidget {
  final SplitNavigationController controller;

  const _SplitNavigationScope({required this.controller, required super.child});

  @override
  bool updateShouldNotify(_SplitNavigationScope oldWidget) => controller != oldWidget.controller;
}
