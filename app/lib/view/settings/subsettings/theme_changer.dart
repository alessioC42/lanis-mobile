import 'package:flutter/material.dart';
import 'package:sph_plan/client/storage.dart';
import 'package:sph_plan/themes.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Appearance"),
        ),
        body: const AppearanceElements()
    );
  }
}

class AppearanceElements extends StatefulWidget {
  const AppearanceElements({super.key});

  @override
  State<AppearanceElements> createState() => _AppearanceElementsState();
}

class _AppearanceElementsState extends State<AppearanceElements> {
  String _selectedTheme = "system"; // Default theme

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    _selectedTheme = (await globalStorage.read(key: "theme")) ?? "system";
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RadioListTile(
            title: const Text('Light Mode'),
            value: "light",
            groupValue: _selectedTheme,
            onChanged: (value) {
              setState(() {
                _selectedTheme = value.toString();
                ThemeModeNotifier.setThemeMode(_selectedTheme);
              });
            },
          ),
          RadioListTile(
            title: const Text('Dark Mode'),
            value: "dark",
            groupValue: _selectedTheme,
            onChanged: (value) {
              setState(() {
                _selectedTheme = value.toString();
                ThemeModeNotifier.setThemeMode(_selectedTheme);
              });
            },
          ),
          RadioListTile(
            title: const Text('System Mode'),
            value: "system",
            groupValue: _selectedTheme,
            onChanged: (value) {
              setState(() {
                _selectedTheme = value.toString();
                ThemeModeNotifier.setThemeMode(_selectedTheme);
              });
            },
          ),
        ],
      ),
    );
  }
}