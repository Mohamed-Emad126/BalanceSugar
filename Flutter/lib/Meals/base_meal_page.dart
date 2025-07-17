import 'package:flutter/material.dart';
import '../services/diet_service.dart';
import 'MainMeal.dart'; // Import MealTrackerScreen from MainMeal.dart
import 'details.dart'; // Import the FoodDetailsWidget
import '../common/bottom_nav.dart';

// Abstract base widget for meal pages
class BaseMealPage extends StatefulWidget {
  final String pageTitle;
  final String addButtonText;
  final String mealType;
  // Add any other required parameters here

  const BaseMealPage({
    Key? key,
    required this.pageTitle,
    required this.addButtonText,
    required this.mealType,
    // Add any other required parameters here
  }) : super(key: key);

  @override
  _BaseMealPageState createState() => _BaseMealPageState();
}

// Replace the abstract state class with a concrete one
class _BaseMealPageState extends State<BaseMealPage>
    with TickerProviderStateMixin {
  final DietService _dietService = DietService();
  List<Map<String, dynamic>> foodItems = [];
  int selectedItems = 0;
  bool isLoading = true;
  String? error;
  Map<int, Map<String, dynamic>> nutritionInfoByIndex = {};
  TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    fetchFoodItems();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> fetchFoodItems() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final items = await _dietService.getFoodItems();

      final processedItems = items
          .map((item) => {
                ...item,
                'expanded': false,
                'portionSize': '',
              })
          .toList();

      setState(() {
        foodItems = processedItems;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load food items: $e';
        isLoading = false;
      });
    }
  }

  void toggleExpand(int index) {
    if (index >= 0 && index < foodItems.length) {
      setState(() {
        final item = foodItems[index];
        item['expanded'] = !(item['expanded'] ?? false);
      });
    }
  }

  void addSelectedItem(int index) {
    final foodItem = foodItems[index];
    final nutrition = nutritionInfoByIndex[index];
    if (nutrition == null || nutrition['portionSize'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please enter a valid portion size and wait for nutrition info.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    addMeal(
      foodItem['name'],
      nutrition['portionSize'].toString(),
      nutrition['calories']?.toString() ?? '',
      nutrition['fat']?.toString() ?? '',
      nutrition['carbohydrates']?.toString() ?? '',
      nutrition['protein']?.toString() ?? '',
      nutrition['sugars']?.toString() ?? '',
    ).then((_) {
      setState(() {
        selectedItems++;
      });
    });
  }

  Future<void> addMeal(
    String foodName,
    String portionSize,
    String calories,
    String fat,
    String carbohydrates,
    String protein,
    String sugars,
  ) async {
    try {
      final meal = Meal(
        id: 0,
        mealType: widget.mealType, // Use mealType from the widget
        name: foodName,
        portionSize: portionSize,
        calories: calories,
        fat: fat,
        carbohydrates: carbohydrates,
        protein: protein,
        sugars: sugars,
      );
      await _dietService.addMeal(meal);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meal added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add meal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget buildPageContent(BuildContext context) {
    final filteredItems = searchQuery.isEmpty
        ? foodItems
        : foodItems
            .where((item) => item['name']
                .toString()
                .toLowerCase()
                .contains(searchQuery.toLowerCase()))
            .toList();
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(
                        child: Text(
                          error!,
                          style: TextStyle(fontSize: 18, color: Colors.red),
                        ),
                      )
                    : foodItems.isEmpty
                        ? const Center(
                            child: Text(
                              "No food items available",
                              style: TextStyle(
                                  fontSize: 18, color: Colors.black54),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredItems.length,
                            itemBuilder: (context, index) {
                              return Column(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 15,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 5,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 80,
                                              height: 40,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                              ),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: Colors.grey.shade300,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                  12,
                                                ),
                                              ),
                                              child: TextField(
                                                keyboardType:
                                                    TextInputType.number,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                ),
                                                decoration:
                                                    const InputDecoration(
                                                  hintText: "Grams",
                                                  hintStyle: TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 14,
                                                  ),
                                                  border: InputBorder.none,
                                                ),
                                                onChanged: (value) {
                                                  setState(() {
                                                    filteredItems[index]
                                                        ['portionSize'] = value;
                                                  });
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            IconButton(
                                              icon: Icon(
                                                filteredItems[index]['expanded']
                                                    ? Icons.keyboard_arrow_up
                                                    : Icons.keyboard_arrow_down,
                                                color: Colors.black,
                                                size: 20,
                                              ),
                                              onPressed: () => toggleExpand(
                                                index,
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                filteredItems[index]['name'],
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.add_circle,
                                                color: Color(0xFF034985),
                                                size: 30,
                                              ),
                                              onPressed: () =>
                                                  addSelectedItem(index),
                                            ),
                                          ],
                                        ),
                                        AnimatedSize(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          child: filteredItems[index]
                                                  ['expanded']
                                              ? FoodDetailsWidget(
                                                  foodName: filteredItems[index]
                                                      ['name'],
                                                  baseCalories:
                                                      filteredItems[index]
                                                              ['calories']
                                                          .toString(),
                                                  baseFat: filteredItems[index]
                                                          ['fat']
                                                      .toString(),
                                                  baseCarbs:
                                                      filteredItems[index]
                                                              ['carbohydrates']
                                                          .toString(),
                                                  baseProtein:
                                                      filteredItems[index]
                                                              ['protein']
                                                          .toString(),
                                                  baseSugar:
                                                      filteredItems[index]
                                                              ['sugars']
                                                          .toString(),
                                                  currentPortionSize:
                                                      (filteredItems[index][
                                                                  'portionSize']
                                                              as String?) ??
                                                          '',
                                                  onNutritionReady:
                                                      (nutrition) {
                                                    setState(() {
                                                      nutritionInfoByIndex[
                                                          index] = nutrition;
                                                    });
                                                  },
                                                )
                                              : const SizedBox.shrink(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Color(0xFF034985), Color(0xFF0768AD)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: ElevatedButton(
              onPressed: () {
                // Navigate to MealTrackerScreen after adding meal
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const MealTrackerScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.addButtonText, // Use addButtonText from the widget
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$selectedItems',
                        style: const TextStyle(
                          color: Color(0xFF034985),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavScaffold(
      currentIndex: 1,
      backgroundColor: const Color(0xFFE6EEF5),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.blue[900]),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(width: 10),
                Text(
                  widget.pageTitle, // Use pageTitle from the widget
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF4F8),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.grey, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        hintText: "What do you want to eat?",
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                        border: InputBorder.none,
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        toolbarHeight: 160,
      ),
      body: buildPageContent(context),
    );
  }
}
