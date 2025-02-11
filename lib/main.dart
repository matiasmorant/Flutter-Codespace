import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
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
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Using Obx here to reactively change the theme.
    return Obx(() {
      final isDark = Get.find<SettingsController>().isDarkMode.value;
      return GetMaterialApp(
        title: 'GetX Hive Example',
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
              // Use Get.defaultDialog to show the settings dialog.
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
              onTap: () => Get.to(() =>
                  DetailScreen(entry: entriesController.entries[index])),
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
  final GraphController graphController = Get.put(GraphController());
  int draggedIndex = -1;
  Offset? dragStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: GestureDetector(
        onPanUpdate: (details) {
          RenderBox box = context.findRenderObject() as RenderBox;
          Offset localPosition = box.globalToLocal(details.globalPosition);
          if (draggedIndex >= 0 && dragStart != null) {
            // Calculate chart boundaries dynamically from current points.
            double minX = graphController.points
                .reduce((curr, next) => next.x < curr.x ? next : curr)
                .x;
            double maxX = graphController.points
                .reduce((curr, next) => next.x > curr.x ? next : curr)
                .x;
            double minY = graphController.points
                .reduce((curr, next) => next.y < curr.y ? next : curr)
                .y;
            double maxY = graphController.points
                .reduce((curr, next) => next.y > curr.y ? next : curr)
                .y;
            double dx = localPosition.dx - dragStart!.dx;
            double dy = localPosition.dy - dragStart!.dy;
            double newX = graphController.points[draggedIndex].x +
                dx * (maxX - minX) / box.size.width;
            double newY = graphController.points[draggedIndex].y +
                dy * (maxY - minY) / box.size.height;
            graphController.updatePoint(draggedIndex, FlSpot(newX, newY));
            dragStart = localPosition;
          }
        },
        child: Center(
          child: Container(
            height: 300,
            child: Obx(() {
              // Determine boundaries based on the current points.
              double minX = graphController.points
                  .reduce((curr, next) => next.x < curr.x ? next : curr)
                  .x;
              double maxX = graphController.points
                  .reduce((curr, next) => next.x > curr.x ? next : curr)
                  .x;
              double minY = graphController.points
                  .reduce((curr, next) => next.y < curr.y ? next : curr)
                  .y;
              double maxY = graphController.points
                  .reduce((curr, next) => next.y > curr.y ? next : curr)
                  .y;

              LineChartData lineChartData = LineChartData(
                minX: minX,
                maxX: maxX,
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: List.of(graphController.points),
                    isCurved: true,
                    barWidth: 4,
                    color: Colors.blue,
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                    if (event is FlPanEndEvent) {
                      draggedIndex = -1;
                    }
                    if (response != null &&
                        response.lineBarSpots != null &&
                        draggedIndex < 0) {
                      final spot = response.lineBarSpots!.first;
                      draggedIndex = spot.spotIndex;
                      dragStart = event.localPosition;
                      print(
                          'selected: ${spot.x}, ${spot.y} (${dragStart?.dx}, ${dragStart?.dy})');
                    }
                  },
                  handleBuiltInTouches: true,
                ),
              );
              return LineChart(lineChartData);
            }),
          ),
        ),
      ),
    );
  }
}

class GraphController extends GetxController {
  var points = <FlSpot>[].obs;

  @override
  void onInit() {
    points.assignAll([FlSpot(1, 1), FlSpot(2, 2), FlSpot(3, 3)]);
    super.onInit();
  }

  void updatePoint(int index, FlSpot newSpot) {
    points[index] = newSpot;
    points.refresh();
  }
}
