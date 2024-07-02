import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

import '../../client/logger.dart';


class ConversationsSend extends StatefulWidget {
  const ConversationsSend({super.key});

  @override
  State<ConversationsSend> createState() => _ConversationsSendState();
}

class _ConversationsSendState extends State<ConversationsSend> {
  final QuillController _controller = QuillController.basic();

  String parseText(Delta delta) {
    String text = "";

    List<Operation> operations = delta.operations;
    for (int i = 0; i < delta.length; i++) {
      final Operation operation = operations[i];
      String current = operation.value;

      if (operation.attributes == null){
        current = operation.value;
      } else {

        for (MapEntry attribute in operation.attributes!.entries) {
          switch (attribute.key) {
            case "bold":
              current = "**$current**";
              break;

            case "underline":
              current = "__${current}__";
              break;

            case "italic":
              current = "~~$current~~";
              break;

            case "strike":
              current = "--$current--";
              break;

            case "code":
              current = "`$current`";
              break;

            case "script":
              if (attribute.value == "super") {
                current = "^($current)";
              } else if (attribute.value == "sub") {
                current = "_($current)";
              }
              break;

            default:
              break;
          }
        }
      }

      if (i != operations.length - 1) {
        final Map<String, dynamic>? nextAttributes = operations[i + 1].attributes;

        if (nextAttributes != null && nextAttributes.containsKey("list")) {
          if (current.contains("\u000A")) {
            final String temp = current.toString();
            current = temp.substring(0, temp.indexOf("\u000A") + 1);
            current += "- ${temp.substring(temp.indexOf("\u000A") + 1)}";
          } else {
            current = "- $current";
          }
        }
      }

      text += current;
    }

    return text.substring(0, text.length-1);
  }

  @override
  Widget build(BuildContext context) {
    late bool other;
    if (kDebugMode) {
      other = false;
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context, null);
          },
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          if (kDebugMode) ...[
            IconButton(
              onPressed: () {
                other = !other;
              },
              icon: const Icon(Icons.transfer_within_a_station),
            ),
            IconButton(
              onPressed: () {
                Navigator.pop(context, [parseText(_controller.document.toDelta()), false, other]);
              },
              icon: const Icon(Icons.cancel_schedule_send),
            ),
            IconButton(
              onPressed: () {
                Navigator.pop(context, [parseText(_controller.document.toDelta()), true, other]);
              },
              icon: const Icon(Icons.schedule_send),
            ),
            IconButton(
              onPressed: () { logger.d(parseText(_controller.document.toDelta())); },
              icon: const Icon(Icons.print),
            ),
          ],
          IconButton(
            onPressed: () { _controller.clear(); },
            icon: const Icon(Icons.delete_forever),
          ),
          IconButton(
            onPressed: () {
              Navigator.pop(context, parseText(_controller.document.toDelta()));
            },
            icon: const Icon(Icons.send),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: QuillEditor.basic(
                configurations: QuillEditorConfigurations(
                  controller: _controller,
                  placeholder: "Schreibe hier deine Nachricht...",
                  padding: const EdgeInsets.symmetric(horizontal: 16.0)
                )
            ),
          ),
          QuillToolbar(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Wrap(
                  children: [
                    QuillToolbarHistoryButton(
                      isUndo: true,
                      controller: _controller,
                    ),
                    QuillToolbarHistoryButton(
                      isUndo: false,
                      controller: _controller,
                    ),
                    QuillToolbarClearFormatButton(
                      controller: _controller,
                    ),
                    QuillToolbarToggleStyleButton(
                      options: const QuillToolbarToggleStyleButtonOptions(),
                      controller: _controller,
                      attribute: Attribute.bold,
                    ),
                    QuillToolbarToggleStyleButton(
                      options: const QuillToolbarToggleStyleButtonOptions(),
                      controller: _controller,
                      attribute: Attribute.italic,
                    ),
                    QuillToolbarToggleStyleButton(
                      controller: _controller,
                      attribute: Attribute.underline,
                    ),
                    QuillToolbarToggleStyleButton(
                        controller: _controller,
                        attribute: Attribute.strikeThrough
                    ),
                    QuillToolbarToggleStyleButton(
                      controller: _controller,
                      attribute: Attribute.inlineCode,
                    ),
                    QuillToolbarToggleStyleButton(
                      controller: _controller,
                      attribute: Attribute.ul,
                    ),
                    QuillToolbarToggleStyleButton(
                        controller: _controller,
                        attribute: Attribute.superscript
                    ),
                    QuillToolbarToggleStyleButton(
                        controller: _controller,
                        attribute: Attribute.subscript
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      )
    );
  }
}
