import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/format.dart';
import '../../core/haptics.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../platform/blocker.dart';
import '../../platform/gravity.dart';
import '../widgets/kit.dart';
import '../widgets/pressable.dart';
import 'frame_converter.dart';
import 'pose_painter.dart';
import 'pushup_tracker.dart';

enum _Phase { loading, permission, denied, unavailable, ready }

class PushUpScreen extends StatefulWidget {
  const PushUpScreen({super.key, required this.required, required this.secondsEach});

  final int required;
  final int secondsEach;

  @override
  State<PushUpScreen> createState() => _PushUpScreenState();
}

class _PushUpScreenState extends State<PushUpScreen> with WidgetsBindingObserver {
  final PoseDetector _detector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream, model: PoseDetectionModel.accurate),
  );
  late final PushUpTracker _tracker = PushUpTracker(target: widget.required);
  final Stopwatch _clock = Stopwatch()..start();
  StreamSubscription<List<double>>? _gravity;
  List<double>? _reading;
  CameraController? _camera;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  int _sdk = 0;
  double _zoom = 1;
  _Phase _phase = _Phase.loading;
  bool _busy = false;
  bool _switching = false;
  bool _guide = true;
  bool _finished = false;
  Pose? _pose;
  Size _imageSize = Size.zero;
  InputImageRotation _rotation = InputImageRotation.rotation0deg;
  PushUpCue _cue = PushUpCue.findBody;
  DateTime _holdCueUntil = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _front => _cameras.isNotEmpty && _cameras[_cameraIndex].lensDirection == CameraLensDirection.front;

  bool get _mirrorPose => Platform.isAndroid && _front;

  bool get _flipPreview => _mirrorPose && (_sdk == 0 || _sdk >= 29);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gravity = Gravity.watch().listen((value) => _reading = value, onError: (Object _) {});
    _prepare();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gravity?.cancel();
    _closeCamera();
    _detector.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_phase != _Phase.ready) {
      if (state == AppLifecycleState.resumed && _phase == _Phase.denied) _prepare();
      return;
    }
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _closeCamera();
    } else if (state == AppLifecycleState.resumed && _camera == null) {
      _open(_cameraIndex);
    }
  }

  Future<void> _prepare() async {
    final status = await Permission.camera.status;
    if (!mounted) return;
    if (status.isGranted) {
      await _startCameras();
    } else {
      setState(() => _phase = status.isPermanentlyDenied ? _Phase.denied : _Phase.permission);
    }
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isGranted) {
      await _startCameras();
    } else if (status.isPermanentlyDenied) {
      setState(() => _phase = _Phase.denied);
    }
  }

  Future<void> _startCameras() async {
    try {
      _cameras = await availableCameras();
    } on CameraException {
      _cameras = const [];
    }
    if (Platform.isAndroid) _sdk = (await Blocker.status()).sdk;
    if (!mounted) return;
    if (_cameras.isEmpty) {
      setState(() => _phase = _Phase.unavailable);
      return;
    }
    final front = _cameras.indexWhere((camera) => camera.lensDirection == CameraLensDirection.front);
    _cameraIndex = front < 0 ? 0 : front;
    await _open(_cameraIndex);
  }

  Future<void> _open(int index) async {
    await _closeCamera();
    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
    );
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _camera = controller;
      _zoom = await _widest(controller);
      await controller.startImageStream(_onFrame);
      setState(() {
        _phase = _Phase.ready;
        _switching = false;
      });
    } on CameraException {
      await controller.dispose();
      if (mounted) setState(() => _phase = _Phase.unavailable);
    }
  }

  Future<double> _widest(CameraController controller) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final minimum = await controller.getMinZoomLevel();
        if (minimum >= 0.99) return 1;
        await controller.setZoomLevel(minimum);
        return minimum;
      } on Exception {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    return 1;
  }

  Future<void> _closeCamera() async {
    final camera = _camera;
    _camera = null;
    if (camera == null) return;
    try {
      if (camera.value.isStreamingImages) await camera.stopImageStream();
    } on CameraException {
      return;
    } finally {
      await camera.dispose();
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _switching) return;
    setState(() {
      _switching = true;
      _pose = null;
    });
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _open(_cameraIndex);
  }

  void _onFrame(CameraImage image) {
    if (_busy || _finished || _switching) return;
    _busy = true;
    _analyze(image).whenComplete(() => _busy = false);
  }

  Future<void> _analyze(CameraImage image) async {
    final camera = _camera;
    if (camera == null) return;
    final orientation = camera.value.deviceOrientation;
    final rotation = FrameConverter.rotation(_cameras[_cameraIndex], orientation);
    if (rotation == null) return;
    final input = FrameConverter.toInputImage(image, rotation);
    if (input == null) return;
    final List<Pose> poses;
    try {
      poses = await _detector.processImage(input);
    } on Exception {
      return;
    }
    if (!mounted || _finished) return;
    final pose = poses.isEmpty ? null : poses.first;
    final before = _tracker.count;
    final (:down, :level) = FrameConverter.gravity(
      _reading,
      front: _front,
      compensation: FrameConverter.compensation(orientation),
    );
    final cue = _tracker.update(pose == null ? null : _sample(pose), _clock.elapsed, gravity: down, level: level);
    final now = DateTime.now();
    if (_tracker.count > before) {
      Haptics.medium();
      _holdCueUntil = now.add(const Duration(milliseconds: 900));
    }
    setState(() {
      _pose = pose;
      _imageSize = Size(image.width.toDouble(), image.height.toDouble());
      _rotation = rotation;
      if (pose != null) _guide = false;
      if (cue == PushUpCue.rep || cue == PushUpCue.done || now.isAfter(_holdCueUntil)) _cue = cue;
    });
    if (_tracker.complete) _complete();
  }

  PoseSample _sample(Pose pose) {
    Joint? point(PoseLandmarkType type) {
      final landmark = pose.landmarks[type];
      if (landmark == null || landmark.likelihood < 0.3) return null;
      return Joint(Offset(landmark.x, landmark.y), landmark.likelihood);
    }

    return PoseSample(
      leftShoulder: point(PoseLandmarkType.leftShoulder),
      rightShoulder: point(PoseLandmarkType.rightShoulder),
      leftElbow: point(PoseLandmarkType.leftElbow),
      rightElbow: point(PoseLandmarkType.rightElbow),
      leftWrist: point(PoseLandmarkType.leftWrist),
      rightWrist: point(PoseLandmarkType.rightWrist),
      leftHip: point(PoseLandmarkType.leftHip),
      rightHip: point(PoseLandmarkType.rightHip),
      leftKnee: point(PoseLandmarkType.leftKnee),
      rightKnee: point(PoseLandmarkType.rightKnee),
      leftAnkle: point(PoseLandmarkType.leftAnkle),
      rightAnkle: point(PoseLandmarkType.rightAnkle),
    );
  }

  Future<void> _complete() async {
    if (_finished) return;
    _finished = true;
    Haptics.heavy();
    setState(() => _cue = PushUpCue.done);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted) Navigator.of(context).pop(_tracker.count);
  }

  void _close() => Navigator.of(context).pop(_tracker.count);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: Palette.background,
        body: AnimatedSwitcher(
          duration: Motion.medium,
          child: switch (_phase) {
            _Phase.loading => const Center(
                key: ValueKey('loading'),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            _Phase.permission => _Notice(
                key: const ValueKey('permission'),
                icon: Icons.photo_camera_outlined,
                color: Palette.primary,
                title: l.t('cameraNeeded'),
                body: l.t('cameraNeededDesc'),
                action: l.t('allowCamera'),
                onAction: _requestPermission,
                onClose: _close,
              ),
            _Phase.denied => _Notice(
                key: const ValueKey('denied'),
                icon: Icons.no_photography,
                color: Palette.danger,
                title: l.t('cameraDenied'),
                body: l.t('cameraDeniedDesc'),
                action: l.t('openSettings'),
                onAction: openAppSettings,
                onClose: _close,
              ),
            _Phase.unavailable => _Notice(
                key: const ValueKey('unavailable'),
                icon: Icons.videocam_off,
                color: Palette.danger,
                title: l.t('cameraUnavailable'),
                body: l.t('cameraUnavailableDesc'),
                onClose: _close,
              ),
            _Phase.ready => KeyedSubtree(key: const ValueKey('ready'), child: _buildCamera(context)),
          },
        ),
      ),
    );
  }

  Widget _buildCamera(BuildContext context) {
    final l = context.l10n;
    final camera = _camera;
    final previewSize = camera?.value.previewSize;
    final detected = _pose != null;
    final progress = widget.required == 0 ? 0.0 : (_tracker.count / widget.required).clamp(0.0, 1.0);
    final color = _tracker.complete ? Palette.success : (_tracker.down ? Palette.warning : Palette.primary);
    final bar = _tracker.complete ? Palette.success : Palette.primary;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (camera != null && camera.value.isInitialized && previewSize != null)
          ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: previewSize.height,
                height: previewSize.width,
                child: Transform.flip(flipX: _flipPreview, child: CameraPreview(camera)),
              ),
            ),
          ),
        if (_pose != null)
          CustomPaint(
            painter: PosePainter(
              pose: _pose!,
              imageSize: _imageSize,
              previewSize: previewSize == null ? null : Size(previewSize.height, previewSize.width),
              rotation: _rotation,
              mirrored: _mirrorPose,
              upperOnly: _tracker.view == PushUpView.front,
              color: color,
            ),
          ),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.15, 0.7, 1],
                colors: [Color(0xBF000000), Color(0x00000000), Color(0x00000000), Color(0xCC000000)],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(Space.md),
                child: Row(
                  children: [
                    _HudBox(
                      onTap: _close,
                      tooltip: l.t('close'),
                      child: const Icon(Icons.close, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(child: _DetectionBox(detected: detected)),
                    if (_cameras.length > 1) ...[
                      const SizedBox(width: Space.sm),
                      _HudBox(
                        onTap: _switching ? null : _switchCamera,
                        tooltip: l.t('switchCamera'),
                        border: Palette.primary.withOpacity(0.5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_switching ? Icons.hourglass_top : Icons.cameraswitch,
                                color: Palette.primary, size: 20),
                            const SizedBox(width: Space.xs),
                            Caps(
                              l.t(_front ? 'cameraFront' : 'cameraBack'),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Palette.primary),
                            ),
                            if (_zoom < 0.99) ...[
                              const SizedBox(width: Space.xs),
                              Text(
                                '${_zoom.toStringAsFixed(1)}×',
                                textDirection: TextDirection.ltr,
                                style: Typo.numeral.copyWith(fontSize: 10, color: Palette.primary),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        transitionBuilder: (child, animation) => ScaleTransition(
                          scale: Tween(begin: 1.3, end: 1.0)
                              .animate(CurvedAnimation(parent: animation, curve: Motion.spring)),
                          child: FadeTransition(opacity: animation, child: child),
                        ),
                        child: Text(
                          '${_tracker.count}',
                          key: ValueKey(_tracker.count),
                          style: Typo.numeral.copyWith(
                            fontSize: 120,
                            height: 1,
                            letterSpacing: -4,
                            shadows: const [Shadow(color: Colors.black, blurRadius: 20)],
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        decoration: BoxDecoration(color: Colors.black54, border: Border.all(color: Palette.primary)),
                        child: Text(
                          '/ ${widget.required}',
                          textDirection: TextDirection.ltr,
                          style: Typo.numeral.copyWith(fontSize: 24, color: Palette.primary, letterSpacing: 1),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 60),
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(end: progress),
                              duration: Motion.medium,
                              curve: Motion.ease,
                              builder: (context, value, _) => FractionallySizedBox(
                                widthFactor: value,
                                heightFactor: 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: bar,
                                    borderRadius: BorderRadius.circular(3),
                                    boxShadow: [BoxShadow(color: bar.withOpacity(0.6), blurRadius: 8)],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _CuePanel(
                cue: _cue,
                detail: l.f('pushUpInfo', {
                  'seconds': '${widget.secondsEach}',
                  'time': Fmt.duration(l, widget.required * widget.secondsEach),
                }),
              ),
            ],
          ),
        ),
        PositionedDirectional(
          end: Space.md,
          top: 0,
          bottom: 0,
          child: Center(
            child: _DepthGauge(depth: _tracker.depth, down: _tracker.down, active: _tracker.calibrated),
          ),
        ),
        if (_switching) const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        if (_guide) _Guide(onStart: () => setState(() => _guide = false)),
      ],
    );
  }
}

class _HudBox extends StatelessWidget {
  const _HudBox({required this.child, required this.onTap, required this.tooltip, this.border = Palette.divider});

  final Widget child;
  final VoidCallback? onTap;
  final String tooltip;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: Pressable(
        onTap: onTap,
        semanticLabel: tooltip,
        scale: 0.94,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: Space.sm + 2),
          decoration: BoxDecoration(color: Colors.black54, border: Border.all(color: border)),
          child: Center(widthFactor: 1, child: child),
        ),
      ),
    );
  }
}

