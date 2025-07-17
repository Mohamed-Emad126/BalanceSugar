import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/diet_service.dart';

class FoodDetailsWidget extends StatefulWidget {
  final String foodName;
  final String currentPortionSize; // New parameter for the current portion size
  final String baseCalories; // Changed to String for decimal handling
  final String baseFat;
  final String baseCarbs;
  final String baseProtein;
  final String baseSugar;
  final void Function(Map<String, dynamic> nutrition)? onNutritionReady;

  FoodDetailsWidget({
    Key? key,
    required this.foodName,
    required this.currentPortionSize,
    required this.baseCalories,
    required this.baseFat,
    required this.baseCarbs,
    required this.baseProtein,
    required this.baseSugar,
    this.onNutritionReady,
  }) : super(key: key);

  @override
  _FoodDetailsWidgetState createState() => _FoodDetailsWidgetState();
}

class _FoodDetailsWidgetState extends State<FoodDetailsWidget> {
  final FocusNode _portionFocusNode =
      FocusNode(); // Keep FocusNode if needed for other interactions, though keyboard listener will be removed.

  // Nutrition values from API
  String? calories, fat, carbs, protein, sugar;
  bool _isLoading = false;
  String? _error;

  final _dietService = DietService();

  @override
  void initState() {
    super.initState();
    // Initial calculation based on the provided currentPortionSize
    _calculateNutrition(widget.currentPortionSize);
  }

  @override
  void dispose() {
    _portionFocusNode.dispose(); // Dispose even if keyboard listener is gone
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FoodDetailsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger calculation if the portion size changes from the parent widget
    if (widget.currentPortionSize != oldWidget.currentPortionSize) {
      _calculateNutrition(widget.currentPortionSize);
    }
  }

  void _calculateNutrition(String value) async {
    final newSize = double.tryParse(value);
    if (newSize != null && newSize > 0) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      try {
        final nutrition = await _dietService.getFoodNutritionInfo(
          foodName: widget.foodName,
          portionSize: newSize,
        );
        setState(() {
          calories = nutrition['calories']?.toString();
          fat = nutrition['fat']?.toString();
          carbs = nutrition['carbohydrates']?.toString();
          protein = nutrition['protein']?.toString();
          sugar = nutrition['sugars']?.toString();
          _isLoading = false;
        });
        if (widget.onNutritionReady != null) {
          widget.onNutritionReady!({
            'portionSize': newSize,
            'calories': calories, // Pass calculated values
            'fat': fat, // Pass calculated values
            'carbohydrates': carbs, // Pass calculated values
            'protein': protein, // Pass calculated values
            'sugars': sugar, // Pass calculated values
          });
        }
      } catch (e) {
        setState(() {
          _error = 'Failed to fetch nutrition info';
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        calories = fat = carbs = protein = sugar = null;
        _error = 'Please enter a valid portion size';
        if (widget.onNutritionReady != null) {
          widget.onNutritionReady!(
              {}); // Indicate no valid nutrition by sending an empty map
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8),
            if (_isLoading) Center(child: CircularProgressIndicator()),
            if (_error != null)
              Center(child: Text(_error!, style: TextStyle(color: Colors.red))),
            if (!_isLoading &&
                _error == null &&
                double.tryParse(widget.currentPortionSize) != null &&
                double.tryParse(widget.currentPortionSize)! > 0)
              Column(
                children: [
                  // Combined container for sugar, kcal, and portion size
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Color(0xFFECF8F9), // very light blue background
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Sugar
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.circle,
                                      size: 14, color: Colors.amber),
                                  SizedBox(width: 4),
                                  Text(
                                    sugar != null && sugar!.isNotEmpty
                                        ? '${sugar}g'
                                        : 'N/A',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 2),
                              Text('Sugar',
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.black54)),
                            ],
                          ),
                        ),
                        // kcal
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                calories != null ? '${calories}' : 'N/A',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text('kcal',
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.black54)),
                            ],
                          ),
                        ),
                        // Portion size
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.currentPortionSize.isNotEmpty
                                    ? '${double.tryParse(widget.currentPortionSize)?.toStringAsFixed(0) ?? 'N/A'}g'
                                    : 'N/A',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87),
                              ),
                              SizedBox(height: 2),
                              Text('Portion',
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.black54)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                Color(0xFFFFFBEA), // very light yellow for Fat
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.circle,
                                      size: 14, color: Colors.blue[800]),
                                  SizedBox(width: 4),
                                  Text(
                                    fat != null && fat!.isNotEmpty
                                        ? '${fat}g'
                                        : 'N/A',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              SizedBox(height: 2),
                              Text('Fat',
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.black54)),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                Color(0xFFF6FAFF), // very light blue for Carbs
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.circle,
                                      size: 14, color: Colors.amber),
                                  SizedBox(width: 4),
                                  Text(
                                    carbs != null && carbs!.isNotEmpty
                                        ? '${carbs}g'
                                        : 'N/A',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              SizedBox(height: 2),
                              Text('Carbs',
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.black54)),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Color(
                                0xFFFDF6F7), // very light pink/red for Protein
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.circle,
                                      size: 14, color: Colors.cyan),
                                  SizedBox(width: 4),
                                  Text(
                                    protein != null && protein!.isNotEmpty
                                        ? '${protein}g'
                                        : 'N/A',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              SizedBox(height: 2),
                              Text('Protein',
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.black54)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
