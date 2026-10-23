import 'dart:math';
import 'package:flutter/material.dart';

class FloatingParticles extends StatefulWidget {
  final int count;
  const FloatingParticles({super.key, this.count = 70});

  @override
  State<FloatingParticles> createState() => _FloatingParticlesState();
}

class _FloatingParticlesState extends State<FloatingParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  List<_Particle>? _particles;
  Size _lastSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (_particles == null || size != _lastSize) {
          _lastSize = size;
          _particles = List.generate(widget.count, (_) => _Particle.random(size));
        }
        return RepaintBoundary(
          child: CustomPaint(
            painter: _ParticlePainter(_particles!, _ctrl),
            size: size,
          ),
        );
      },
    );
  }
}

class _Particle {
  double x, y, vx, vy, radius, alpha;
  Color color;

  static final _rng = Random();
  static const _colors = [
    Color(0xFF3B82F6),
    Color(0xFF6366F1),
    Color(0xFFA855F7),
    Color(0xFFEC4899),
  ];

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.alpha,
    required this.color,
  });

  factory _Particle.random(Size bounds) => _Particle(
        x: _rng.nextDouble() * bounds.width,
        y: _rng.nextDouble() * bounds.height,
        vx: (_rng.nextDouble() - 0.5) * 0.6,
        vy: (_rng.nextDouble() - 0.5) * 0.6,
        radius: _rng.nextDouble() * 1.8 + 0.8,
        alpha: _rng.nextDouble() * 0.45 + 0.15,
        color: _colors[_rng.nextInt(_colors.length)],
      );

  void update(Size bounds) {
    x += vx;
    y += vy;
    if (x < 0) x += bounds.width;
    if (x > bounds.width) x -= bounds.width;
    if (y < 0) y += bounds.height;
    if (y > bounds.height) y -= bounds.height;
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final Animation<double> animation;
  final _paint = Paint();

  _ParticlePainter(this.particles, this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      p.update(size);
      _paint
        ..color = p.color.withValues(alpha: p.alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.radius * 1.6);
      canvas.drawCircle(Offset(p.x, p.y), p.radius, _paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true;
}
