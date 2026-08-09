part of 'power3d_controller.dart';

/// Ergebnis einer Hotspot-Projektion (Fraktionen 0…1 relativ zum Canvas).
class ProjectedHotspot {
  const ProjectedHotspot({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.visible,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final bool visible;
}

/// Weltpunkt in Babylon-Koordinaten.
class WorldPoint {
  const WorldPoint(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;

  Map<String, double> toJson() => {'x': x, 'y': y, 'z': z};

  factory WorldPoint.fromJson(Map<String, dynamic> json) => WorldPoint(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
        (json['z'] as num).toDouble(),
      );
}

/// Vier Ecken eines Hotspot-Rechtecks in der Welt.
class WorldQuad {
  const WorldQuad({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  final WorldPoint topLeft;
  final WorldPoint topRight;
  final WorldPoint bottomRight;
  final WorldPoint bottomLeft;

  List<WorldPoint> get points => [topLeft, topRight, bottomRight, bottomLeft];

  Map<String, dynamic> toJson() => {
        'tl': topLeft.toJson(),
        'tr': topRight.toJson(),
        'br': bottomRight.toJson(),
        'bl': bottomLeft.toJson(),
      };

  factory WorldQuad.fromJson(Map<String, dynamic> json) {
    WorldPoint p(String k) {
      final m = json[k];
      if (m is Map<String, dynamic>) return WorldPoint.fromJson(m);
      if (m is Map) {
        return WorldPoint.fromJson(Map<String, dynamic>.from(m));
      }
      return const WorldPoint(0, 0, 0);
    }

    return WorldQuad(
      topLeft: p('tl'),
      topRight: p('tr'),
      bottomRight: p('br'),
      bottomLeft: p('bl'),
    );
  }
}

/// Projizierter Screen-Punkt (Canvas-Pixel).
class ProjectedScreenPoint {
  const ProjectedScreenPoint({
    required this.x,
    required this.y,
    required this.z,
    required this.visible,
    required this.canvasWidth,
    required this.canvasHeight,
  });

  final double x;
  final double y;
  final double z;
  final bool visible;
  final double canvasWidth;
  final double canvasHeight;
}

/// Treffer eines Screen-Picks.
class PickHit {
  const PickHit({
    required this.x,
    required this.y,
    required this.z,
    this.meshName,
  });

  final double x;
  final double y;
  final double z;
  final String? meshName;
}

