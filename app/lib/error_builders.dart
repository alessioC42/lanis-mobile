import 'package:flutter/material.dart';

ValueNotifier<List<String>> logMessages = ValueNotifier(['This is a test message']);

class ErrorDisplay extends StatefulWidget {
  const ErrorDisplay({super.key});

  @override
  State<ErrorDisplay> createState() => _ErrorDisplay();

}

class _ErrorDisplay extends State<ErrorDisplay> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Logs and shit"),
      ),
      body: ValueListenableBuilder(
        valueListenable: logMessages,
        builder: (BuildContext context, List<String> data, Widget? _) => ListView.builder(
          itemCount: data.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(index.toString()),
              subtitle: Text(data[index]),
            ),
          ),
      ),
    );
  }
}

void openAppLogs(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => const ErrorDisplay(),
    ),
  );
}

FloatingActionButton getAPPFAB(context) {
  return FloatingActionButton(
    onPressed: ()=>openAppLogs(context),
    child: const Icon(Icons.bug_report),
    );
}

void addLogMessage(String message) {
  logMessages.value.add(message);
}