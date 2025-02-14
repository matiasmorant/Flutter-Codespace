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

  // Initialize our controllers so they’re available app-wide.
  Get.put(SettingsController());
  Get.put(EntriesController());
  Get.put(GraphController());
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Using Obx to reactively update the theme.
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
              // Use Get.defaultDialog for the settings dialog.
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
    return Scaffold(
      appBar: AppBar(title: Text(entry)),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () => Get.to(() => GraphScreen(title: 'Slider')),
            child: Text('Slider'),
          ),
          ElevatedButton(
            onPressed: () => Get.to(() => GraphScreen(title: 'Kinematics')),
            child: Text('Kinematics'),
          ),
        ],
      ),
    );
  }
}

class GraphScreen extends StatefulWidget {
  final String title;
  GraphScreen({required this.title});

  @override
  _GraphScreenState createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  final GraphController graphController = Get.find<GraphController>();
  int draggedIndex = -1;
  Offset? dragStart;

  // Computes the minimum and maximum values for x and y.
  Map<String, double> computeBounds() {
    List<Offset> points = graphController.points;
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

  // Converts a data point to a pixel position within the given size.
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: GestureDetector(
        onPanStart: (details) {
          RenderBox box = context.findRenderObject() as RenderBox;
          Offset localPos = box.globalToLocal(details.globalPosition);
          var bounds = computeBounds();
          double minX = bounds['minX']!;
          double maxX = bounds['maxX']!;
          double minY = bounds['minY']!;
          double maxY = bounds['maxY']!;
          // Check if the touch is near any of the points.
          for (int i = 0; i < graphController.points.length; i++) {
            Offset point = graphController.points[i];
            Offset pixel = dataToPixel(point, box.size, minX, maxX, minY, maxY);
            print('Match? $pixel = $localPos');
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
            var bounds = computeBounds();
            double minX = bounds['minX']!;
            double maxX = bounds['maxX']!;
            double minY = bounds['minY']!;
            double maxY = bounds['maxY']!;
            double dx = localPos.dx - dragStart!.dx;
            double dy = localPos.dy - dragStart!.dy;
            // Scale factors from pixel movement to data space.
            double scaleX = (maxX - minX) / box.size.width;
            double scaleY = (maxY - minY) / box.size.height;
            // Note the inversion for the y-axis.
            double newX = graphController.points[draggedIndex].dx + dx * scaleX;
            double newY = graphController.points[draggedIndex].dy - dy * scaleY;
            graphController.updatePoint(draggedIndex, Offset(newX, newY));
            dragStart = localPos;
          }
        },
        onPanEnd: (details) {
          draggedIndex = -1;
          dragStart = null;
        },
        child: Center(
          child: Container(
            height: 300,
            width: double.infinity,
            child: Obx(() {
              return CustomPaint(
                painter: LineChartPainter(
                    points: graphController.points.toList()),
                child: Container(),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class GraphController extends GetxController {
  // Using Offset to represent each point (x, y)
  var points = <Offset>[].obs;

  @override
  void onInit() {
    points.assignAll([Offset(1, 1), Offset(2, 2), Offset(3, 3)]);
    super.onInit();
  }

  void updatePoint(int index, Offset newPoint) {
    points[index] = newPoint;
    points.refresh();
  }
}

class LineChartPainter extends CustomPainter {
  final List<Offset> points;

  LineChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // Calculate boundaries.
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

    // Paint for the connecting line.
    Paint linePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    // Paint for the data points.
    Paint circlePaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    Path path = Path();
    path.moveTo(mappedPoints[0].dx, mappedPoints[0].dy);
    for (int i = 1; i < mappedPoints.length; i++) {
      path.lineTo(mappedPoints[i].dx, mappedPoints[i].dy);
    }
    canvas.drawPath(path, linePaint);

    // Draw circles for each data point.
    for (Offset p in mappedPoints) {
      canvas.drawCircle(p, 6, circlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
