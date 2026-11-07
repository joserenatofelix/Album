import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:screen_protector/screen_protector.dart';

const _grena = Color(0xFF7B1E3A);
const _imageExt = ['.jpg', '.jpeg', '.png', '.webp'];
const _audioExt = ['.mp3', '.m4a', '.aac', '.wav'];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  await _enableProtection();
  runApp(const AlbumApp());
}

/// Android: FLAG_SECURE (bloqueia print/gravação). iOS: oculta o conteúdo
/// durante captura/gravação de tela e no seletor de apps.
Future<void> _enableProtection() async {
  try {
    await ScreenProtector.protectDataLeakageOn();
    await ScreenProtector.preventScreenshotOn();
  } catch (_) {}
}

class AlbumApp extends StatelessWidget {
  const AlbumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Casamento Cléo e Renato',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFBF5F3),
        colorScheme: ColorScheme.fromSeed(seedColor: _grena),
      ),
      home: const AlbumPage(),
    );
  }
}

class AlbumPage extends StatefulWidget {
  const AlbumPage({super.key});

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> with WidgetsBindingObserver {
  final _player = AudioPlayer();
  final _pageController = PageController();
  List<String> _photos = [];
  List<String> _songs = [];
  int _index = 0;
  bool _loading = true;
  bool _muted = false;
  bool _slideshow = false;
  bool _zoomed = false;
  bool _showUi = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets()..sort();
    bool isType(String a, String dir, List<String> ext) =>
        a.startsWith(dir) && ext.any(a.toLowerCase().endsWith);
    _photos = assets.where((a) => isType(a, 'assets/fotos/', _imageExt)).toList();
    _songs = assets.where((a) => isType(a, 'assets/musicas/', _audioExt)).toList();
    if (_songs.isNotEmpty) {
      try {
        await _player.setAudioSources(
            _songs.map((s) => AudioSource.asset(s)).toList());
        await _player.setLoopMode(LoopMode.all);
        await _player.setVolume(0.7);
        unawaited(_player.play());
      } catch (_) {}
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _player.pause();
    } else if (state == AppLifecycleState.resumed && !_muted && _songs.isNotEmpty) {
      _player.play();
    }
  }

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= _photos.length) return;
    _pageController.animateToPage(next,
        duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
  }

  void _toggleSlideshow() {
    setState(() => _slideshow = !_slideshow);
    _timer?.cancel();
    if (_slideshow) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (_zoomed) return;
        final next = (_index + 1) % _photos.length;
        _pageController.animateToPage(next,
            duration: const Duration(milliseconds: 700), curve: Curves.easeInOut);
      });
    }
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _muted ? _player.pause() : _player.play();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _player.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: _grena)));
    }
    if (_photos.isEmpty) {
      return const Scaffold(
          body: Center(child: Text('Adicione fotos em assets/fotos/')));
    }
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _showUi = !_showUi),
        child: Stack(fit: StackFit.expand, children: [
          Image.asset(
            'assets/fundo/fundo.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFFBF5F3)),
          ),
          PageView.builder(
            controller: _pageController,
            physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
            itemCount: _photos.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _PhotoView(
              path: _photos[i],
              onZoomChanged: (z) {
                if (z != _zoomed) setState(() => _zoomed = z);
              },
            ),
          ),
          const IgnorePointer(child: _FallingHearts()),
          _fade(top: true, child: _header()),
          _fade(top: false, child: _controls()),
        ]),
      ),
    );
  }

  Widget _fade({required bool top, required Widget child}) {
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !_showUi || _zoomed,
        child: AnimatedOpacity(
          opacity: _showUi && !_zoomed ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: top ? Alignment.topCenter : Alignment.bottomCenter,
                end: top ? Alignment.bottomCenter : Alignment.topCenter,
                colors: [
                  const Color(0xFFFBF5F3).withValues(alpha: 0.9),
                  Colors.transparent
                ],
              ),
            ),
            child: SafeArea(child: child),
          ),
        ),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          const Expanded(
            child: Text('Casamento Cléo e Renato',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'GreatVibes',
                    fontSize: 34,
                    height: 1.1,
                    color: _grena)),
          ),
        ]),
      );

  Widget _pill({required List<Widget> children}) => Center(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                  color: _grena.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      );

  Widget _controls() => _pill(children: [
        IconButton(
            iconSize: 32,
            color: _grena,
            onPressed: _index > 0 ? () => _go(-1) : null,
            icon: const Icon(Icons.chevron_left)),
        IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: _grena),
            onPressed: _toggleSlideshow,
            icon: Icon(_slideshow ? Icons.pause : Icons.play_arrow)),
        const SizedBox(width: 6),
        Text('${_index + 1} / ${_photos.length}',
            style: const TextStyle(
                color: _grena, fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(width: 6),
        IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: _grena),
            onPressed: _songs.isEmpty ? null : _toggleMute,
            icon: Icon(_muted ? Icons.music_off : Icons.music_note)),
        IconButton(
            iconSize: 32,
            color: _grena,
            onPressed: _index < _photos.length - 1 ? () => _go(1) : null,
            icon: const Icon(Icons.chevron_right)),
      ]);
}

