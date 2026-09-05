import 'package:flutter/material.dart';

import '../camera/camera_configuration.dart';
import '../camera/camera_controller.dart';
import '../camera/camera_state.dart';
import '../errors/camera_exceptions.dart';
import '../platform/camera_platform_interface.dart';

/// Signature for the permission check a consumer supplies to
/// [D3CameraScope]. Return `true` once camera permission is granted.
///
/// This package deliberately takes no permissions-plugin dependency --
/// which plugin to use is the consuming app's choice, and apps commonly
/// already have one. Supply a closure over yours, e.g. with
/// `permission_handler`:
///
/// ```dart
/// requestPermission: () async =>
///     (await Permission.camera.request()).isGranted,
/// ```
typedef CameraPermissionRequest = Future<bool> Function();

/// Owns a [CustomCameraController]'s full lifecycle -- create,
/// permission, initialize, listen, dispose -- and hands the ready
/// controller to [builder].
///
/// This is the middle layer of the package's three: [D3CameraScope]
/// removes the boilerplate every consumer would otherwise rewrite, while
/// leaving all UI to the caller. Use `D3CameraScreen` when you want a
/// working camera UI outright, or drive [CustomCameraController]
/// yourself when you need control over the lifecycle too.
///
/// [builder] is called only once the controller is initialized, so it
/// never has to handle a null or half-ready controller. While
/// permission/initialization is pending, or after a failure, the
/// corresponding builder is used instead.
class D3CameraScope extends StatefulWidget {
  const D3CameraScope({
    super.key,
    required this.builder,
    this.configuration = const CameraConfiguration(),
    this.requestPermission,
    this.loadingBuilder,
    this.errorBuilder,
    this.permissionDeniedBuilder,
    @visibleForTesting this.platform,
  });

  /// Called with an initialized, ready-to-use controller.
  final Widget Function(BuildContext context, CustomCameraController controller)
  builder;

  final CameraConfiguration configuration;

  /// Called before `initialize()`. When null, initialization is
  /// attempted directly -- appropriate if the app already secured
  /// permission earlier in its own flow.
  final CameraPermissionRequest? requestPermission;

  /// Shown while permission and initialization are in flight. Defaults
  /// to a centered progress indicator on black.
  final WidgetBuilder? loadingBuilder;

  /// Shown when initialization fails. Defaults to the error's message on
  /// black.
  final Widget Function(BuildContext context, CustomCameraException error)?
  errorBuilder;

  /// Shown when [requestPermission] returns false. Defaults to a short
  /// explanatory message.
  final WidgetBuilder? permissionDeniedBuilder;

  /// Injectable platform for tests, mirroring
  /// [CustomCameraController]'s own hook. Production code leaves this
  /// null and gets the real method-channel implementation.
  @visibleForTesting
  final CameraPlatform? platform;

  @override
  State<D3CameraScope> createState() => _D3CameraScopeState();
}

class _D3CameraScopeState extends State<D3CameraScope> {
  late final CustomCameraController _controller;
  CustomCameraException? _error;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _controller = CustomCameraController(
      configuration: widget.configuration,
      // Forwarding this widget's own @visibleForTesting seam to the
      // controller's.
      // ignore: invalid_use_of_visible_for_testing_member
      platform: widget.platform,
    );
    _controller.addListener(_onControllerChanged);
    _start();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _start() async {
    final request = widget.requestPermission;
    if (request != null) {
      final granted = await request();
      if (!mounted) return;
      if (!granted) {
        setState(() => _permissionDenied = true);
        return;
      }
    }

    try {
      await _controller.initialize();
    } on CustomCameraException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return widget.permissionDeniedBuilder?.call(context) ??
          const _CameraScopeMessage(
            'Camera permission was denied. Grant it in system settings to '
            'use the camera.',
          );
    }

    final error = _error ?? _controller.value.lastError;
    if (error != null && _controller.value.status == CameraStatus.error) {
      return widget.errorBuilder?.call(context, error) ??
          _CameraScopeMessage(error.message);
    }

    if (_controller.value.status != CameraStatus.ready &&
        _controller.value.textureId == null) {
      return widget.loadingBuilder?.call(context) ??
          const ColoredBox(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator()),
          );
    }

    return widget.builder(context, _controller);
  }
}

class _CameraScopeMessage extends StatelessWidget {
  const _CameraScopeMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
