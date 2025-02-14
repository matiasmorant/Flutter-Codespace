import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  Hive.init(dir.path);
  await Hive.openBox('entries');
  await Hive.openBox('settings');

  // Initialize global controllers.
  Get.put(SettingsController());
  Get.put(EntriesController());
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isDark = Get.find<SettingsController>().isDarkMode.value;
      return GetMaterialApp(
        title: 'GetX Custom Chart Example',
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
        home: MainScreen(),
      );
    });
  }
}

class SettingsController extends GetxController {
  var isDarkMode = false.obs;
  late Box settingsBox;

  @override
  void onInit() {
    settingsBox = Hive.box('settings');
    isDarkMode.value = settingsBox.get('darkMode', defaultValue: false);
    super.onInit();
  }

  void toggleTheme() {
    isDarkMode.value = !isDarkMode.value;
    settingsBox.put('darkMode', isDarkMode.value);
  }
}

class EntriesController extends GetxController {
  late Box entriesBox;
  var entries = <String>[].obs;

  @override
  void onInit() {
    entriesBox = Hive.box('entries');
    entries.assignAll(entriesBox.values.cast<String>().toList());
    super.onInit();
  }

  void addEntry() {
    String name = 'Chemical Substance ${entries.length + 1}';
    entriesBox.add(name);
    entries.add(name);
  }

  void deleteEntry(int index) {
    entriesBox.deleteAt(index);
    entries.removeAt(index);
  }

  void renameEntry(int index, String newName) {
    entriesBox.putAt(index, newName);
    entries[index] = newName;
    entries.refresh();
  }
}

class MainScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final entriesController = Get.find<EntriesController>();
    final settingsController = Get.find<SettingsController>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Entries'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Get.defaultDialog(
                title: 'Settings',
                content: Obx(
                  () => SwitchListTile(
                    title: Text('Dark Mode'),
                    value: settingsController.isDarkMode.value,
                    onChanged: (value) {
                      settingsController.toggleTheme();
                      Get.back();
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Obx(
        () => ListView.builder(
          itemCount: entriesController.entries.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(entriesController.entries[index]),
              onTap: () => Get.to(
                  () => DetailScreen(entry: entriesController.entries[index])),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: () {
                      TextEditingController controller = TextEditingController(
                          text: entriesController.entries[index]);
                      Get.defaultDialog(
                        title: 'Rename Entry',
                        content: TextField(
                          controller: controller,
                          decoration:
                              InputDecoration(hintText: 'Enter new name'),
                        ),
                        textCancel: 'Cancel',
                        textConfirm: 'Save',
                        onConfirm: () {
                          entriesController.renameEntry(index, controller.text);
                          Get.back();
                        },
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () => entriesController.deleteEntry(index),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: entriesController.addEntry,
        child: Icon(Icons.add),
      ),
    );
  }
}

class DetailScreen extends StatelessWidget {
  final String entry;
  DetailScreen({required this.entry});

  @override
  Widget build(BuildContext context) {
    // Ensure two separate ChartControllers exist with distinct tags.
    if (!Get.isRegistered<ChartController>(tag: "slider")) {
      Get.put(ChartController(initialPoints: [Offset(1, 1), Offset(2, 2), Offset(3, 3)]),
          tag: "slider");
    }
    if (!Get.isRegistered<ChartController>(tag: "kinematics")) {
      Get.put(ChartController(initialPoints: [Offset(1, 2), Offset(2, 3), Offset(3, 4)]),
          tag: "kinematics");
    }

    return Scaffold(
      appBar: AppBar(title: Text(entry)),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Slider',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            CustomChartWidget(tag: "slider"),
            SizedBox(height: 32),
            Text('Kinematics',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            CustomChartWidget(tag: "kinematics"),
          ],
        ),
      ),
    );
  }
}

class ChartController extends GetxController {
  // Holds chart data points.
  var points = <Offset>[].obs;

  ChartController({required List<Offset> initialPoints}) {
    points.assignAll(initialPoints);
  }

  void updatePoint(int index, Offset newPoint) {
    points[index] = newPoint;
    points.refresh();
  }
}

class CustomChartWidget extends StatefulWidget {
  final String tag;
  const CustomChartWidget({Key? key, required this.tag}) : super(key: key);

  @override
  _CustomChartWidgetState createState() => _CustomChartWidgetState();
}

class _CustomChartWidgetState extends State<CustomChartWidget> {
  late ChartController chartController;
  int draggedIndex = -1;
  Offset? dragStart;

  // Compute data bounds (min and max for x and y).
  Map<String, double> computeBounds(List<Offset> points) {
    double minX = points.first.dx;
    double maxX = points.first.dx;
    double minY = points.first.dy;
    double maxY = points.first.dy;
    for (Offset p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    return {'minX': minX, 'maxX': maxX, 'minY': minY, 'maxY': maxY};
  }

  // Convert a data point into canvas coordinates.
  Offset dataToPixel(
      Offset data, Size size, double minX, double maxX, double minY, double maxY) {
    double x = (data.dx - minX) / ((maxX - minX) == 0 ? 1 : (maxX - minX)) *
        size.width;
    double y = size.height -
        ((data.dy - minY) / ((maxY - minY) == 0 ? 1 : (maxY - minY)) *
            size.height);
    return Offset(x, y);
  }

  @override
  void initState() {
    super.initState();
    chartController = Get.find<ChartController>(tag: widget.tag);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        RenderBox box = context.findRenderObject() as RenderBox;
        Offset localPos = box.globalToLocal(details.globalPosition);
        var bounds = computeBounds(chartController.points);
        double minX = bounds['minX']!;
        double maxX = bounds['maxX']!;
        double minY = bounds['minY']!;
        double maxY = bounds['maxY']!;
        // Check if the touch is near any point.
        for (int i = 0; i < chartController.points.length; i++) {
          Offset point = chartController.points[i];
          Offset pixel = dataToPixel(point, box.size, minX, maxX, minY, maxY);
          if ((pixel - localPos).distance < 20) {
            draggedIndex = i;
            dragStart = localPos;
            break;
          }
        }
      },
      onPanUpdate: (details) {
        if (draggedIndex != -1 && dragStart != null) {
          RenderBox box = context.findRenderObject() as RenderBox;
          Offset localPos = box.globalToLocal(details.globalPosition);
          var bounds = computeBounds(chartController.points);
          double minX = bounds['minX']!;
          double maxX = bounds['maxX']!;
          double minY = bounds['minY']!;
          double maxY = bounds['maxY']!;
          double dx = localPos.dx - dragStart!.dx;
          double dy = localPos.dy - dragStart!.dy;
          double scaleX = (maxX - minX) / box.size.width;
          double scaleY = (maxY - minY) / box.size.height;
          // Invert y-axis movement.
          double newX = chartController.points[draggedIndex].dx + dx * scaleX;
          double newY = chartController.points[draggedIndex].dy - dy * scaleY;
          chartController.updatePoint(draggedIndex, Offset(newX, newY));
          dragStart = localPos;
        }
      },
      onPanEnd: (details) {
        draggedIndex = -1;
        dragStart = null;
      },
      child: Container(
        height: 300,
        width: double.infinity,
        child: Obx(() {
          return CustomPaint(
            painter: LineChartPainter(points: chartController.points.toList()),
            child: Container(),
          );
        }),
      ),
    );
  }
}