/// Corações que caem continuamente sobre as fotos.
class _FallingHearts extends StatefulWidget {
  const _FallingHearts();

  @override
  State<_FallingHearts> createState() => _FallingHeartsState();
}

class _Heart {
  _Heart(math.Random r)
      : x = r.nextDouble(),
        phase = r.nextDouble(),
        speed = 0.6 + r.nextDouble() * 0.8,
        size = 14 + r.nextDouble() * 18,
        sway = 10 + r.nextDouble() * 20,
        opacity = 0.35 + r.nextDouble() * 0.45,
        color = r.nextBool() ? const Color(0xFFE8829B) : _grena;
  final double x, phase, speed, size, sway, opacity;
  final Color color;
}

class _FallingHeartsState extends State<_FallingHearts>
    with SingleTickerProviderStateMixin {
  static const _count = 22;
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 10))
    ..repeat();
  final _rand = math.Random();
  late final List<_Heart> _hearts =
      List.generate(_count, (_) => _Heart(_rand));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, box) {
      return AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Stack(children: [
          for (final h in _hearts)
            () {
              final t = (_c.value * h.speed + h.phase) % 1.0;
              final dx = math.sin(t * 2 * math.pi * 2) * h.sway;
              return Positioned(
                left: h.x * box.maxWidth + dx,
                top: -h.size + t * (box.maxHeight + h.size * 2),
                child: Opacity(
                  opacity: h.opacity,
                  child: Icon(Icons.favorite, size: h.size, color: h.color),
                ),
              );
            }(),
        ]),
      );
    });
  }
}

/// Foto com zoom (pinça) e duplo toque; sem long-press, salvar ou compartilhar.
class _PhotoView extends StatefulWidget {
  const _PhotoView({required this.path, required this.onZoomChanged});
  final String path;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_PhotoView> createState() => _PhotoViewState();
}

class _PhotoViewState extends State<_PhotoView>
    with SingleTickerProviderStateMixin {
  final _controller = TransformationController();
  late final AnimationController _anim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 250));
  Offset _tap = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller.addListener(
        () => widget.onZoomChanged(_controller.value.getMaxScaleOnAxis() > 1.01));
  }

  void _doubleTap() {
    final zoomed = _controller.value.getMaxScaleOnAxis() > 1.01;
    final end = zoomed
        ? Matrix4.identity()
        : (Matrix4.identity()
          ..translate(-_tap.dx * 1.5, -_tap.dy * 1.5)
          ..scale(2.5));
    final tween = Matrix4Tween(begin: _controller.value, end: end)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    void listener() => _controller.value = tween.value;
    tween.addListener(listener);
    _anim.forward(from: 0).whenComplete(() => tween.removeListener(listener));
  }

  @override
  void dispose() {
    _anim.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (d) => _tap = d.localPosition,
      onDoubleTap: _doubleTap,
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 1,
        maxScale: 5,
        child: SizedBox.expand(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 96, 20, 100),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: _grena.withValues(alpha: 0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 10)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  widget.path,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) =>
                      const Center(child: Icon(Icons.broken_image)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
