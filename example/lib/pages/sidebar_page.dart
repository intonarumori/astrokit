import 'package:astrokit/astrokit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SidebarPage extends StatefulWidget {
  const SidebarPage({super.key, required this.items, required this.onItemSelected, required this.selectedIndex});

  final List<String> items;
  final int selectedIndex;
  final void Function(int index) onItemSelected;

  @override
  State<SidebarPage> createState() => _SidebarPageState();
}

class _SidebarPageState extends State<SidebarPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              itemCount: widget.items.length,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              itemBuilder: (context, index) {
                final selected = index == widget.selectedIndex;
                return AstroListTile(
                  selectedColor: Theme.of(context).colorScheme.onSurface,
                  titleTextStyle: Theme.of(context).textTheme.bodySmall,
                  title: Text(widget.items[index]),
                  selected: selected,
                  onTap: () {
                    widget.onItemSelected(index);
                  },
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 2),
            ),
          ),
        ],
      ),
    );
  }
}
