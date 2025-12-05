import 'package:flutter/material.dart';
import '../app_theme.dart';

class SparkAnimation extends StatelessWidget {
  final Widget child;
  final int glowTrigger;
  final Color glowColor;
  final Duration duration;
  final double height;
  final double intensity; // Parámetro para la intensidad del brillo

  const SparkAnimation({
    super.key,
    required this.child,
    required this.glowTrigger,
    this.glowColor = AppColors.primary,
    this.duration = const Duration(milliseconds: 700),
    this.height = 28,
    this.intensity = 1.0, // Valor por defecto
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        child,
        TweenAnimationBuilder<double>(
          key: ValueKey(glowTrigger),
          tween: Tween<double>(begin: 1.0, end: 0.0),
          duration: duration,
          curve: Curves.easeOutCubic,
          builder: (context, animatedOpacity, _) {
            if (animatedOpacity <= 0 || glowTrigger == 0) {
              return const SizedBox.shrink();
            }

            return IgnorePointer(
              child: Container(
                width: double.infinity,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  boxShadow: [
                    BoxShadow(
                      // La intensidad multiplica las propiedades del brillo
                      color: glowColor.withOpacity(animatedOpacity * 0.5 * intensity),
                      blurRadius: 12.0 * animatedOpacity * intensity,
                      spreadRadius: 2.0 * animatedOpacity * intensity,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
