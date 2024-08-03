import 'package:flutter/material.dart';
import 'package:flutter_tagging_plus/flutter_tagging_plus.dart';
import 'package:sph_plan/shared/exceptions/client_status_exceptions.dart';
import 'package:sph_plan/shared/types/conversations.dart';
import 'package:sph_plan/view/conversations/send.dart';

import '../../client/client.dart';
import '../../client/connection_checker.dart';
import '../../client/fetcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../shared/widgets/error_view.dart';
import 'chat.dart';

class ConversationsOverview extends StatefulWidget {
  const ConversationsOverview({super.key});

  @override
  State<StatefulWidget> createState() => _ConversationsOverviewState();
}

class _ConversationsOverviewState extends State<ConversationsOverview>
    with TickerProviderStateMixin {
  static const double padding = 12.0;

  final InvisibleConversationsFetcher invisibleConversationsFetcher =
      client.fetchers.invisibleConversationsFetcher;
  final VisibleConversationsFetcher visibleConversationsFetcher =
      client.fetchers.visibleConversationsFetcher;

  final GlobalKey<RefreshIndicatorState> _refreshVisibleKey =
      GlobalKey<RefreshIndicatorState>();
  final GlobalKey<RefreshIndicatorState> _refreshInvisibleKey =
      GlobalKey<RefreshIndicatorState>();

  dynamic visibleConversations;
  dynamic invisibleConversations;

  late TabController _tabController;

  @override
  void initState() {
    _tabController = TabController(length: 2, vsync: this);

    visibleConversationsFetcher.fetchData();
    invisibleConversationsFetcher.fetchData();

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _tabController.dispose();
  }

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


  ListTile getConversationWidget(Map<String, dynamic> conversation) {
    return ListTile(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 3,
            child: Text(
              conversation["Betreff"] ?? "",
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 21),
            ),
          ),
          Flexible(
            child: Text(
              conversation["kuerzel"] ?? "",
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                conversation["Datum"] ?? "",
              )
            ],
          ),
        ],
      ),
      leading: conversation["unread"] != null && conversation["unread"] == 1
          ? const Icon(Icons.notification_important)
          : null,
    );
  }

  Widget conversationsView(
      BuildContext context, conversations, Fetcher fetcher, GlobalKey key) {
    return RefreshIndicator(
      key: key,
      onRefresh: () async {
        fetcher.fetchData(forceRefresh: true);
      },
      child: ListView.builder(
        itemCount: conversations.length + 1,
        itemBuilder: (context, index) {
          if (index == conversations.length) {
            return ListTile(
                title: Center(
                  child: Text(
                    AppLocalizations.of(context)!.noFurtherEntries,
                    style: const TextStyle(fontSize: 21),
                  ),
                ),
              subtitle: Center(
                child: Text(
                  AppLocalizations.of(context)!.notificationsNote,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.only(
              left: padding,
              right: padding,
              bottom: index == conversations.length ? 14 : 8,
              top: index == 0 ? padding : 0,
            ),
            child: Card(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ConversationsChat(
                        id: conversations[index]
                        ["Uniquid"], // nice typo Lanis
                        title: conversations[index]["Betreff"],
                      ),
                    ),
                  );
                },
                customBorder: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: getConversationWidget(conversations[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: AppLocalizations.of(context)!.visible,
              icon: const Icon(Icons.visibility),
            ),
            Tab(
              text: AppLocalizations.of(context)!.invisible,
              icon: const Icon(Icons.visibility_off),
            )
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            StreamBuilder(
                stream: visibleConversationsFetcher.stream,
                builder: (context, snapshot) {
                  if (snapshot.data?.status == FetcherStatus.error) {
                    return ErrorView(
                        error: snapshot.data!.error!,
                        name: AppLocalizations.of(context)!.messages,
                        retry: retryFetcher(visibleConversationsFetcher));
                  } else if (snapshot.data?.status == FetcherStatus.fetching ||
                      snapshot.data == null) {
                    return const Center(child: CircularProgressIndicator());
                  } else {
                    return conversationsView(context, snapshot.data?.content,
                        visibleConversationsFetcher, _refreshVisibleKey);
                  }
                }),
            StreamBuilder(
                stream: invisibleConversationsFetcher.stream,
                builder: (context, snapshot) {
                  if (snapshot.data?.status == FetcherStatus.error) {
                    return ErrorView(
                        error: snapshot.data!.error!,
                        name: AppLocalizations.of(context)!.messages,
                        retry: retryFetcher(invisibleConversationsFetcher),);
                  } else if (snapshot.data?.status == FetcherStatus.fetching ||
                      snapshot.data == null) {
                    return const Center(child: CircularProgressIndicator());
                  } else {
                    return conversationsView(context, snapshot.data?.content,
                        invisibleConversationsFetcher, _refreshInvisibleKey);
                  }
                })
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            bool canChooseType;
            try {
              canChooseType = await client.conversations.canChooseType();
            } on NoConnectionException {
              return;
            }

            Navigator.of(context).push(
                MaterialPageRoute(builder: (context) {
                  if (canChooseType) {
                    return const TypeChooser();
                  }
                  return const CreateConversation(chatType: null);
                })
            );
          },
          child: const Icon(Icons.edit),
        ));
  }
}

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

