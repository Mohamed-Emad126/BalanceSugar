import 'package:flutter/material.dart';
import 'base_meal_page.dart';

class DinnerPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseMealPage(
      pageTitle: "Dinner",
      addButtonText: "Add to dinner",
      mealType: "dinner",
    );
  }
}
