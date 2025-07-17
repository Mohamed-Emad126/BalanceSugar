import 'package:flutter/material.dart';
import 'base_meal_page.dart';

class LunchPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseMealPage(
      pageTitle: "Lunch",
      addButtonText: "Add to lunch",
      mealType: "lunch",
    );
  }
}