class LineChartPainter extends CustomPainter {
  final List<Offset> points;
  // Use a single color for both the line and points.
  final Color chartColor = Colors.blue;

  LineChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // Compute boundaries.
    double minX = points.first.dx;
    double maxX = points.first.dx;
    double minY = points.first.dy;
    double maxY = points.first.dy;
    for (Offset p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    double rangeX = maxX - minX;
    double rangeY = maxY - minY;
    if (rangeX == 0) rangeX = 1;
    if (rangeY == 0) rangeY = 1;

    // Map data points to canvas coordinates.
    List<Offset> mappedPoints = points.map((p) {
      double x = (p.dx - minX) / rangeX * size.width;
      double y = size.height - ((p.dy - minY) / rangeY * size.height);
      return Offset(x, y);
    }).toList();

    // Draw axes.
    Paint axisPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1;

    // x-axis: from bottom left to bottom right.
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), axisPaint);
    // y-axis: from bottom left to top left.
    canvas.drawLine(Offset(0, size.height), Offset(0, 0), axisPaint);

    // Draw ticks and labels.
    const int tickCount = 5;
    final textStyle = TextStyle(color: Colors.black, fontSize: 10);
    // x-axis ticks.
    for (int i = 0; i <= tickCount; i++) {
      double tickX = i * size.width / tickCount;
      double tickValue = minX + (rangeX) * i / tickCount;
      // Tick mark.
      canvas.drawLine(Offset(tickX, size.height), Offset(tickX, size.height - 5), axisPaint);
      // Draw text.
      TextPainter tp = TextPainter(
        text: TextSpan(text: tickValue.toStringAsFixed(1), style: textStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(tickX - tp.width / 2, size.height + 2));
    }
    // y-axis ticks.
    for (int i = 0; i <= tickCount; i++) {
      double tickY = size.height - i * size.height / tickCount;
      double tickValue = minY + (rangeY) * i / tickCount;
      canvas.drawLine(Offset(0, tickY), Offset(5, tickY), axisPaint);
      TextPainter tp = TextPainter(
        text: TextSpan(text: tickValue.toStringAsFixed(1), style: textStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(-tp.width - 2, tickY - tp.height / 2));
    }

    // Draw the chart line.
    Paint linePaint = Paint()
      ..color = chartColor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    Path path = Path();
    path.moveTo(mappedPoints.first.dx, mappedPoints.first.dy);
    for (int i = 1; i < mappedPoints.length; i++) {
      path.lineTo(mappedPoints[i].dx, mappedPoints[i].dy);
    }
    canvas.drawPath(path, linePaint);

    // Draw data points.
    Paint circlePaint = Paint()
      ..color = chartColor
      ..style = PaintingStyle.fill;
    for (Offset p in mappedPoints) {
      canvas.drawCircle(p, 6, circlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
