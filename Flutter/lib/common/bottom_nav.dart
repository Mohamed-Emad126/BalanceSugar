import 'package:flutter/material.dart';
import '../Welcom/newhome.dart';
import '../Meals/MainMeal.dart';
import '../Medications/Firstmed.dart';
import '../Foot/foot_history_page.dart';
import '../Measurements/glucose_input_page.dart';

class CommonBottomNavBar extends StatelessWidget {
  final int currentIndex;
  const CommonBottomNavBar({required this.currentIndex, Key? key})
      : super(key: key);

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex && index != 4) return;
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardPage()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MealTrackerScreen()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => PillReminderScreen()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const FootHistoryPage()),
        );
        break;
      case 4:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const GlucoseInputPage()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color darkBlue = const Color(0xFF034985);
    return BottomNavigationBar(
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: "Home",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.restaurant_menu_rounded),
          label: "Meal",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.medical_services_outlined),
          label: "Medicine",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.healing_outlined),
          label: "Foot",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.track_changes),
          label: "Tracking",
        ),
      ],
      currentIndex: currentIndex,
      selectedItemColor: darkBlue,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      onTap: (index) => _onItemTapped(context, index),
      backgroundColor: Colors.white,
    );
  }
}

class BottomNavScaffold extends StatelessWidget {
  final int currentIndex;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final FloatingActionButton? floatingActionButton;
  final Color? backgroundColor;
  final Widget? endDrawer;

  const BottomNavScaffold({
    Key? key,
    required this.currentIndex,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.endDrawer,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      backgroundColor: backgroundColor,
      endDrawer: endDrawer,
      bottomNavigationBar: CommonBottomNavBar(currentIndex: currentIndex),
    );
  }
}
