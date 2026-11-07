import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../common_widgets/app_toast.dart';
import '../../../constants/app_colors.dart';
import '../data/auth_repository.dart';
import '../data/password_reset_storage.dart';
import '../data/supabase_auth_repository.dart';
import '../../profile/data/supabase_profile_repository.dart';

import '../../learn/data/supabase_pathway_repository.dart';
import '../../profile/domain/profile_model.dart';

/// Where the splash sends the learner, and an optional message to show first.
class _Destination {
  const _Destination(this.route, {this.errorMessage});

  final String route;
  final String? errorMessage;
}

/// Splash: "Assemble".
///
/// 1. A scattered network of nodes fades in, linked to its neighbours.
/// 2. A signal sweeps through it.
/// 3. The nodes travel to the pixels of the real logo and the links let go.
/// 4. The crisp logo resolves, the wordmark types itself, the tagline settles.
///
/// Flat on purpose: thin lines and small dots, no glow or gradient. The first
/// launch plays the whole intro; later launches play a shorter one. The profile
/// and dashboard load while it plays, so it adds no waiting on top of loading.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.authRepository = const SupabaseAuthRepository(),
  });

  final AuthRepository authRepository;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const Duration _fullIntro = Duration(milliseconds: 3000);
  static const Duration _shortIntro = Duration(milliseconds: 1700);
  static const String _seenKey = 'splash_intro_seen_v1';
  static const String _brandLead = 'CodeMentor';
  static const String _brandTail = 'AI';
  static const double _markSize = 76.0;

  late final AnimationController _timeline;
  late final AnimationController _caret;

  // Timeline slices (fractions of the whole intro).
  late final Animation<double> _appear;
  late final Animation<double> _pulse;
  late final Animation<double> _assemble;
  late final Animation<double> _logo;
  late final Animation<double> _typing;
  late final Animation<double> _tagline;

  _NodeField? _field;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();

    _timeline = AnimationController(vsync: this, duration: _fullIntro);

    Animation<double> slice(double a, double b, Curve curve) => CurvedAnimation(
      parent: _timeline,
      curve: Interval(a, b, curve: curve),
    );

    _appear = slice(0.00, 0.22, Curves.easeOut);
    _pulse = slice(0.10, 0.42, Curves.linear);
    _assemble = slice(0.30, 0.66, Curves.linear);
    _logo = slice(0.62, 0.74, Curves.easeOut);
    _typing = slice(0.70, 0.88, Curves.linear);
    _tagline = slice(0.88, 1.00, Curves.easeOutCubic);

    _caret = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1060),
    )..repeat();

    // Resolve the destination right away, in parallel with the intro.
    final Future<_Destination> destination = _resolveDestination();
    _start(destination);
  }

  Future<void> _start(Future<_Destination> destination) async {
    bool seen = false;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      seen = prefs.getBool(_seenKey) ?? false;
      unawaited(prefs.setBool(_seenKey, true));
    } catch (_) {}

    try {
      _field = await _NodeField.fromAsset(
        'assets/images/app_logo.png',
        markSize: _markSize,
        screen: _screenSize(),
      );
    } catch (_) {
      _field = null; // The logo still resolves, just without the network.
    }
    if (!mounted) return;

    _timeline.duration = seen ? _shortIntro : _fullIntro;
    await _run(destination);
  }

  Size _screenSize() {
    final ui.FlutterView view = WidgetsBinding.instance.platformDispatcher.views
        .first;
    return view.physicalSize / view.devicePixelRatio;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
  }

  Future<void> _run(Future<_Destination> destination) async {
    // Reduced motion: show the finished frame and keep a short branded pause.
    if (_reduceMotion) {
      _timeline.value = 1.0;
      await Future<void>.delayed(const Duration(milliseconds: 700));
    } else {
      await _timeline.forward().orCancel.catchError((Object _) {});
    }

    final _Destination dest = await destination;
    if (!mounted) return;

    if (dest.errorMessage != null) {
      AppToast.showError(context, dest.errorMessage!);
    }
    context.go(dest.route);
  }

  Future<_Destination> _resolveDestination() async {
    try {
      final bool isResetPending = await PasswordResetStorage.isResetPending();
      final session = Supabase.instance.client.auth.currentSession;
      final String provider =
          session?.user.appMetadata['provider'] as String? ?? '';
      final dynamic amrList = session?.user.appMetadata['amr'];
      final bool isRecovery =
          provider == 'recovery' ||
          (amrList is List &&
              amrList.any(
                (dynamic item) => item is Map && item['method'] == 'recovery',
              ));

      if (isResetPending || isRecovery) {
        return const _Destination('/reset-password');
      }

      final user = await widget.authRepository.getCurrentUser();
      if (user == null) return const _Destination('/login');

      final profileRepo = const SupabaseProfileRepository();
      final pathwayRepo = const SupabasePathwayRepository();

      // Fetch profile and dashboard data together while the splash plays.
      final results = await Future.wait(<Future<Object?>>[
        profileRepo.getProfile(user.id),
        pathwayRepo.getLearnDashboardData(user.id),
      ]);
      final ProfileModel? profile = results[0] as ProfileModel?;

      // Mobile is for learners only. Mentors and admins use the web portal.
      if (!SupabaseProfileRepository.isRoleAllowedOnMobile(profile?.role)) {
        await widget.authRepository.signOut();
        return const _Destination(
          '/login',
          errorMessage:
              'Access restricted. Mentor and Admin workspaces are available on the web portal only.',
        );
      }

      final bool hasCompleted =
          profile?.userOnboarded ??
          ((profile?.firstName?.isNotEmpty ?? false) &&
              (profile?.lastName?.isNotEmpty ?? false));

      return _Destination(hasCompleted ? '/dashboard' : '/onboarding');
    } catch (_) {
      return const _Destination('/login');
    }
  }

  @override
  void dispose() {
    _timeline.dispose();
    _caret.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Semantics(
        label: 'CodeMentorAI. Master code with AI mentorship.',
        child: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[_timeline, _caret]),
            builder: (BuildContext context, Widget? child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _buildMark(),
                  const SizedBox(height: 28.0),
                  _buildWordmark(),
                  const SizedBox(height: 10.0),
                  _buildTagline(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // The network assembles into the logo, then the crisp logo resolves over it.
  Widget _buildMark() {
    const double box = _markSize + 12.0;
    final double t = _timeline.value;
    final _NodeField? field = _field;
    // Without a network the logo simply fades in early.
    final double logoOpacity = field == null
        ? Curves.easeOut.transform(((t - 0.10) / 0.2).clamp(0.0, 1.0))
        : _logo.value;

    return SizedBox(
      width: box,
      height: box,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: <Widget>[
          if (field != null)
            CustomPaint(
              size: const Size(box, box),
              painter: _NetworkPainter(
                field: field,
                appear: _appear.value,
                pulse: _pulse.value,
                assemble: _assemble.value,
                dissolve: _logo.value,
                time: t,
              ),
            ),
          Opacity(
            opacity: logoOpacity,
            child: Image.asset(
              'assets/images/app_logo.png',
              width: _markSize,
              height: _markSize,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  // Types the name with a caret. The full word is laid out invisibly first so
  // the text never shifts sideways while it fills in.
  Widget _buildWordmark() {
    final TextStyle style = GoogleFonts.plusJakartaSans(
      fontSize: 28.0,
      fontWeight: FontWeight.w800,
      color: AppColors.darkTextPrimary,
      letterSpacing: -0.6,
      height: 1.1,
    );
    const int total = 12; // 'CodeMentor' + 'AI'
    final int shown = (_typing.value * total).floor().clamp(0, total);
    final String lead = _brandLead.substring(
      0,
      math.min(shown, _brandLead.length),
    );
    final String tail = shown > _brandLead.length
        ? _brandTail.substring(0, shown - _brandLead.length)
        : '';

    final bool typingDone = _typing.value >= 1.0;
    final bool started = _typing.value > 0.0;
    // Solid while typing, then a calm blink that settles out after a moment.
    final double blink = typingDone
        ? (_tagline.value >= 1.0
              ? 0.0
              : (_caret.value < 0.5 ? 1.0 : 0.0))
        : (started ? 1.0 : 0.0);

    return Stack(
      alignment: Alignment.centerLeft,
      children: <Widget>[
        Opacity(
          opacity: 0.0,
          child: RichText(
            text: TextSpan(
              style: style,
              children: const <TextSpan>[
                TextSpan(text: _brandLead),
                TextSpan(text: _brandTail),
              ],
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            RichText(
              text: TextSpan(
                style: style,
                children: <TextSpan>[
                  TextSpan(text: lead),
                  TextSpan(
                    text: tail,
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ],
              ),
            ),
            Opacity(
              opacity: blink,
              child: Container(
                width: 3.0,
                height: 28.0,
                margin: const EdgeInsets.only(left: 3.0),
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTagline() {
    return Opacity(
      opacity: _tagline.value,
      child: Transform.translate(
        offset: Offset(0.0, 6.0 * (1.0 - _tagline.value)),
        child: Text(
          'Master code with AI mentorship',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14.0,
            fontWeight: FontWeight.w500,
            color: AppColors.darkTextSecondary,
          ),
        ),
      ),
    );
  }
}

/// The nodes of the intro. Each node starts at a scattered position and ends on
/// a pixel of the real logo, taking that pixel's color. Built once, off the
/// asset itself, so the network assembles into the true mark.
class _NodeField {
  _NodeField._({
    required this.count,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.delay,
    required this.size,
    required this.phase,
    required this.endColor,
    required this.edges,
    required this.order,
  })  : posX = Float32List(count),
        posY = Float32List(count),
        moved = Float32List(count);

  final int count;
  final Float32List startX;
  final Float32List startY;
  final Float32List endX;
  final Float32List endY;
  final Float32List delay; // 0..0.35, so nodes do not all leave together
  final Float32List size;
  final Float32List phase; // drift phase
  final List<Color> endColor;
  final List<int> edges; // pairs of node indexes
  final Float32List order; // 0..1 position of each node in the signal sweep

  // Reused every frame so painting allocates nothing.
  final Float32List posX;
  final Float32List posY;
  final Float32List moved;

  static const int _nodes = 180;

  static Future<_NodeField> fromAsset(
    String asset, {
    required double markSize,
    required Size screen,
  }) async {
    final ByteData data = await rootBundle.load(asset);
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: 96,
    );
    final ui.Image image = (await codec.getNextFrame()).image;
    final ByteData? raw = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (raw == null) throw StateError('logo pixels unavailable');

    final int w = image.width;
    final int h = image.height;
    final List<int> opaque = <int>[];
    for (int y = 0; y < h; y += 1) {
      for (int x = 0; x < w; x += 1) {
        if (raw.getUint8((y * w + x) * 4 + 3) > 140) opaque.add(y * w + x);
      }
    }
    if (opaque.isEmpty) throw StateError('logo is empty');

    final math.Random rnd = math.Random(7);
    opaque.shuffle(rnd);
    final int n = math.min(_nodes, opaque.length);

    final Float32List sx = Float32List(n);
    final Float32List sy = Float32List(n);
    final Float32List ex = Float32List(n);
    final Float32List ey = Float32List(n);
    final Float32List delay = Float32List(n);
    final Float32List size = Float32List(n);
    final Float32List phase = Float32List(n);
    final Float32List order = Float32List(n);
    final List<Color> colors = <Color>[];

    // Scatter across the whole screen, measured from the logo's centre
    // (which sits a little above the middle of the screen).
    final double halfW = screen.width / 2 - 14;
    final double halfH = screen.height / 2 - 70;
    for (int i = 0; i < n; i++) {
      final int idx = opaque[i];
      final int px = idx % w;
      final int py = idx ~/ w;
      ex[i] = (px / w - 0.5) * markSize;
      ey[i] = (py / h - 0.5) * markSize;
      final int o = idx * 4;
      colors.add(
        Color.fromARGB(
          255,
          raw.getUint8(o),
          raw.getUint8(o + 1),
          raw.getUint8(o + 2),
        ),
      );
      sx[i] = ((rnd.nextDouble() * 2 - 1) * halfW).toDouble();
      sy[i] = ((rnd.nextDouble() * 2 - 1) * halfH + 43).toDouble();
      delay[i] = (rnd.nextDouble() * 0.35).toDouble();
      size[i] = (1.5 + rnd.nextDouble() * 1.4).toDouble();
      phase[i] = (rnd.nextDouble() * math.pi * 2).toDouble();
    }

    // Signal order: sweep from left to right across the scattered nodes.
    for (int i = 0; i < n; i++) {
      order[i] = ((sx[i] + halfW) / (halfW * 2)).clamp(0.0, 1.0).toDouble();
    }

    // Link each node to its two nearest neighbours (computed once).
    final Set<int> seen = <int>{};
    final List<int> edges = <int>[];
    for (int i = 0; i < n; i++) {
      final List<int> idxs = List<int>.generate(n, (int k) => k)
        ..remove(i)
        ..sort((int a, int b) {
          final double da = _d2(sx, sy, i, a);
          final double db = _d2(sx, sy, i, b);
          return da.compareTo(db);
        });
      for (final int j in idxs.take(2)) {
        final int lo = math.min(i, j);
        final int hi = math.max(i, j);
        if (seen.add(lo * n + hi)) {
          edges
            ..add(lo)
            ..add(hi);
        }
      }
    }

    return _NodeField._(
      count: n,
      startX: sx,
      startY: sy,
      endX: ex,
      endY: ey,
      delay: delay,
      size: size,
      phase: phase,
      endColor: colors,
      edges: edges,
      order: order,
    );
  }

  static double _d2(Float32List x, Float32List y, int a, int b) {
    final double dx = x[a] - x[b];
    final double dy = y[a] - y[b];
    return dx * dx + dy * dy;
  }
}

class _NetworkPainter extends CustomPainter {
  const _NetworkPainter({
    required this.field,
    required this.appear,
    required this.pulse,
    required this.assemble,
    required this.dissolve,
    required this.time,
  });

  final _NodeField field;
  final double appear; // nodes and links fade in
  final double pulse; // 0..1 signal sweep
  final double assemble; // 0..1 nodes travel to the logo
  final double dissolve; // 0..1 nodes fade out as the real logo resolves
  final double time;

  static const Color _idle = Color(0xFF6E7681);

  @override
  void paint(Canvas canvas, Size size) {
    if (appear <= 0.0 || dissolve >= 1.0) return;

    final Offset c = size.center(Offset.zero);
    final int n = field.count;
    final double alive = appear * (1.0 - dissolve);

    // Current position of every node.
    final Float32List px = field.posX;
    final Float32List py = field.posY;
    final Float32List move = field.moved;
    for (int i = 0; i < n; i++) {
      final double raw = ((assemble - field.delay[i]) / (1.0 - 0.35)).clamp(
        0.0,
        1.0,
      );
      final double t = Curves.easeInOutCubic.transform(raw);
      move[i] = t;
      // A slow drift while scattered; it settles as the node arrives.
      final double drift = (1.0 - t) * 5.0;
      final double wx = math.sin(time * 9.0 + field.phase[i]) * drift;
      final double wy = math.cos(time * 8.0 + field.phase[i]) * drift;
      px[i] = c.dx + field.startX[i] + (field.endX[i] - field.startX[i]) * t + wx;
      py[i] = c.dy + field.startY[i] + (field.endY[i] - field.startY[i]) * t + wy;
    }

    // Links: thin, flat, fading out as the network collapses into the logo.
    final double linkAlpha = 0.28 * alive * (1.0 - assemble);
    if (linkAlpha > 0.004) {
      final Paint link = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = _idle.withValues(alpha: linkAlpha);
      // One path for every link, so it is a single draw call.
      final Path links = Path();
      for (int e = 0; e < field.edges.length; e += 2) {
        links
          ..moveTo(px[field.edges[e]], py[field.edges[e]])
          ..lineTo(px[field.edges[e + 1]], py[field.edges[e + 1]]);
      }
      canvas.drawPath(links, link);
    }

    // Nodes: neutral while scattered, taking the logo's color on arrival. The
    // signal pulse briefly brightens the nodes it passes.
    final Paint dot = Paint();
    for (int i = 0; i < n; i++) {
      final double hit = (1.0 - ((pulse - field.order[i]).abs() * 7.0)).clamp(
        0.0,
        1.0,
      );
      final Color base = Color.lerp(_idle, field.endColor[i], move[i])!;
      final Color lit = Color.lerp(base, AppColors.primary, hit * (1.0 - move[i]))!;
      dot.color = lit.withValues(alpha: (0.55 + 0.45 * hit + 0.45 * move[i]).clamp(0.0, 1.0) * alive);
      canvas.drawCircle(
        Offset(px[i], py[i]),
        field.size[i] * (1.0 + 0.6 * hit * (1.0 - move[i])) * (1.0 - 0.25 * move[i]),
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(_NetworkPainter old) =>
      old.appear != appear ||
      old.pulse != pulse ||
      old.assemble != assemble ||
      old.dissolve != dissolve ||
      old.time != time;
}
