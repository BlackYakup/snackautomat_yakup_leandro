import 'dart:io';

import 'package:flutter/material.dart';
import 'package:snackautomat_yakup_leandro/features_snack/providers/provider.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/local_file_cache.dart';

class CoinVisual extends StatelessWidget {
  const CoinVisual({
    required this.denominationCents,
    this.imagePath,
    this.size = 40,
    super.key,
  });

  final int denominationCents;
  final String? imagePath;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (imagePath != null && imagePath!.isNotEmpty && LocalFileCache.exists(imagePath)) {
      return ClipOval(
        child: Image.file(
          File(imagePath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    final colors = _coinColors(denominationCents);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [colors.$1, colors.$2],
          center: const Alignment(-0.3, -0.3),
        ),
        border: Border.all(color: colors.$3, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _coinLabel(denominationCents),
          style: TextStyle(
            color: colors.$4,
            fontSize: size * 0.28,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  (Color, Color, Color, Color) _coinColors(int cents) {
    switch (cents) {
      case 5:
        return (
          const Color(0xFFE8B4A0),
          const Color(0xFFC97B5C),
          const Color(0xFFA85D42),
          const Color(0xFF5C2E1E),
        );
      case 10:
        return (
          const Color(0xFFF5D78E),
          const Color(0xFFD4A843),
          const Color(0xFFB8922F),
          const Color(0xFF5C4518),
        );
      case 20:
        return (
          const Color(0xFFF0D080),
          const Color(0xFFCCA035),
          const Color(0xFFAA8528),
          const Color(0xFF5C4215),
        );
      case 50:
        return (
          const Color(0xFFE8C860),
          const Color(0xFFC49A28),
          const Color(0xFFA07E1E),
          const Color(0xFF5C4010),
        );
      case 100:
        return (
          const Color(0xFFE8E8E8),
          const Color(0xFFB8B8B8),
          const Color(0xFFD4AF37),
          const Color(0xFF404040),
        );
      case 200:
        return (
          const Color(0xFFE0E0E0),
          const Color(0xFFA8A8A8),
          const Color(0xFFCFA020),
          const Color(0xFF383838),
        );
      default:
        return (
          const Color(0xFFE0E0E0),
          const Color(0xFFB0B0B0),
          const Color(0xFF909090),
          const Color(0xFF404040),
        );
    }
  }

  String _coinLabel(int cents) {
    if (cents >= 100) {
      return '${cents ~/ 100}€';
    }
    return '${cents}c';
  }
}

String coinValueLabel(int cents) {
  if (cents >= 100) {
    final euros = cents ~/ 100;
  return '$euros,00 Euro';
  }
  final euroPart = cents ~/ 100;
  final centPart = cents % 100;
  return '$euroPart,${centPart.toString().padLeft(2, '0')} Euro';
}

int coinCapacityFor(int denominationCents) => coinCassetteCapacity;
