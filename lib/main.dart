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

// MainScreen now uses a stateful widget to track the currently selected entry.
class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = -1;

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
            bool isSelected = index == selectedIndex;
            return ListTile(
              title: Text(entriesController.entries[index]),
              tileColor:
                  isSelected ? Theme.of(context).highlightColor : null,
              onTap: () {
                setState(() {
                  selectedIndex = index;
                });
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pencil icon routes to the detail screen for editing.
                  IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: () {
                      Get.to(() => DetailScreen(
                            entry: entriesController.entries[index],
                            index: index,
                          ));
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

// -------------------------------------------------
// DetailScreen is a stateful widget to handle
// the top-bar editable entry name and the small
// inhalation time input above the Slider chart.
// -------------------------------------------------
class DetailScreen extends StatefulWidget {
  final String entry;
  final int index;
  DetailScreen({required this.entry, required this.index});

  @override
  _DetailScreenState createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late TextEditingController _entryController;
  late TextEditingController _inhalationTimeController;

  @override
  void initState() {
    super.initState();
    _entryController = TextEditingController(text: widget.entry);
    _inhalationTimeController = TextEditingController(text: "10");
  }

  @override
  void dispose() {
    _entryController.dispose();
    _inhalationTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ensure two separate ChartControllers exist with distinct tags.
    if (!Get.isRegistered<ChartController>(tag: "slider")) {
      Get.put(
          ChartController(
              initialPoints: [Offset(1, 1), Offset(2, 2), Offset(3, 3)]),
          tag: "slider");
    }
    if (!Get.isRegistered<ChartController>(tag: "kinematics")) {
      Get.put(
          ChartController(
              initialPoints: [Offset(1, 2), Offset(2, 3), Offset(3, 4)]),
          tag: "kinematics");
    }

    return Scaffold(
      appBar: AppBar(
        // Editable entry name using theme-based colors.
        title: TextField(
          controller: _entryController,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 18,
          ),
          cursorColor: Theme.of(context).colorScheme.onPrimary,
          decoration: InputDecoration(
            hintText: 'Enter entry name',
            hintStyle: TextStyle(
              color:
                  Theme.of(context).colorScheme.onPrimary.withOpacity(0.6),
            ),
            border: InputBorder.none,
            // Use the app bar's background color for the text field.
            filled: true,
            fillColor: Theme.of(context).appBarTheme.backgroundColor ??
                Theme.of(context).primaryColor,
          ),
          onSubmitted: (newName) {
            Get.find<EntriesController>().renameEntry(widget.index, newName);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Smaller inhalation time input with a fixed width and maxLength 2.
            Container(
              width: 80,
              child: TextField(
                controller: _inhalationTimeController,
                decoration: InputDecoration(
                  labelText: 'inhalation time [s]',
                  counterText: '',
                ),
                keyboardType: TextInputType.number,
                maxLength: 2,
              ),
            ),
            SizedBox(height: 16),
            Text('Slider',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            // Center the chart horizontally.
            Center(child: CustomChartWidget(tag: "slider")),
            SizedBox(height: 32),
            Text('Kinematics',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            // Center the chart horizontally.
            Center(child: CustomChartWidget(tag: "kinematics")),
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
  Offset? currentDragPoint; // Track the currently dragged point (data coordinates)

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
    double x = (data.dx - minX) /
        ((maxX - minX) == 0 ? 1 : (maxX - minX)) *
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
    final theme = Theme.of(context);
    // Use the theme's text color for axes, ticks, and labels.
    final axisColor = theme.textTheme.bodySmall?.color ?? Colors.black;

    return GestureDetector(
      onPanStart: (details) {
        RenderBox box = context.findRenderObject() as RenderBox;
        Offset localPos = box.globalToLocal(details.globalPosition);
        var bounds = computeBounds(chartController.points);
        double minX = bounds['minX']!;
        double maxX = bounds['maxX']!;
        double minY = bounds['minY']!;
        double maxY = bounds['maxY']!;
        bool found = false;
        // Check if the touch is near any point.
        for (int i = 0; i < chartController.points.length; i++) {
          Offset point = chartController.points[i];
          Offset pixel = dataToPixel(point, box.size, minX, maxX, minY, maxY);
          if ((pixel - localPos).distance < 20) {
            draggedIndex = i;
            dragStart = localPos;
            found = true;
            break;
          }
        }
        // If no point was near the touch, create a new point.
        if (!found) {
          double newDataX =
              minX + (localPos.dx / box.size.width) * (maxX - minX);
          double newDataY = minY +
              ((box.size.height - localPos.dy) / box.size.height) * (maxY - minY);
          chartController.points.add(Offset(newDataX, newDataY));
          chartController.points.refresh();
          draggedIndex = chartController.points.length - 1;
          dragStart = localPos;
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
          setState(() {
            currentDragPoint = chartController.points[draggedIndex];
          });
        }
      },
      onPanEnd: (details) {
        draggedIndex = -1;
        dragStart = null;
        setState(() {
          currentDragPoint = null;
        });
      },
      child: Container(
        height: 250, 
        width: MediaQuery.of(context).size.width * 0.8,
        child: Obx(() {
          // Determine axis labels based on the widget tag.
          String xAxisLabel;
          String yAxisLabel;
          if (widget.tag == "slider") {
            xAxisLabel = "position";
            yAxisLabel = "dose";
          } else if (widget.tag == "kinematics") {
            xAxisLabel = "time [m]";
            yAxisLabel = "intensity";
          } else {
            xAxisLabel = "";
            yAxisLabel = "";
          }
          return CustomPaint(
            painter: LineChartPainter(
              points: chartController.points.toList(),
              xAxisLabel: xAxisLabel,
              yAxisLabel: yAxisLabel,
              axisColor: axisColor,
              draggedPoint: currentDragPoint, // pass the currently dragged point
            ),
            child: Container(),
          );
        }),
      ),
    );
  }
}

class LineChartPainter extends CustomPainter {
  final List<Offset> points;
  final String xAxisLabel;
  final String yAxisLabel;
  final Color axisColor; // Color for axes, ticks, and labels.
  final Offset? draggedPoint; // The point currently being dragged (if any)
  // Chart line and data points remain blue.
  final Color chartColor = Colors.blue;

  LineChartPainter({
    required this.points,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.axisColor,
    this.draggedPoint,
  });

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

    // -------------------------
    // Draw background grid.
    // -------------------------
    const int tickCount = 5;
    Paint gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 1;
    // Vertical grid lines.
    for (int i = 0; i <= tickCount; i++) {
      double x = i * size.width / tickCount;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    // Horizontal grid lines.
    for (int i = 0; i <= tickCount; i++) {
      double y = size.height - i * size.height / tickCount;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // -------------------------
    // Draw axes.
    // -------------------------
    Paint axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    // x-axis: from bottom left to bottom right.
    canvas.drawLine(
        Offset(0, size.height), Offset(size.width, size.height), axisPaint);
    // y-axis: from bottom left to top left.
    canvas.drawLine(Offset(0, size.height), Offset(0, 0), axisPaint);

    // -------------------------
    // Draw ticks and labels.
    // -------------------------
    final textStyle = TextStyle(color: axisColor, fontSize: 10);
    // x-axis ticks.
    for (int i = 0; i <= tickCount; i++) {
      double tickX = i * size.width / tickCount;
      double tickValue = minX + (rangeX) * i / tickCount;
      // Tick mark.
      canvas.drawLine(
          Offset(tickX, size.height),
          Offset(tickX, size.height - 5),
          axisPaint);
      // Draw text.
      TextPainter tp = TextPainter(
        text: TextSpan(text: tickValue.toStringAsFixed(1), style: textStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(tickX - tp.width / 2, size.height + 2));
    }
    // y-axis ticks (displayed as percentages).
    for (int i = 0; i <= tickCount; i++) {
      double tickY = size.height - i * size.height / tickCount;
      double tickValue = minY + (rangeY) * i / tickCount;
      canvas.drawLine(Offset(0, tickY), Offset(5, tickY), axisPaint);
      String tickText = (tickValue * 100).toStringAsFixed(0) + "%";
      TextPainter tp = TextPainter(
        text: TextSpan(text: tickText, style: textStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(-tp.width - 2, tickY - tp.height / 2));
    }

    // -------------------------
    // Draw axis labels.
    // -------------------------
    final labelStyle = TextStyle(color: axisColor, fontSize: 12);
    // x-axis label: centered below the axis.
    TextPainter xLabelPainter = TextPainter(
      text: TextSpan(text: xAxisLabel, style: labelStyle),
      textDirection: TextDirection.ltr,
    );
    xLabelPainter.layout();
    xLabelPainter.paint(
        canvas,
        Offset(size.width / 2 - xLabelPainter.width / 2,
            size.height + 15));

    // y-axis label: rotated and centered along the y-axis.
    canvas.save();
    TextPainter yLabelPainter = TextPainter(
      text: TextSpan(text: yAxisLabel, style: labelStyle),
      textDirection: TextDirection.ltr,
    );
    yLabelPainter.layout();
    canvas.translate(-25, size.height / 2 + yLabelPainter.width / 2);
    canvas.rotate(-3.14159 / 2);
    yLabelPainter.paint(canvas, Offset(0, 0));
    canvas.restore();

    // -------------------------
    // Draw the chart line.
    // -------------------------
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

    // -------------------------
    // Draw data points.
    // -------------------------
    Paint circlePaint = Paint()
      ..color = chartColor
      ..style = PaintingStyle.fill;
    for (Offset p in mappedPoints) {
      canvas.drawCircle(p, 6, circlePaint);
    }

    // -------------------------
    // If dragging, draw coordinate labels.
    // -------------------------
    if (draggedPoint != null) {
      // Convert dragged data point to canvas coordinates.
      double dragPixelX = (draggedPoint!.dx - minX) / rangeX * size.width;
      double dragPixelY = size.height -
          ((draggedPoint!.dy - minY) / rangeY * size.height);

      // X-axis coordinate label.
      String xDragText = draggedPoint!.dx.toStringAsFixed(1);
      TextPainter xDragPainter = TextPainter(
        text: TextSpan(text: xDragText, style: TextStyle(color: Colors.red, fontSize: 12)),
        textDirection: TextDirection.ltr,
      );
      xDragPainter.layout();
      xDragPainter.paint(
          canvas, Offset(dragPixelX - xDragPainter.width / 2, size.height - 20));

      // Y-axis coordinate label (as percentage).
      String yDragText = (draggedPoint!.dy * 100).toStringAsFixed(0) + "%";
      TextPainter yDragPainter = TextPainter(
        text: TextSpan(text: yDragText, style: TextStyle(color: Colors.red, fontSize: 12)),
        textDirection: TextDirection.ltr,
      );
      yDragPainter.layout();
      yDragPainter.paint(
          canvas, Offset(-yDragPainter.width - 5, dragPixelY - yDragPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
