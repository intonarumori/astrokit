import 'package:astrokit/astrokit.dart';
import 'package:astrokit/components/appbar/astro_appbar.dart';
import 'package:astrokit/components/split_navigation/split_navigation_widget.dart';
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
                  child: Column(children: [Text(title, style: Theme.of(context).textTheme.headlineMedium)]),
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
