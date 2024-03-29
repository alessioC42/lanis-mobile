import 'dart:async';

import 'package:flutter/material.dart';

import 'filterlogic.dart';

class FilterPlan extends StatelessWidget {
  static const double padding = 10.0;
  FilterPlan({super.key}) {
    loadConfiguration();
  }

  final _klassenStufeController = TextEditingController();
  final _klassenController = TextEditingController();
  final _lehrerKuerzelController = TextEditingController();

  void loadConfiguration() async {
    final filterQueries = await getFilter();

    _klassenStufeController.text = filterQueries["klassenStufe"];
    _klassenController.text = filterQueries["klasse"];
    _lehrerKuerzelController.text = filterQueries["lehrerKuerzel"];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Filter anpassen'),
        ),
        body: ListView(
          children: [
            FilterElements(
              klassenStufeController: _klassenStufeController,
              klassenController: _klassenController,
              lehrerKuerzelController: _lehrerKuerzelController,
            ),
            const Padding(
              padding: EdgeInsets.all(padding),
              child: Card(
                child: ListTile(
                  title: Text(
                    "Hinweis",
                    style: TextStyle(fontSize: 22),
                  ),
                  subtitle: Text(
                      "Da manche Schulen ihre Vertretungsplaneinträge nicht vollständig angeben, kann es sein, dass du bestimmte Einträge, die eigentlich für dich bestimmt sind, mit dem Filter nicht findest, weil sie nicht die Klasse oder den Lehrer enthalten. Wende dich an deine Schulleitung/Schul-IT, um dieses Problem zu beheben. "),
                ),
              ),
            ),
          ],
        ));
  }
}

class FilterElements extends StatefulWidget {
  final TextEditingController klassenStufeController;
  final TextEditingController klassenController;
  final TextEditingController lehrerKuerzelController;
  const FilterElements(
      {super.key,
      required this.klassenStufeController,
      required this.klassenController,
      required this.lehrerKuerzelController});

  @override
  State<FilterElements> createState() => _FilterElementsState();
}

class _FilterElementsState extends State<FilterElements> {
  static const double padding = 10.0;

  Timer? _debounceTimer;

  void _onTypingFinished(String text) {
    if (_debounceTimer != null) {
      _debounceTimer!.cancel();
    }

    _debounceTimer = Timer(const Duration(milliseconds: 1500), () async {
      await setFilter(widget.klassenStufeController.text,
          widget.klassenController.text, widget.lehrerKuerzelController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(padding),
          child: TextFormField(
              controller: widget.klassenStufeController,
              onChanged: _onTypingFinished,
              decoration: const InputDecoration(
                  labelText: 'Klassenstufe (z.B. 7; 8; E; Q)')),
        ),
        Padding(
          padding: const EdgeInsets.all(padding),
          child: TextFormField(
              controller: widget.klassenController,
              onChanged: _onTypingFinished,
              decoration: const InputDecoration(
                  labelText: 'Klasse (z.B. a; b; GA; RA; 1/2; 3/4)')),
        ),
        Padding(
          padding: const EdgeInsets.all(padding),
          child: TextFormField(
              controller: widget.lehrerKuerzelController,
              onChanged: _onTypingFinished,
              decoration: const InputDecoration(
                  labelText: 'Lehrerkürzel (z.B. Abc; XYZ; Müller)')),
        ),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text("Mehrere Filter"),
          subtitle: Text(
              "Du kannst mehrere Filter mit einem \";\" trennen. Beispiel: 7; 8; Q"),
        )
      ],
    );
  }
}
