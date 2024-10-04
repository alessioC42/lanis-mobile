import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_tagging_plus/flutter_tagging_plus.dart';
import 'package:sph_plan/view/conversations/send.dart';

import '../../client/client.dart';
import '../../client/connection_checker.dart';
import '../../shared/types/conversations.dart';

class TypeChooser extends StatefulWidget {
  const TypeChooser({super.key});

  @override
  State<TypeChooser> createState() => _TypeChooserState();
}

class _TypeChooserState extends State<TypeChooser> {
  static const List<ChatType> chatTypes = ChatType.values;
  static ChatType selectedValue = chatTypes[0];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.conversationType),
        ),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => CreateConversation(chatType: selectedValue,)));
            },
            icon: const Icon(Icons.arrow_forward),
            label: Text(AppLocalizations.of(context)!.select)
        ),
        body: ListView.builder(
          itemCount: chatTypes.length,
          itemBuilder: (context, index) {
            return RadioListTile(
              value: chatTypes[index],
              groupValue: selectedValue,
              onChanged: (value) {
                setState(() {
                  selectedValue = value!;
                });
              },
              title: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Icon(chatTypes[index].icon),
                  ),
                  Text(AppLocalizations.of(context)!
                      .conversationTypeName(
                      chatTypes[index].name)),
                  if (chatTypes[index] == ChatType.openChat) ...[
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(right: 4.0),
                      child: Text(
                        AppLocalizations.of(context)!
                            .experimental
                            .toUpperCase(),
                        style: const TextStyle(
                            fontSize: 10.0,
                            fontWeight: FontWeight.bold),
                      ),
                    )
                  ]
                ],
              ),
              subtitle: Text(
                AppLocalizations.of(context)!
                    .conversationTypeDescription(
                    chatTypes[index].name),
                textAlign: TextAlign.start,
              ),
              isThreeLine: index == 3,
            );
          },
        )
    );
  }
}

class CreateConversation extends StatefulWidget {
  final ChatType? chatType;
  const CreateConversation({super.key, this.chatType});

  @override
  State<CreateConversation> createState() => _CreateConversationState();
}

class TriggerRebuild with ChangeNotifier {
  void trigger() {
    notifyListeners();
  }
}

class _CreateConversationState extends State<CreateConversation> {
  static final TextEditingController subjectController = TextEditingController();
  static final List<ReceiverEntry> receivers = [];
  final TriggerRebuild rebuildSearch = TriggerRebuild();


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.createNewConversation),
      ),
      floatingActionButton: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: FloatingActionButton.extended(
                onPressed: () {
                  subjectController.clear();
                  receivers.clear();
                  rebuildSearch.trigger();
                },
                heroTag: "clearAll",
                icon: const Icon(Icons.clear_all),
                label: Text(AppLocalizations.of(context)!.clearAll)
            ),
          ),
          FloatingActionButton.extended(
              onPressed: () {
                if (subjectController.text.isEmpty || receivers.isEmpty) {
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => ConversationsSend(
                        creationData: ChatCreationData(
                            type: widget.chatType,
                            subject: subjectController.text,
                            receivers: receivers
                                .map((entry) => entry.id)
                                .toList()),
                      )),
                );
              },
              icon: const Icon(Icons.create),
              label: Text(AppLocalizations.of(context)!.create)
          ),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: subjectController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.subject,
              ),
              maxLines: null,
              autofocus: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 12.0),
            child: ListenableBuilder(
              listenable: rebuildSearch,
              builder: (context, widget) {
                return FlutterTagging<ReceiverEntry>(
                  initialItems: receivers,
                  textFieldConfiguration: TextFieldConfiguration(
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!
                          .addReceiversHint,
                      labelText: AppLocalizations.of(context)!
                          .addReceivers,
                    ),
                  ),
                  configureSuggestion: (entry) {
                    return SuggestionConfiguration(
                      title: Text(entry.name),
                      leading: Icon(entry.isTeacher ? Icons.school : Icons.person),
                      subtitle: entry.isTeacher ? Text(AppLocalizations.of(context)!.teacher) : null,
                    );
                  },
                  configureChip: (entry) {
                    return ChipConfiguration(
                      label: Text(entry.name),
                      avatar: Icon(entry.isTeacher ? Icons.school : Icons.person),
                    );
                  },
                  loadingBuilder: (context) {
                    return ListTile(
                      leading: const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(),
                      ),
                      title: Text(AppLocalizations.of(context)!.loading),
                    );

                  },
                  emptyBuilder: (context) {
                    if (connectionChecker.status == ConnectionStatus.disconnected) {
                      return ListTile(
                        leading: const Icon(Icons.wifi_off),
                        title: Text(AppLocalizations.of(context)!.noInternetConnection2),
                      );
                    }

                    return ListTile(
                      leading: const Icon(Icons.person_off),
                      title: Text(AppLocalizations.of(context)!.noPersonFound),
                    );
                  },
                  onAdded: (receiverEntry) {
                    return receiverEntry;
                  },
                  findSuggestions: (query) async {
                    query = query.trim();
                    if (query.isEmpty) return <ReceiverEntry>[];

                    final dynamic result = await client
                        .conversations
                        .searchTeacher(query);
                    return result;
                  },
                );
              },
            ),),
        ],
      ),
    );
  }
}