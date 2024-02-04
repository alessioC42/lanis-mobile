import 'package:flutter/material.dart';
import 'package:html/parser.dart';
import 'package:sph_plan/shared/format_text.dart';
import '../../client/client.dart';

import '../../shared/errorView.dart';

class DetailedConversationAnsicht extends StatefulWidget {
  final String uniqueID;
  final String? title;

  const DetailedConversationAnsicht(
      {super.key, required this.uniqueID, required this.title});

  @override
  State<DetailedConversationAnsicht> createState() =>
      _DetailedConversationAnsichtState();
}

class _DetailedConversationAnsichtState
    extends State<DetailedConversationAnsicht> {
  late final Future<dynamic> _getSingleConversation;

  void showSnackbar(String text, {seconds = 1, milliseconds = 0}) {
    if (mounted) {
      // Hide the current SnackBar if one is already visible.
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          duration: Duration(seconds: seconds, milliseconds: milliseconds),
        ),
      );
    }
  }

  Future<dynamic> fetchConversation({secondTry = false}) async {
    client.searchTeacher("aa");

    try {
      if (secondTry) {
        await client.login();
      }

      return client.getSingleConversation(widget.uniqueID);
    } catch (e) {
      if (!secondTry) {
        fetchConversation(secondTry: true);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _getSingleConversation = fetchConversation();
  }

  Widget getConversationWidget(
      Map<String, dynamic> conversation, bool rootMessage) {
    final contentParsed = parse(conversation["Inhalt"]);
    final content = contentParsed.body!.text;

    final usernameParsed = parse(conversation["username"]);
    final username =
        usernameParsed.querySelector("span")?.text ?? conversation["username"];

    return Padding(
      padding: const EdgeInsets.only(left: 12.0, right: 12.0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0, top: 8.0),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 4.0),
                  child: Icon(
                    username == " , " ? Icons.person_off : Icons.person,
                    size: 18,
                  ),
                ),
                Text(
                  username == " , " ? "Kein Name" : username,
                  style: Theme.of(context).textTheme.labelSmall,
                )
              ],
            ),
          ),
          // Do not show title again in a comment.
          if (rootMessage) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                children: [
                  Flexible(
                    flex: 10,
                    child: Text(
                      conversation["Betreff"],
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Row(
              children: [
                Flexible(
                  flex: 10,
                  child: FormattedText(text: content,)
                )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Text(
                  conversation["Datum"],
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? "Nachricht"),
      ),
      body: FutureBuilder(
          future: _getSingleConversation,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.waiting) {
              // Error content
              if (snapshot.data is int) {
                return ErrorView.fromCode(
                  data: snapshot.data,
                  name: "einer einzelnen Nachricht",
                  fetcher: null,
                );
              }
              // Successful contents
              return ListView.builder(
                  itemCount: snapshot.data["reply"].length + 1,
                  itemBuilder: (context, index) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Shows on the first comment a "reply" icon.
                        if (index == 1) ...[
                          Flexible(
                            flex: 1,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 14.0),
                              child: RotatedBox(
                                quarterTurns: 1,
                                child: Transform.flip(
                                    flipY: true,
                                    child: const Icon(Icons.reply)),
                              ),
                            ),
                          ),
                        ],
                        // Make a empty box to align it with the first comment.
                        if (index >= 2) ...[
                          const Flexible(
                            flex: 1,
                            child: SizedBox.shrink(),
                          )
                        ],
                        Flexible(
                          flex: 10,
                          child: Padding(
                              padding: const EdgeInsets.only(
                                  left: 10.0, right: 10.0, bottom: 10.0),
                              child: Card(
                                  // Get root conversation widget or comments.
                                  child: getConversationWidget(
                                      index == 0
                                          ? snapshot.data
                                          : snapshot.data["reply"][index - 1],
                                      index == 0 ? true : false))),
                        ),
                      ],
                    );
                  });
            }
            // Waiting content
            return const Center(
              child: CircularProgressIndicator(),
            );
          }),
    );
  }
}
