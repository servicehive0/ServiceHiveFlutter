import 'package:flutter/material.dart';
import '../core/theme.dart';

class GradientBg extends StatelessWidget {
  final Widget child;

  const GradientBg({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _Orb(color: AppColors.primary, top: -120, left: -120),
        const _Orb(color: Color(0xFF6366F1), bottom: -120, right: -120),
        child,
      ],
    );
  }
}

class _Orb extends StatefulWidget {
  final Color color;
  final double? top;
  final double? left;
  final double? bottom;
  final double? right;

  const _Orb({required this.color, this.top, this.left, this.bottom, this.right});

  @override
  State<_Orb> createState() => _OrbState();
}

class _OrbState extends State<_Orb> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 20))
      ..repeat(reverse: true);
    _anim = Tween<Offset>(begin: Offset.zero, end: const Offset(0.05, 0.04)).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.top,
      left: widget.left,
      bottom: widget.bottom,
      right: widget.right,
      child: SlideTransition(
        position: _anim,
        child: Container(
          width: 350,
          height: 350,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withOpacity(0.15),
          ),
          child: BackdropFilter(
            filter: _blurFilter,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  static final _blurFilter = _buildBlur();
  static _buildBlur() {
    return ColorFilter.mode(Colors.transparent, BlendMode.clear);
  }
}
