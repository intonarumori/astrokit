import 'package:astrokit/astrokit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SplitPage extends StatefulWidget {
  const SplitPage({super.key});

  @override
  State<SplitPage> createState() => _SplitPageState();
}

class _SplitPageState extends State<SplitPage> {
  int _selectedIndex = 0;

  static const _items = ['Home', 'Search', 'Library', 'Settings'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SplitNavigationWidget(
        sidebarWidth: 280,
        sidebar: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AstroAppBar(
            leading: const SizedBox(),
            actions: [
              Builder(
                builder: (context) =>
                    IconButton(icon: Icon(CupertinoIcons.sidebar_left), onPressed: () => SplitNavigationWidget.of(context).close()),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView.separated(
                  itemCount: _items.length,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                  itemBuilder: (context, index) {
                    final selected = index == _selectedIndex;
                    return AstroListTile(
                      selectedColor: Theme.of(context).colorScheme.onSurface,
                      titleTextStyle: Theme.of(context).textTheme.bodySmall,
                      title: Text(_items[index]),
                      selected: selected,
                      onTap: () => setState(() => _selectedIndex = index),
                    );
                  },
                  separatorBuilder: (context, index) => const SizedBox(height: 2),
                ),
              ),
            ],
          ),
        ),
        child: Scaffold(
          appBar: AstroAppBar(
            title: Text(_items[_selectedIndex]),
            leadingWidth: 114,
            actionsPadding: const EdgeInsets.only(right: 12),
            leading: Builder(
              builder: (context) {
                final controller = SplitNavigationWidget.of(context);
                return ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) {
                    if (controller.isOpen) return const SizedBox();
                    return Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(icon: Icon(CupertinoIcons.sidebar_left), onPressed: controller.toggle),
                    );
                  },
                );
              },
            ),
          ),
          body: SafeArea(
            child: Container(
              decoration: const BoxDecoration(),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(children: [Text(_items[_selectedIndex], style: Theme.of(context).textTheme.headlineMedium)]),
                    ),
                  ),
                  TextField(decoration: InputDecoration(hintText: 'Enter text')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
