import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  Hive.init(dir.path);
  await Hive.openBox('entries');
  await Hive.openBox('settings');
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final Box settingsBox = Hive.box('settings');

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = settingsBox.get('darkMode', defaultValue: false);
    return MaterialApp(
      theme: isDarkMode ? ThemeData.dark() : ThemeData.light(),
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final Box box = Hive.box('entries');
  final Box settingsBox = Hive.box('settings');

  void addEntry() {
    String name = 'Chemical Substance ${box.length + 1}';
    box.add(name);
    setState(() {});
  }

  void deleteEntry(int index) {
    box.deleteAt(index);
    setState(() {});
  }

  void renameEntry(int index, String newName) {
    box.putAt(index, newName);
    setState(() {});
  }

  void toggleTheme() {
    bool isDarkMode = settingsBox.get('darkMode', defaultValue: false);
    settingsBox.put('darkMode', !isDarkMode);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Entries'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Settings'),
                content: SwitchListTile(
                  title: Text('Dark Mode'),
                  value: settingsBox.get('darkMode', defaultValue: false),
                  onChanged: (value) {
                    toggleTheme();
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: box.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(box.getAt(index)),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetailScreen(entry: box.getAt(index)),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () {
                    TextEditingController controller = TextEditingController(text: box.getAt(index));
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Rename Entry'),
                        content: TextField(
                          controller: controller,
                          decoration: InputDecoration(hintText: 'Enter new name'),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              renameEntry(index, controller.text);
                              Navigator.pop(context);
                            },
                            child: Text('Save'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => deleteEntry(index),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: addEntry,
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
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => GraphScreen(title: 'Slider')),
            ),
            child: Text('Slider'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => GraphScreen(title: 'Kinematics')),
            ),
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
  List<FlSpot> points = [FlSpot(1, 1), FlSpot(2, 2), FlSpot(3, 3)];

  void _updatePoint(int index, FlSpot newSpot) {
    setState(() {
      points[index] = newSpot;
    });
  }

  @override
  Widget build(BuildContext context) {
    int draggedindex=-1;
    Offset? dragstart;
    double minX = points.reduce((current, next) => next.x < current.x ? next : current).x;
    double maxX = points.reduce((current, next) => next.x > current.x ? next : current).x;
    double minY = points.reduce((current, next) => next.y < current.y ? next : current).y;
    double maxY = points.reduce((current, next) => next.y > current.y ? next : current).y;

    LineChartData linechartdata = LineChartData(
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
          spots: points,
          isCurved: true,
          barWidth: 4,
          color: Colors.blue,
          belowBarData: BarAreaData(show: false),
        ),
      ],
      lineTouchData: LineTouchData(
        touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
          // ScaffoldMessenger.of(context).showSnackBar(
          //     SnackBar(content: Text('Touched at x: ${event.localPosition?.dx}, y: ${event.localPosition?.dy}')),
          // );
          if (event is FlPanEndEvent) {
            draggedindex=-1;
          }
          if (response != null && response.lineBarSpots != null && draggedindex<0) {
            final spot = response.lineBarSpots!.first;
            draggedindex = spot.spotIndex;
            dragstart=event.localPosition;
            print('selected: ${spot.x},${spot.y} (${dragstart?.dx},${dragstart?.dy})');
          }
        },
        handleBuiltInTouches: true,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: GestureDetector(
        onPanUpdate: (details) {
          // double minX = linechartdata.minX;
          // double maxX = linechartdata.maxX;
          // double minY = linechartdata.minY;
          // double maxY = linechartdata.maxY;
          // FlChartPainter painter = LineChartPainter(lineChartData, showingTooltipSpots: []);
          // FlSpot bottomLeft = FlSpot(lineChartData.minX!, lineChartData.minY!);
          // FlSpot topRight = FlSpot(lineChartData.maxX!, lineChartData.maxY!);

          // Offset bottomLeftPx = painter.getPixelForValue(bottomLeft);
          // Offset topRightPx = painter.getPixelForValue(topRight);

          RenderBox box = context.findRenderObject() as RenderBox;
          Offset localPosition = box.globalToLocal(details.globalPosition);
          if (draggedindex>=0){
            print('* ${(linechartdata.maxX-linechartdata.minX)/box.size.width},${(linechartdata.maxY-linechartdata.minY)/box.size.height} (${linechartdata.maxX} ${box.size.height})');
            double x=points[draggedindex].x+(localPosition.dx-dragstart!.dx)*(linechartdata.maxX-linechartdata.minX)/box.size.width;
            double y=points[draggedindex].y+(localPosition.dy-dragstart!.dy)*(linechartdata.maxY-linechartdata.minY)/box.size.height;
            
            print('${points[draggedindex].x},${points[draggedindex].y} -> $x,$y');
            print('drag: ${localPosition?.dx},${localPosition?.dy} - ${dragstart!.dx},${dragstart!.dy} = ${localPosition.dx-dragstart!.dx},${localPosition.dy-dragstart!.dy}');

            _updatePoint(draggedindex, FlSpot(x,y));
            dragstart=localPosition;
          }

          // double x = (localPosition.dx / box.size.width) * 10;
          // double y = (1 - localPosition.dy / box.size.height) * 10;
          
          // for (int i = 0; i < points.length; i++) {
          //   if ((points[i].x - x).abs() < 0.5 && (points[i].y - y).abs() < 0.5) {
          //     _updatePoint(i, FlSpot(x, y));
          //     break;
          //   }
          // }
        },
        child: Center(
          child: Container(
            height: 300,
            child: LineChart(
              linechartdata,
            ),
          ),
        ),
      ),
    );
  }
}
