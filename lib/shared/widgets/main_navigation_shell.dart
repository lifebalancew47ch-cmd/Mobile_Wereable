import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainNavigationShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainNavigationShell({
    super.key,
    required this.navigationShell,
  });

  void _onTap(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    IconData icon,
    IconData selectedIcon,
    String label,
  ) {
    final isSelected = navigationShell.currentIndex == index;
    const activeColor = Color(0xFF3E6F58);

    return InkWell(
      onTap: () => _onTap(context, index),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected ? activeColor : Colors.grey.shade600,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? activeColor : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () => navigationShell.goBranch(
          2,
          initialLocation: navigationShell.currentIndex == 2,
        ),
        backgroundColor: const Color(0xFF3E6F58),
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      bottomNavigationBar: BottomAppBar(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: Colors.white,
        elevation: 8,
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(context, 0, Icons.grid_view_outlined, Icons.grid_view, 'Resumen'),
            _buildNavItem(context, 1, Icons.bar_chart_outlined, Icons.bar_chart, 'Análisis'),
            const SizedBox(width: 48), // Espacio para el FAB central con muesca
            _buildNavItem(context, 3, Icons.help_outline, Icons.help, 'Soporte'),
            _buildNavItem(context, 4, Icons.person_outline, Icons.person, 'Perfil'),
          ],
        ),
      ),
    );
  }
}
