import 'package:flutter/material.dart';
import 'base_meal_page.dart';

class BreakfastPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseMealPage(
      pageTitle: "Breakfast",
      addButtonText: "Add to breakfast",
      mealType: "breakfast",
    );
  }
}
