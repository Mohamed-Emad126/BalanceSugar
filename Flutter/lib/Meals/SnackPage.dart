import 'package:flutter/material.dart';
import 'base_meal_page.dart';

class SnackPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseMealPage(
      pageTitle: "Snack",
      addButtonText: "Add to snack",
      mealType: "snack",
    );
  }
}
