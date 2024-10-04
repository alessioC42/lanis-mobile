import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:sph_plan/view/conversations/chat.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../client/client.dart';
import '../../client/connection_checker.dart';
import '../../shared/types/conversations.dart';
import 'shared.dart';

class ConversationsSend extends StatefulWidget {
  final ChatCreationData? creationData;

  const ConversationsSend({super.key, this.creationData});

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

      if (operation.attributes == null) {
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
        final Map<String, dynamic>? nextAttributes =
            operations[i + 1].attributes;

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

    return text.substring(0, text.length - 1);
  }

  Future<void> newConversation(String text) async {
    final bool status = await connectionChecker.connected;
    if (!status) {
      showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              icon: const Icon(Icons.wifi_off),
              title: Text(AppLocalizations.of(context)!.noInternetConnection2),
              actions: [
                FilledButton(
                    onPressed: () async {
                      Navigator.pop(context);
                    },
                    child: const Text("Ok")),
              ],
            );
          });
      return;
    }

    final textMessage = Message(
      text: text,
      own: true,
      date: DateTime.now(),
      author: null,
      state: MessageState.first,
      status: MessageStatus.sent,
    );

    final CreationResponse response = await client.conversations
        .createConversation(
            widget.creationData!.receivers,
            widget.creationData!.type?.name,
            widget.creationData!.subject,
            text);

    if (response.success) {
      client.fetchers.conversationsFetcher.fetchData(forceRefresh: true);

      Navigator.pop(context);
      Navigator.pop(context);
      Navigator.pop(context);
      Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => ConversationsChat(
              title: widget.creationData!.subject,
              id: response.id!,
              newSettings: NewConversationSettings(
                  firstMessage: textMessage,
                  settings: ConversationSettings(
                      id: response.id!,
                      groupChat:
                          widget.creationData!.type == ChatType.groupOnly,
                      onlyPrivateAnswers: widget.creationData!.type ==
                          ChatType.privateAnswerOnly,
                      noReply:
                          widget.creationData!.type == ChatType.noAnswerAllowed,
                      own: true)))));
    } else {
      showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              icon: const Icon(Icons.error),
              title:
                  Text(AppLocalizations.of(context)!.errorCreatingConversation),
              actions: [
                FilledButton(
                    onPressed: () async {
                      Navigator.pop(context);
                    },
                    child: const Text("Ok")),
              ],
            );
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              onPressed: () {
                _controller.clear();
              },
              icon: const Icon(Icons.delete_forever),
            ),
            IconButton(
              onPressed: () {
                final String text = parseText(_controller.document.toDelta());

                if (text.isEmpty) return;

                if (widget.creationData != null) {
                  newConversation(text);
                } else {
                  Navigator.pop(context, text);
                }
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
                      placeholder:
                          AppLocalizations.of(context)!.sendMessagePlaceholder,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0))),
            ),
            QuillToolbar(
              child: DecoratedBox(
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer),
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
                          attribute: Attribute.strikeThrough),
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
                          attribute: Attribute.superscript),
                      QuillToolbarToggleStyleButton(
                          controller: _controller,
                          attribute: Attribute.subscript),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ));
  }
}
