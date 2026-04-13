import 'package:flutter/foundation.dart';

/// Controller for programmatically opening and closing the sidebar in narrow
/// mode.
///
/// Attach to a `SplitNavigationWidget` via its `controller` parameter. The
/// controller notifies listeners whenever the open/closed state changes.
///
/// ```dart
/// final controller = SplitNavigationController();
///
/// SplitNavigationWidget(
///   controller: controller,
///   sidebar: MyNavList(),
///   child: MyContent(),
/// )
///
/// // Later:
/// controller.open();
/// controller.close();
/// controller.toggle();
/// ```
class SplitNavigationController extends ChangeNotifier {
  /// Whether the sidebar is currently open (or animating open) in narrow mode.
  bool get isOpen => _isOpen;
  bool _isOpen = false;

  VoidCallback? _onOpen;
  VoidCallback? _onClose;

  /// Open the sidebar. No-op in wide mode or when not attached.
  void open() => _onOpen?.call();

  /// Close the sidebar. No-op in wide mode or when not attached.
  void close() => _onClose?.call();

  /// Toggle the sidebar open/closed.
  void toggle() {
    if (_isOpen) {
      close();
    } else {
      open();
    }
  }

  /// Called by [SplitNavigationWidget] to wire up open/close callbacks.
  void attach({required VoidCallback onOpen, required VoidCallback onClose}) {
    _onOpen = onOpen;
    _onClose = onClose;
  }

  /// Called by [SplitNavigationWidget] when the widget is disposed or the
  /// controller is swapped.
  void detach() {
    _onOpen = null;
    _onClose = null;
  }

  /// Called by [SplitNavigationWidget] to update the open/closed state.
  void setOpen(bool value) {
    if (value != _isOpen) {
      _isOpen = value;
      notifyListeners();
    }
  }
}
