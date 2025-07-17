import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:intl/intl.dart';
import '../Foot/Foot.dart';
import '../Measurements/glucose_input_page.dart';
import '../Medications/Firstmed.dart';
import '../Welcom/newhome.dart';
import '../services/diet_service.dart';
import '../chat/chatbot0.dart';
import 'BreakfastPage.dart';
import 'DinnerPage.dart';
import 'LunchPage.dart';
import 'SnackPage.dart';
import 'Meal_history.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';
import '../services/api_config.dart';
import '../Foot/foot_history_page.dart';
import '../common/bottom_nav.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MealTrackerScreen(),
    );
  }
}

class MealTrackerScreen extends StatefulWidget {
  const MealTrackerScreen({super.key});

  @override
  _MealTrackerScreenState createState() => _MealTrackerScreenState();
}

class _MealTrackerScreenState extends State<MealTrackerScreen> {
  Color darkBlue = const Color(0xFF034985);
  Color primaryBlue = const Color(0xFF0F76CE);
  Color yellowAccent = const Color(0xFFFDD00E);
  Color tealAccent = const Color(0xFF13BEB4);
  Color redAccent = const Color(0xFFF6574D);

  final DietService _dietService = DietService();
  int selectedIndex = 1; // Default to Meal Tracker tab
  int availableCalories = 0;
  int caloriesEaten = 0;
  int caloriesGoal = 0;
  int caloriesBurned = 0;
  Map<String, List<Meal>> mealsByType = {
    'breakfast': [],
    'lunch': [],
    'dinner': [],
    'snack': [],
  };
  bool isLoading = true;
  Map<String, bool> mealExpanded = {
    'breakfast': false,
    'lunch': false,
    'dinner': false,
    'snack': false,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Load meals and calorie info
      final loadedMeals = await _dietService.getMeals();
      final calorieInfo = await _dietService.getMealCalorieInfo();

      setState(() {
        mealsByType = loadedMeals;

        // Use calorie info values from API
        caloriesEaten = (calorieInfo['calories_eaten'] as num).toInt();
        caloriesGoal = (calorieInfo['calorie_goal'] as num).toInt();
        availableCalories = (calorieInfo['calories_available'] as num).toInt();
        caloriesBurned = (calorieInfo['calories_burned'] as num).toInt();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  int _calculateTotalCalories() {
    int sum = 0;
    for (var type in mealsByType.keys) {
      sum += mealsByType[type]!
          .fold(0, (prev, meal) => prev + (int.tryParse(meal.calories) ?? 0));
    }
    return sum;
  }

  Map<String, List<Meal>> getMealsByType() {
    return mealsByType;
  }

  double getTotalCalories(String mealType) {
    final mealList = mealsByType[mealType.toLowerCase()] ?? [];
    return mealList.fold(0.0, (sum, meal) {
      final calories = double.tryParse(meal.calories) ?? 0.0;
      return sum + calories;
    });
  }

  Future<bool> hasAnyFootRegion() async {
    try {
      final headers = await AuthService.getHeaders();
      final url = Uri.parse(ApiConfig.latestByRegion);
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.isNotEmpty;
      }
    } catch (_) {}
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavScaffold(
      currentIndex: 1,
      backgroundColor: const Color(0xFFE6EEF5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.blue[900]),
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const DashboardPage()),
            (route) => false,
          ),
        ),
        title: Text(
          DateFormat('          d MMMM, EEEE').format(DateTime.now()),
          style: const TextStyle(
            fontSize: 18,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  ClipPath(
                    clipper: BottomCurveClipper(),
                    child: Container(
                      height: 360,
                      color: Colors.white,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _buildStatItem(
                                Icons.local_fire_department,
                                caloriesBurned.toString(),
                                "Burn",
                                Colors.red,
                              ),
                              Flexible(
                                child: CircularPercentIndicator(
                                  radius: 100.0,
                                  lineWidth: 15.0,
                                  percent: (caloriesEaten / caloriesGoal)
                                      .clamp(0.0, 1.0),
                                  center: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        caloriesEaten.toString(),
                                        style: const TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF034985),
                                        ),
                                      ),
                                      const Text(
                                        "Eaten",
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  progressColor: const Color(0xFF0F76CE),
                                  backgroundColor: Colors.grey.withOpacity(0.2),
                                  circularStrokeCap: CircularStrokeCap.round,
                                ),
                              ),
                              _buildStatItem(
                                Icons.restaurant_menu,
                                availableCalories.toString(),
                                "Available",
                                const Color(0xFFF6574D),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildStatItem(
                            Icons.emoji_events,
                            caloriesGoal.toString(),
                            "Goal",
                            const Color(0xFF034985),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 12.0),
                        child: Text(
                          'Daily meals',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                  ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    children: [
                      _buildMealTypeCard('Breakfast', primaryBlue),
                      _buildMealTypeCard('Lunch', yellowAccent),
                      _buildMealTypeCard('Dinner', tealAccent),
                      _buildMealTypeCard('Snack', redAccent),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _buildStatItem(
      IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildMealTypeCard(String mealType, Color color) {
    final key = mealType.toLowerCase();
    final meals = mealsByType[key] ?? [];
    final totalCalories = getTotalCalories(mealType);
    final isExpanded = mealExpanded[key] ?? false;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 5, spreadRadius: 1),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 60,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15),
                    bottomLeft: Radius.circular(15),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      mealType,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${totalCalories.toStringAsFixed(0)} Kcal',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          mealExpanded[key] = !isExpanded;
                        });
                      },
                      child: Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: GestureDetector(
                  onTap: () async {
                    Widget? page;
                    if (key == 'breakfast') page = BreakfastPage();
                    if (key == 'lunch') page = LunchPage();
                    if (key == 'dinner') page = DinnerPage();
                    if (key == 'snack') page = SnackPage();
                    if (page != null) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => page!),
                      );
                      _loadData();
                    }
                  },
                  child: CircleAvatar(
                    backgroundColor: const Color(0xFF034985),
                    radius: 18,
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (meals.isEmpty)
                    const Text('No items added',
                        style: TextStyle(color: Colors.grey)),
                  if (meals.isNotEmpty)
                    ...meals.map((meal) => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${meal.name} ${meal.portionSize} g',
                                style: const TextStyle(fontSize: 15)),
                            Text(
                                '${double.tryParse(meal.calories)?.toStringAsFixed(0) ?? '0'} Kcal',
                                style: TextStyle(
                                    fontSize: 15, color: Colors.grey[700])),
                          ],
                        )),
                  if (meals.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                      child: Center(
                        child: SizedBox(
                          width: 180,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () {
                              Widget page;
                              switch (key) {
                                case 'breakfast':
                                  page = MealHistoryPage(
                                      mealType: 'Breakfast',
                                      color: primaryBlue);
                                  break;
                                case 'lunch':
                                  page = MealHistoryPage(
                                      mealType: 'Lunch', color: yellowAccent);
                                  break;
                                case 'dinner':
                                  page = MealHistoryPage(
                                      mealType: 'Dinner', color: tealAccent);
                                  break;
                                case 'snack':
                                  page = MealHistoryPage(
                                      mealType: 'Snack', color: redAccent);
                                  break;
                                default:
                                  page = MealHistoryPage(
                                      mealType: 'All', color: darkBlue);
                              }
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => page,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              elevation: 4,
                            ),
                            child: const Text(
                              'View All',
                              style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 80);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 80,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

Widget _buildStatTile(IconData icon, String label, int value, Color color) {
  return Column(
    children: [
      Icon(icon, color: color, size: 35),
      const SizedBox(height: 4),
      Text(
        "$value",
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    ],
  );
}