class _DetectionBox extends StatelessWidget {
  const _DetectionBox({required this.detected});

  final bool detected;

  @override
  Widget build(BuildContext context) {
    final color = detected ? Palette.success : Palette.danger;
    return AnimatedContainer(
      duration: Motion.medium,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: Space.sm + 2),
      decoration: BoxDecoration(color: Colors.black54, border: Border.all(color: color.withOpacity(0.7))),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: Space.sm - 2),
          Expanded(
            child: Caps(
              context.t(detected ? 'detected' : 'noBody'),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _CuePanel extends StatelessWidget {
  const _CuePanel({required this.cue, required this.detail});

  final PushUpCue cue;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final key = switch (cue) {
      PushUpCue.findBody => 'cueFindBody',
      PushUpCue.showUpperBody => 'cueUpperBody',
      PushUpCue.showBody => 'cueFullBody',
      PushUpCue.placePhone => 'cuePlacePhone',
      PushUpCue.getInPosition => 'cuePosition',
      PushUpCue.liftKnees => 'cueKnees',
      PushUpCue.straightenBody => 'cueStraight',
      PushUpCue.holdStill => 'cueSteady',
      PushUpCue.startTop => 'cueStartTop',
      PushUpCue.goDown => 'cueGoDown',
      PushUpCue.lower => 'cueLower',
      PushUpCue.pushUp => 'cuePushUp',
      PushUpCue.rep => 'cueRep',
      PushUpCue.done => 'cueDone',
    };
    final color = switch (cue) {
      PushUpCue.rep || PushUpCue.done => Palette.success,
      PushUpCue.pushUp || PushUpCue.lower || PushUpCue.holdStill => Palette.warning,
      PushUpCue.findBody ||
      PushUpCue.showUpperBody ||
      PushUpCue.showBody ||
      PushUpCue.placePhone ||
      PushUpCue.getInPosition ||
      PushUpCue.liftKnees ||
      PushUpCue.straightenBody ||
      PushUpCue.startTop =>
        Palette.textSecondary,
      PushUpCue.goDown => Colors.white,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        border: const Border(top: BorderSide(color: Palette.primary, width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: Motion.medium,
            child: Text(
              l.t(key),
              key: ValueKey(key),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color),
            ),
          ),
          const SizedBox(height: Space.sm - 2),
          Caps(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, letterSpacing: 1, color: Palette.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Guide extends StatelessWidget {
  const _Guide({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ColoredBox(
      color: Colors.black.withOpacity(0.85),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.fitness_center, color: Palette.primary, size: 44),
                const SizedBox(height: Space.lg),
                Caps(
                  l.t('pushUpChallenge'),
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 1, color: Colors.white),
                ),
                const SizedBox(height: Space.xl),
                for (final (number, key, icon) in const [
                  ('1', 'guideStep1', Icons.stay_current_portrait),
                  ('2', 'guideStep2', Icons.crop_free),
                  ('3', 'guideStep3', Icons.fitness_center),
                  ('4', 'guideStep4', Icons.compare_arrows),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.lg),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(border: Border.all(color: Palette.primary)),
                          child: Text(number, style: Typo.numeral.copyWith(fontSize: 14, color: Palette.primary)),
                        ),
                        const SizedBox(width: Space.md),
                        Icon(icon, size: 20, color: Palette.textSecondary),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: Text(
                            l.t(key),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600, color: Palette.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Space.md),
                  decoration: BoxDecoration(
                    color: Palette.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(color: Palette.primary.withOpacity(0.3)),
                  ),
                  child: Text(
                    l.t('guideNote'),
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Palette.primary, height: 1.5),
                  ),
                ),
                const SizedBox(height: Space.xl),
                BlockButton(label: l.t('gotItStart'), icon: Icons.play_arrow_rounded, onTap: onStart),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.onClose,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String? action;
  final FutureOr<void> Function()? onAction;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Space.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 64),
            const SizedBox(height: Space.lg),
            Caps(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1, color: Colors.white),
            ),
            const SizedBox(height: Space.sm),
            Text(body, textAlign: TextAlign.center, style: Typo.body),
            const SizedBox(height: Space.xl),
            if (action != null && onAction != null) ...[
              BlockButton(label: action!, onTap: () => onAction!()),
              const SizedBox(height: Space.sm),
            ],
            TextButton(
              onPressed: onClose,
              child: Text(l.t('cancel'), style: const TextStyle(color: Palette.textMuted, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DepthGauge extends StatelessWidget {
  const _DepthGauge({required this.depth, required this.down, required this.active});

  static const _height = 180.0;
  static const _inset = 3.0;

  final double depth;
  final bool down;
  final bool active;

  @override
  Widget build(BuildContext context) {
    const track = _height - _inset * 2;
    return ExcludeSemantics(
      child: AnimatedOpacity(
        duration: Motion.medium,
        opacity: active ? 1 : 0.35,
        child: Container(
          width: 14,
          height: _height,
          padding: const EdgeInsets.all(_inset),
          decoration: BoxDecoration(color: Colors.black54, border: Border.all(color: Palette.divider)),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  height: track * depth.clamp(0.0, 1.0),
                  color: down ? Palette.warning : Palette.primary,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: track * PushUpTracker.bottomDepth,
                child: Container(height: 2, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
