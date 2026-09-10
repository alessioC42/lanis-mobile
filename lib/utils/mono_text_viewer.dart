import 'dart:io';

import 'package:flutter/material.dart';

import 'file_operations.dart';

class MonoTextViewer extends StatelessWidget {
  const MonoTextViewer({
    super.key,
    required this.report,
    required this.title,
    required this.fileNameStart,
  });

  final String report;
  final String title;
  final String fileNameStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: 8.0,
          right: 8.0,
          top: 8.0,
          bottom: 100.0,
        ),
        child: SelectableText(
          report,
          style: TextStyle(fontFamily: 'monospace', fontSize: 10),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        label: Text('Export Report File'),
        icon: Icon(Icons.save_alt),
        onPressed: () {
          final fileName =
              '${fileNameStart}_${DateTime.now().toIso8601String()}.txt';
          final file = File('${Directory.systemTemp.path}/$fileName');
          file
              .writeAsString(report)
              .then((_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Report saved to ${file.path}')),
                  );
                }
              })
              .catchError((e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to save report: $e')),
                  );
                }
              });
          showFileModal(
            context,
            DownloadableFile.local(
              filePath: file.path,
              name: fileName,
              size: "",
            ),
          );
        },
      ),
    );
  }
}
