import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

// Import our custom model.
import 'chemical.dart';

double clip(double value, double lower, double upper) {
  return value < lower ? lower : (value > upper ? upper : value);
}

Offset sliderConstraint(Offset newCoord, List<Offset> points, int index) {
  double lower = index > 0 ? points[index - 1].dy : 0;
  double upper = index < points.length - 1 ? points[index + 1].dy : 1;
  return Offset(points[index].dx, clip(newCoord.dy, lower, upper));
}

Offset kinematicsConstraint(Offset newCoord, List<Offset> points, int index) {
  double lower = index > 0 ? points[index - 1].dx : 0;
  double upper = index < points.length - 1 ? points[index + 1].dx : 1000;
  return Offset(clip(newCoord.dx, lower, upper), clip(newCoord.dy, 0.0, 1.0));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  Hive.init(dir.path);
  Hive.registerAdapter(ChemicalAdapter());
  await Hive.openBox<Chemical>('chemicals');
  await Hive.openBox('settings');

  // Initialize global controllers.
  Get.put(SettingsController());
  Get.put(ChemicalsController());
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isDark = Get.find<SettingsController>().isDarkMode.value;
      return GetMaterialApp(
        theme: ThemeData.light().copyWith(
           appBarTheme: AppBarTheme(
              // iconTheme: IconThemeData(color: Colors.black),
              color: ThemeData.light().colorScheme.primaryContainer
          ),
        ),
        darkTheme: ThemeData.dark().copyWith(
           appBarTheme: AppBarTheme(
              // iconTheme: IconThemeData(color: Colors.black),
              color: ThemeData.dark().colorScheme.primaryContainer
          )
        ),
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

class ChemicalsController extends GetxController {
  late Box<Chemical> chemicalsBox;
  var chemicals = <Chemical>[].obs;

  @override
  void onInit() {
    chemicalsBox = Hive.box<Chemical>('chemicals');
    chemicals.assignAll(chemicalsBox.values.toList());
    super.onInit();
  }

  void addChemical() {
    final newChemical = Chemical(
      name: 'Chemical Substance ${chemicals.length + 1}',
      inhalationTime: 10,
      sliderPoints: [
        {"x": 0, "y": 0},
        {"x": 1, "y": 0.25},
        {"x": 2, "y": 0.5},
        {"x": 3, "y": 0.75},
        {"x": 4, "y": 1},
      ],
      kinematicsPoints: [
        {"x": 0, "y": 1},
        {"x": 60, "y": 0},
      ],
    );
    chemicalsBox.add(newChemical);
    chemicals.add(newChemical);
  }

  void deleteChemical(int index) {
    chemicalsBox.deleteAt(index);
    chemicals.removeAt(index);
  }

  void renameChemical(int index, String newName) {
    final chemical = chemicals[index];
    chemical.name = newName;
    chemical.save();
    chemicals[index] = chemical;
    chemicals.refresh();
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = -1;
  @override
  Widget build(BuildContext context) {
    final chemicalsController = Get.find<ChemicalsController>();
    final settingsController = Get.find<SettingsController>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Chemicals'),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert),
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
          itemCount: chemicalsController.chemicals.length,
          itemBuilder: (context, index) {
            bool isSelected = index == selectedIndex;
            Chemical chemical = chemicalsController.chemicals[index];
            return ListTile(
              title: Text(chemical.name),
              tileColor:
                  isSelected ? Theme.of(context).highlightColor : null,
              onTap: () {
                setState(() {
                  selectedIndex = index;
                });
              },
              trailing: IconButton(
                icon: Icon(Icons.edit),
                onPressed: () {
                  Get.to(() => DetailScreen(chemical: chemical, index: index));
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: chemicalsController.addChemical,
        child: Icon(Icons.add),
      ),
    );
  }
}

class DetailScreen extends StatefulWidget {
  final Chemical chemical;
  final int index;
  DetailScreen({required this.chemical, required this.index});

  @override
  _DetailScreenState createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late TextEditingController _chemicalController;
  late TextEditingController _inhalationTimeController;

  @override
  void initState() {
    super.initState();
    _chemicalController = TextEditingController(text: widget.chemical.name);
    _inhalationTimeController =
        TextEditingController(text: widget.chemical.inhalationTime.toString());

    // Initialize ChartControllers with existing points.
    if (!Get.isRegistered<ChartController>(tag: "slider")) {
      Get.put(
          ChartController(
              initialPoints: widget.chemical.sliderPoints
                  .map((map) => Offset(map["x"] ?? 0, map["y"] ?? 0))
                  .toList()),
          tag: "slider");
    }
    if (!Get.isRegistered<ChartController>(tag: "kinematics")) {
      Get.put(
          ChartController(
              initialPoints: widget.chemical.kinematicsPoints
                  .map((map) => Offset(map["x"] ?? 0, map["y"] ?? 0))
                  .toList()),
          tag: "kinematics");
    }
  }

  @override
  void dispose() {
    _chemicalController.dispose();
    _inhalationTimeController.dispose();
    super.dispose();
  }

  void _deleteChemical() {
    Get.defaultDialog(
      title: 'Confirm Delete',
      middleText: 'Are you sure you want to delete this chemical?',
      textCancel: 'Cancel',
      textConfirm: 'Delete',
      onConfirm: () {
        Get.find<ChemicalsController>().deleteChemical(widget.index);
        Get.back(); // close dialog
        Get.back(); // return to home screen
      },
    );
  }

  // Persist the updated data to Hive.
  void _persistChanges() {
    final chemicalsController = Get.find<ChemicalsController>();
    Chemical currentChemical = chemicalsController.chemicals[widget.index];
    currentChemical.name = _chemicalController.text;
    currentChemical.inhalationTime =
        int.tryParse(_inhalationTimeController.text) ?? 10;
    currentChemical.sliderPoints = Get.find<ChartController>(tag: "slider")
        .points
        .map((offset) => {"x": offset.dx, "y": offset.dy})
        .toList();
    currentChemical.kinematicsPoints = Get.find<ChartController>(tag: "kinematics")
        .points
        .map((offset) => {"x": offset.dx, "y": offset.dy})
        .toList();
    currentChemical.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _chemicalController,
          style: TextStyle(fontSize: 18,),
          cursorColor: Theme.of(context).colorScheme.onPrimary,
          decoration: InputDecoration(
            hintText: 'Enter chemical name',
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.6),
            ),
            border: InputBorder.none,
            filled: true,
            fillColor: Theme.of(context).appBarTheme.backgroundColor ??
                Theme.of(context).primaryColor,
          ),
          onSubmitted: (newName) {
            Get.find<ChemicalsController>().renameChemical(widget.index, newName);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: _deleteChemical,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                onSubmitted: (value) => _persistChanges(),
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Slider',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Obx(() {
                  final isUndoEnabled = Get.find<ChartController>(tag: "slider").undoStack.isNotEmpty;
                  return IconButton(
                    icon: Icon(Icons.undo, color: isUndoEnabled ? null : Theme.of(context).disabledColor),
                    onPressed: () => Get.find<ChartController>(tag: "slider").undo(),
                  );
                }),
              ],
            ),
            SizedBox(height: 8),
            Center(
              child: CustomChartWidget(
                tag: "slider",
                xAxisLabel: "position",
                yAxisLabel: "dose",
                constraint: sliderConstraint,
                allowCreateDelete: false,
                minX: 0,
                maxX: 4,
                minY: 0,
                maxY: 1,
                onPersist: _persistChanges,
              ),
            ),
            SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Kinematics',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Obx(() {
                  final isUndoEnabled = Get.find<ChartController>(tag: "kinematics").undoStack.isNotEmpty;
                  return IconButton(
                    icon: Icon(Icons.undo, color: isUndoEnabled ? null : Theme.of(context).disabledColor),
                    onPressed: () => Get.find<ChartController>(tag: "kinematics").undo(),
                  );
                }),
              ],
            ),
            SizedBox(height: 8),
            Center(
              child: CustomChartWidget(
                tag: "kinematics",
                xAxisLabel: "time [m]",
                yAxisLabel: "intensity",
                constraint: kinematicsConstraint,
                minX: 0,
                minY: 0,
                maxY: 1,
                onPersist: _persistChanges,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChartController extends GetxController {
  var points = <Offset>[].obs;
  final undoStack = <List<Offset>>[];

  ChartController({required List<Offset> initialPoints}) {
    points.assignAll(initialPoints);
  }

  void updatePoint(int index, Offset newPoint) {
    points[index] = newPoint;
    points.refresh();
  }

  void addPoint(Offset newPoint) {
    undoStack.add(List.from(points));
    points.add(newPoint);
    points.sort((a, b) => a.dx.compareTo(b.dx));
    points.refresh();
  }

  void removePoint(int index) {
    undoStack.add(List.from(points));
    points.removeAt(index);
    points.refresh();
  }

  void undo() {
    if (undoStack.isNotEmpty) {
      points.assignAll(undoStack.removeLast());
    }
  }
}

class CustomChartWidget extends StatefulWidget {
  final String tag;
  final String xAxisLabel;
  final String yAxisLabel;
  final Offset Function(Offset newCoord, List<Offset> points, int index)? constraint;
  final bool allowCreateDelete;
  double? minX;
  double? maxX;
  double? minY;
  double? maxY;
  final bool minXauto;
  final bool maxXauto;
  final bool minYauto;
  final bool maxYauto;
  final VoidCallback onPersist;

  CustomChartWidget({
    Key? key,
    required this.tag,
    required this.xAxisLabel,
    required this.yAxisLabel,
    this.constraint,
    this.allowCreateDelete = true,
    this.minX,
    this.maxX,
    this.minY,
    this.maxY,
    required this.onPersist,
  }) : minXauto = (minX == null), maxXauto = (maxX == null), minYauto = (minY == null), maxYauto = (maxY == null),
   super(key: key);

  @override
  _CustomChartWidgetState createState() => _CustomChartWidgetState();
}

class _CustomChartWidgetState extends State<CustomChartWidget> {
  late ChartController chartController;
  int draggedIndex = -1;
  Offset? dragStart;
  Offset? currentDragPoint;

  // Update data to pixel conversion method
  Offset dataToPixel(Offset data, Size size) {
    double minX = widget.minX!;
    double maxX = widget.maxX!;
    double minY = widget.minY!;
    double maxY = widget.maxY!;
    
    double x = (data.dx - minX) / (maxX - minX) * size.width;
    double y = size.height - ((data.dy - minY) / (maxY - minY) * size.height);
    return Offset(x, y);
  }

  // Convert pixel coordinates back to data coordinates
  Offset pixelToData(Offset pixel, Size size) {
    double minX = widget.minX!;
    double maxX = widget.maxX!;
    double minY = widget.minY!;
    double maxY = widget.maxY!;
    
    double x = minX + (pixel.dx / size.width) * (maxX - minX);
    double y = minY + ((size.height - pixel.dy) / size.height) * (maxY - minY);
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
    final axisColor = theme.textTheme.bodySmall?.color ?? Colors.black;
    
    widget.minX??= chartController.points.map((p) => p.dx).reduce(min);
    widget.maxX??= chartController.points.map((p) => p.dx).reduce(max); 
    widget.minY??= chartController.points.map((p) => p.dy).reduce(min);
    widget.maxY??= chartController.points.map((p) => p.dy).reduce(max);
    
    return GestureDetector(
      onLongPressStart: (details) {
        if (!widget.allowCreateDelete) return;
        RenderBox box = context.findRenderObject() as RenderBox;
        Offset localPos = box.globalToLocal(details.globalPosition);
        
        for (int i = 0; i < chartController.points.length; i++) {
          Offset pixel = dataToPixel(chartController.points[i], box.size);
          if ((pixel - localPos).distance < 40) {
            chartController.removePoint(i);
            widget.onPersist();
            break;
          }
        }
      },
      onPanDown: (details) {
        if (!widget.allowCreateDelete) return;
        RenderBox box = context.findRenderObject() as RenderBox;
        Offset localPos = box.globalToLocal(details.globalPosition);
        
        bool found = false;
        for (int i = 0; i < chartController.points.length; i++) {
          Offset pixel = dataToPixel(chartController.points[i], box.size);
          if ((pixel - localPos).distance < 40) {
            found = true;
            break;
          }
        }
        if (!found) {
          Offset newPoint = pixelToData(localPos, box.size);
          chartController.addPoint(newPoint);
          widget.onPersist();
        }
      },
      onPanStart: (details) {
        RenderBox box = context.findRenderObject() as RenderBox;
        Offset localPos = box.globalToLocal(details.globalPosition);
        
        for (int i = 0; i < chartController.points.length; i++) {
          Offset pixel = dataToPixel(chartController.points[i], box.size);
          if ((pixel - localPos).distance < 40) {
            draggedIndex = i;
            dragStart = localPos;
            chartController.undoStack.add(List.from(chartController.points));
            break;
          }
        }
      },
      onPanUpdate: (details) {
        if (draggedIndex != -1 && dragStart != null) {
          RenderBox box = context.findRenderObject() as RenderBox;
          Offset localPos = box.globalToLocal(details.globalPosition);
          double dx = localPos.dx - dragStart!.dx;
          double dy = localPos.dy - dragStart!.dy;
          
          Offset oldPixel = dataToPixel(chartController.points[draggedIndex], box.size);
          Offset newPixel = Offset(oldPixel.dx + dx, oldPixel.dy + dy);
          Offset newPoint = pixelToData(newPixel, box.size);
          
          if (widget.constraint != null) {
            newPoint = widget.constraint!(newPoint, chartController.points.toList(), draggedIndex);
          }
          
          chartController.updatePoint(draggedIndex, newPoint);

          if(widget.minXauto) widget.minX = chartController.points.map((p) => p.dx).reduce(min);
          if(widget.maxXauto) widget.maxX = chartController.points.map((p) => p.dx).reduce(max);
          if(widget.minYauto) widget.minY = chartController.points.map((p) => p.dy).reduce(min);
          if(widget.maxYauto) widget.maxY = chartController.points.map((p) => p.dy).reduce(max);

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
        // Persist changes when dragging ends.
        widget.onPersist();
      },
      child: Container(
        height: 250,
        width: MediaQuery.of(context).size.width * 0.8,
        child: Obx(() {
          return CustomPaint(
            painter: LineChartPainter(
              points: chartController.points.toList(),
              xAxisLabel: widget.xAxisLabel,
              yAxisLabel: widget.yAxisLabel,
              axisColor: axisColor,
              chartColor: theme.colorScheme.primary,
              draggedPoint: currentDragPoint,
              minX: widget.minX!,
              maxX: widget.maxX!,
              minY: widget.minY!,
              maxY: widget.maxY!,
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
  final Color axisColor;
  final Color chartColor;
  final Offset? draggedPoint;
  double minX;
  double maxX;
  double minY;
  double maxY;
  
  LineChartPainter({
    required this.points,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.axisColor,
    required this.chartColor,
    this.draggedPoint,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    
    double rangeX = maxX - minX;
    if (rangeX == 0) rangeX = 1;
    double rangeY = maxY - minY;
    if (rangeY == 0) rangeY = 1;

    List<Offset> mappedPoints = points.map((p) {
      double x = (p.dx - minX) / rangeX * size.width;
      double y = size.height - ((p.dy - minY) / rangeY * size.height);
      return Offset(x, y);
    }).toList();

    // Draw grid
    const int tickCount = 4;
    Paint gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 1;
    for (int i = 0; i <= tickCount; i++) {
      double x = i * size.width / tickCount;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (int i = 0; i <= tickCount; i++) {
      double y = size.height - i * size.height / tickCount;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  
    // Draw axes
    Paint axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), axisPaint);
    canvas.drawLine(Offset(0, size.height), Offset(0, 0), axisPaint);

     // Draw ticks and labels.
     final textStyle = TextStyle(color: axisColor, fontSize: 10);
     for (int i = 0; i <= tickCount; i++) {
      double tickX = i * size.width / tickCount;
      double tickValue = minX + (rangeX) * i / tickCount;
      canvas.drawLine(Offset(tickX, size.height), Offset(tickX, size.height - 5), axisPaint);
       TextPainter tp = TextPainter(
        text: TextSpan(text: tickValue.toStringAsFixed(0), style: textStyle),
         textDirection: TextDirection.ltr,
       );
       tp.layout();
       tp.paint(canvas, Offset(tickX - tp.width / 2, size.height + 2));
     }
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
    final labelStyle = TextStyle(color: axisColor, fontSize: 12);
    TextPainter xLabelPainter = TextPainter(
      text: TextSpan(text: xAxisLabel, style: labelStyle),
      textDirection: TextDirection.ltr,
    );
    xLabelPainter.layout();
    xLabelPainter.paint(canvas, Offset(size.width / 2 - xLabelPainter.width / 2, size.height + 15));
    canvas.save();
    TextPainter yLabelPainter = TextPainter(
      text: TextSpan(text: yAxisLabel, style: labelStyle),
      textDirection: TextDirection.ltr,
    );
    yLabelPainter.layout();
    canvas.translate(-40, size.height / 2 + yLabelPainter.width / 2);
    canvas.rotate(-3.14159 / 2);
    yLabelPainter.paint(canvas, Offset(0, 0));
    canvas.restore();
  
    // Draw line
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
  
    // Draw data points
    Paint circlePaint = Paint()
      ..color = chartColor
      ..style = PaintingStyle.fill;
    for (Offset p in mappedPoints) {
      canvas.drawCircle(p, 6, circlePaint);
    }
  
    // Optionally draw labels for the currently dragged point.
    if (draggedPoint != null) {
      double dragPixelX = (draggedPoint!.dx - minX) / rangeX * size.width;
      double dragPixelY = size.height - ((draggedPoint!.dy - minY) / rangeY * size.height);
      String xDragText = draggedPoint!.dx.toStringAsFixed(1);
      TextPainter xDragPainter = TextPainter(
        text: TextSpan(text: xDragText, style: TextStyle(color: chartColor, fontSize: 12)),
        textDirection: TextDirection.ltr,
      );
      xDragPainter.layout();
      xDragPainter.paint(
          canvas, Offset(dragPixelX - xDragPainter.width / 2, size.height - 20));

      // Y-axis coordinate label (as percentage).
      String yDragText = (draggedPoint!.dy * 100).toStringAsFixed(0) + "%";
      TextPainter yDragPainter = TextPainter(
        text: TextSpan(text: yDragText, style: TextStyle(color: chartColor, fontSize: 12)),
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
