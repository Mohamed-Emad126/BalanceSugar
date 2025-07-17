import 'package:balance_sugar/Welcom/newhome.dart';
import 'package:flutter/material.dart';
import '../services/diet_service.dart';
import 'details.dart';
import '../common/bottom_nav.dart';

// Place these at the top of the file, outside any class
const Color kSeaGreen = Color(0xFF3AC7BF);
const Color kYellow = Color(0xFFFDD00E);
const Color kRed = Color(0xFFF6574D);
const Color kBlue = Color(0xFF0F76CE);
const Color kFatBg = Color(0xFFFFFBEA); // very light yellow
const Color kCarbsBg = Color(0xFFF6FAFF); // very light blue
const Color kProteinBg = Color(0xFFFDF6F7); // very light pink/red

class MealHistoryPage extends StatefulWidget {
  final String mealType;
  final Color color;

  const MealHistoryPage({
    Key? key,
    required this.mealType,
    required this.color,
  }) : super(key: key);

  @override
  State<MealHistoryPage> createState() => _MealHistoryPageState();
}

class _MealHistoryPageState extends State<MealHistoryPage> {
  final DietService _dietService = DietService();
  Map<String, List<Meal>> mealsByType = {
    'breakfast': [],
    'lunch': [],
    'dinner': [],
    'snack': [],
  };
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadMeals();
  }

  Future<void> _loadMeals() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final loadedMeals = await _dietService.getMeals();
      setState(() {
        if (widget.mealType.toLowerCase() == 'all') {
          mealsByType = loadedMeals;
        } else {
          mealsByType = {
            widget.mealType.toLowerCase():
                loadedMeals[widget.mealType.toLowerCase()] ?? [],
          };
        }
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load meals: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _deleteMeal(Meal meal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 8,
        backgroundColor: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title bar with icon
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.red[700],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.delete_forever, color: Colors.white, size: 26),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Delete Meal',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
              child: Text(
                'Are you sure you want to delete this meal?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 18, left: 16, right: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Delete',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      try {
        await _dietService.deleteMeal(meal.id);
        _loadMeals();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to delete meal: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _editMeal(Meal meal) async {
    final controller = TextEditingController(text: meal.portionSize);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 8,
          backgroundColor: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title bar with icon
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                decoration: BoxDecoration(
                  color: Color(0xFF034985), // Deep blue
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit, color: Colors.white, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Edit Portion Size',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Portion Size (g)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 18, left: 16, right: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(context, controller.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF034985),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Save',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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
      },
    );

    if (result != null && result != meal.portionSize && result.isNotEmpty) {
      try {
        setState(() {
          isLoading = true;
        });

        final nutrition = await _dietService.getFoodNutritionInfo(
          foodName: meal.name,
          portionSize: double.parse(result),
        );

        final updatedMeal = Meal(
          id: meal.id,
          mealType: meal.mealType,
          name: meal.name,
          portionSize: result,
          calories: nutrition['calories']?.toString() ?? '0',
          fat: nutrition['fat']?.toString() ?? '0',
          carbohydrates: nutrition['carbohydrates']?.toString() ?? '0',
          protein: nutrition['protein']?.toString() ?? '0',
          sugars: nutrition['sugars']?.toString() ?? '0',
        );

        await _dietService.updateMeal(meal.id, updatedMeal);
        await _loadMeals();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Portion size and nutrition values updated'),
                backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to update meal: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _buildCircularIconButton(
      IconData iconData, Color iconColor, Function onPressed) {
    return Container(
      width: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[200],
      ),
      child: IconButton(
        icon: Icon(iconData, color: iconColor, size: 20),
        onPressed: () => onPressed(),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6EEF5),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.blue[900]),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          '${widget.mealType} History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final type in mealsByType.keys)
                      if (mealsByType[type]!.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.mealType.toLowerCase() == 'all')
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  type[0].toUpperCase() + type.substring(1),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: widget.color,
                                  ),
                                ),
                              ),
                            ...mealsByType[type]!.map((meal) => Card(
                                  color: Colors.white,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                    color:
                                                        Colors.grey.shade300),
                                              ),
                                              child: Text(
                                                '${meal.portionSize} g',
                                                style: const TextStyle(
                                                    fontSize: 16,
                                                    color: Colors.black),
                                              ),
                                            ),
                                            const SizedBox(width: 30),
                                            Expanded(
                                              child: Text(
                                                '${meal.name}',
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                ),
                                              ),
                                            ),
                                            Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _buildCircularIconButton(
                                                  Icons.edit_outlined,
                                                  Colors.black,
                                                  () => _editMeal(meal),
                                                ),
                                                const SizedBox(height: 3),
                                                _buildCircularIconButton(
                                                  Icons.delete_outline,
                                                  Colors.black,
                                                  () => _deleteMeal(meal),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        Card(
                                          color: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(15)),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                SizedBox(height: 8),
                                                // Top row: Sugar, kcal, Portion (like FoodDetailsWidget)
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                      vertical: 12,
                                                      horizontal: 8),
                                                  decoration: BoxDecoration(
                                                    color: Color(
                                                        0xFFECF8F9), // very light blue background
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceEvenly,
                                                    children: [
                                                      // Sugar
                                                      Expanded(
                                                        child: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              children: [
                                                                Icon(
                                                                    Icons
                                                                        .circle,
                                                                    size: 14,
                                                                    color: Colors
                                                                        .amber),
                                                                SizedBox(
                                                                    width: 4),
                                                                Text(
                                                                  '${meal.sugars}g',
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        18,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: Colors
                                                                        .black87,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            SizedBox(height: 2),
                                                            Text('Sugar',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                    color: Colors
                                                                        .black54)),
                                                          ],
                                                        ),
                                                      ),
                                                      // kcal
                                                      Expanded(
                                                        child: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              '${meal.calories}',
                                                              style: TextStyle(
                                                                fontSize: 18,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                            ),
                                                            SizedBox(height: 2),
                                                            Text('kcal',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                    color: Colors
                                                                        .black54)),
                                                          ],
                                                        ),
                                                      ),
                                                      // Portion size
                                                      Expanded(
                                                        child: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              '${meal.portionSize}g',
                                                              style: TextStyle(
                                                                fontSize: 18,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                            ),
                                                            SizedBox(height: 2),
                                                            Text('Portion',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                    color: Colors
                                                                        .black54)),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                SizedBox(height: 16),
                                                SizedBox(
                                                  height: 80,
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Container(
                                                          padding:
                                                              EdgeInsets.all(6),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Color(
                                                                0xFFFFFBEA), // very light yellow for Fat
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                          ),
                                                          child: Column(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Icon(Icons.circle,
                                                                  size: 14,
                                                                  color: Colors
                                                                      .blue),
                                                              SizedBox(
                                                                  height: 2),
                                                              Text(
                                                                '${meal.fat}g',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: Colors
                                                                      .black87,
                                                                ),
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                              SizedBox(
                                                                  height: 1),
                                                              Text('Fat',
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          13,
                                                                      color: Colors
                                                                          .black54)),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(width: 8),
                                                      Expanded(
                                                        child: Container(
                                                          padding:
                                                              EdgeInsets.all(6),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Color(
                                                                0xFFF6FAFF), // very light blue for Carbs
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                          ),
                                                          child: Column(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Icon(Icons.circle,
                                                                  size: 14,
                                                                  color: Colors
                                                                      .amber),
                                                              SizedBox(
                                                                  height: 2),
                                                              Text(
                                                                '${meal.carbohydrates}g',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: Colors
                                                                      .black87,
                                                                ),
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                              SizedBox(
                                                                  height: 1),
                                                              Text('Carbs',
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          13,
                                                                      color: Colors
                                                                          .black54)),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(width: 8),
                                                      Expanded(
                                                        child: Container(
                                                          padding:
                                                              EdgeInsets.all(6),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Color(
                                                                0xFFFDF6F7), // very light pink/red for Protein
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                          ),
                                                          child: Column(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Icon(Icons.circle,
                                                                  size: 14,
                                                                  color: Colors
                                                                      .cyan),
                                                              SizedBox(
                                                                  height: 2),
                                                              Text(
                                                                '${meal.protein}g',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: Colors
                                                                      .black87,
                                                                ),
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                              SizedBox(
                                                                  height: 1),
                                                              Text('Protein',
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          13,
                                                                      color: Colors
                                                                          .black54)),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )),
                          ],
                        ),
                  ],
                ),
      bottomNavigationBar: CommonBottomNavBar(currentIndex: 1),
    );
  }
}
