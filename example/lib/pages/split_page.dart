import 'package:astrokit/astrokit.dart';
import 'package:example/pages/content_page.dart';
import 'package:example/pages/sidebar_page.dart';
import 'package:flutter/material.dart';

class SplitPage extends StatefulWidget {
  const SplitPage({super.key});

  @override
  State<SplitPage> createState() => _SplitPageState();
}

class _SplitPageState extends State<SplitPage> {

  final List<String> _items = ['Home', 'Search', 'Library', 'Settings'];
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SplitNavigationWidget(
        sidebarWidth: 280,
        sidebar: SidebarPage(
          items: _items,
          selectedIndex: _selectedIndex,
          onItemSelected: (index) => setState(() => _selectedIndex = index),
        ),
        child: ContentPage(title: _items[_selectedIndex]),
      ),
    );
  }
}
