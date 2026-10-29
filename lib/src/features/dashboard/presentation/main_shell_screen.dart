import 'package:flutter/material.dart';
import '../../../common_widgets/app_navbar.dart';
import '../../../constants/app_colors.dart';
import '../../learn/presentation/activity_screen.dart';
import '../../learn/presentation/learn_screen.dart';
import '../../learn/presentation/modules_screen.dart';
import '../../learn/presentation/rooms_screen.dart';
import '../../profile/presentation/profile_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return Scaffold(
      backgroundColor: backgroundColor,
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: const <Widget>[
          // TAB 0: Dashboard (/learn parity)
          LearnScreen(),

          // TAB 1: Modules (/learn/modules parity)
          ModulesScreen(),

          // TAB 2: Hubs (/learn/hubs parity)
          RoomsScreen(),

          // TAB 3: My Activity (/learn/activity parity)
          ActivityScreen(),

          // TAB 4: Profile & Settings (/profile parity)
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: AppNavbar(
        selectedIndex: _currentIndex,
        onItemSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
