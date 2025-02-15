import 'package:hive/hive.dart';
part 'chemical.g.dart';

@HiveType(typeId: 0)
class Chemical extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  int inhalationTime;

  // We store points as maps for simple serialization.
  @HiveField(2)
  List<Map<String, double>> sliderPoints;

  @HiveField(3)
  List<Map<String, double>> kinematicsPoints;

  Chemical({
    required this.name,
    required this.inhalationTime,
    required this.sliderPoints,
    required this.kinematicsPoints,
  });
}
