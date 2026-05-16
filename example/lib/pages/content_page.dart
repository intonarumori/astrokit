import 'package:astrokit/astrokit.dart';
import 'package:astrokit/components/menu/grid_menu.dart';
import 'package:astrokit/components/popup/popup.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ContentPage extends StatelessWidget {
  const ContentPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AstroAppBar(
        title: Text(title),
        leadingWidth: 120,
        clipBehavior: Clip.none,
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
                  child: AstroFloatingButton(icon: Icon(CupertinoIcons.sidebar_left), onPressed: controller.toggle),
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
                  child: Column(
                    children: [
                      Text(title, style: Theme.of(context).textTheme.headlineMedium),
                      DropdownPopup(
                        preferredAlignment: Alignment.bottomCenter,
                        contentBuilder: (context) => GridMenu(
                          columns: 4,
                          itemsBuilder: (context) => [
                            for (var i = 1; i <= 16; i++) GridMenuItem(title: 'Item $i', icon: Icon(CupertinoIcons.star), onTap: () {}),
                          ],
                        ),
                        buttonBuilder: (context, open) => AstroFloatingButton(icon: Icon(CupertinoIcons.add), onPressed: open),
                      ),
                    ],
                  ),
                ),
              ),
              TextField(decoration: InputDecoration(hintText: 'Enter text')),
            ],
          ),
        ),
      ),
    );
  }
}
