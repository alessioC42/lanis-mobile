import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dart_date/dart_date.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:html/parser.dart';
import 'package:intl/intl.dart';
import 'package:sph_plan/shared/widgets/format_text.dart';
import 'package:sph_plan/view/conversations/send.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../client/client.dart';
import '../../shared/exceptions/client_status_exceptions.dart';
import '../../shared/types/conversations.dart';
import '../../shared/widgets/error_view.dart';
import 'shared.dart';

class ConversationsChat extends StatefulWidget {
  final String id; // uniqueId
  final String title;
  final NewConversationSettings? newSettings;

  const ConversationsChat(
      {super.key, required this.title, required this.id, this.newSettings});

  @override
  State<ConversationsChat> createState() => _ConversationsChatState();
}

class _ConversationsChatState extends State<ConversationsChat>
    with SingleTickerProviderStateMixin {
  late final Future<dynamic> _conversationFuture = initConversation();
  late final AnimationController appBarController;

  final TextEditingController messageField = TextEditingController();
  final ScrollController scrollController = ScrollController();

  final ValueNotifier<bool> isSendVisible = ValueNotifier<bool>(false);

  final Map<String, TextStyle> textStyles = {};

  late final ConversationSettings settings;
  late final ParticipationStatistics? statistics;

  final List<dynamic> chat = [];

  @override
  void initState() {
    // Make the app bar title disappear when scrolled to the top
    appBarController = AnimationController(vsync: this);
    scrollController.addListener(animateAppBarTitle);
    animateAppBarTitle();

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    appBarController.dispose();
    scrollController.dispose();
  }

  animateAppBarTitle() {
    if (!scrollController.hasClients) return;

    const appBarHeight = 56.0;

    if (scrollController.offset >= appBarHeight &&
        appBarController.value == 0) {
      appBarController.value = 1;
    } else if (scrollController.offset == 0 && appBarController.value == 1) {
      appBarController.reverse();
    }
  }

  static DateTime parseDateString(String date) {
    if (date.contains("heute")) {
      DateTime now = DateTime.now();
      DateTime conversation = DateFormat("H:m").parse(date.substring(6));

      return now.copyWith(
          hour: conversation.hour, minute: conversation.minute, second: 0);
    } else if (date.contains("gestern")) {
      DateTime yesterday = DateTime.now().subtract(const Duration(days: 1));
      DateTime conversation = DateFormat("H:m").parse(date.substring(8));

      return yesterday.copyWith(
          hour: conversation.hour, minute: conversation.minute, second: 0);
    } else {
      return DateFormat("d.M.y H:m").parse(date);
    }
  }

  void addAuthorTextStyles(final List<String> authors) {
    final ThemeData theme = Theme.of(context);
    for (final String author in authors) {
      textStyles[author] = BubbleStyle.getAuthorTextStyle(theme, author);
    }
  }

  Future<void> sendMessage(String text) async {
    MessageState state = MessageState.first;
    if (chat.last is Message) {
      DateTime date = chat.last.date;
      if (date.isToday) {
        state = MessageState.series;
      }
    }

    final textMessage = Message(
      text: text,
      own: true,
      date: DateTime.now(),
      author: null,
      state: state,
      status: MessageStatus.sending,
    );

    setState(() {
      DateTime lastMessageDate = chat.last.date;
      if (lastMessageDate.isToday) {
        chat.add(textMessage);
      } else {
        chat.addAll([DateHeader(date: DateTime.now()), textMessage]);
      }
    });

    final bool result = await client.conversations.replyToConversation(
        settings.id,
        "all",
        settings.groupChat ? "ja" : "nein",
        settings.onlyPrivateAnswers ? "ja" : "nein",
        text);

    setState(() {
      if (result) {
        chat.last.status = MessageStatus.sent;
      } else {
        chat.last.status = MessageStatus.error;
        showSnackbar(
            context, AppLocalizations.of(context)!.errorSendingMessage);
      }
    });
  }

  Message addMessage(UnparsedMessage message, MessageState position) {
    final contentParsed = parse(message.content);
    final content = contentParsed.body!.text;

    return Message(
      text: content,
      own: message.own,
      author: message.author,
      date: parseDateString(message.date),
      state: position,
      status: MessageStatus.sent,
    );
  }

  void parseMessages(Conversation unparsedMessages) {
    DateTime date = parseDateString(unparsedMessages.parent.date);
    String author = unparsedMessages.parent.author;
    MessageState position = MessageState.first;

    final Set<String> authors = {};

    if (unparsedMessages.parent.own != true) {
      authors.add(author);
    }

    chat.addAll([
      DateHeader(date: date),
      addMessage(unparsedMessages.parent, position)
    ]);

    late DateTime currentDate;
    for (UnparsedMessage current in unparsedMessages.replies) {
      currentDate = parseDateString(current.date);

      position = MessageState.first;
      if (current.author == author) {
        if (date.isSameDay(currentDate)) {
          position = MessageState.series;
        }
      }

      if (date.isSameDay(currentDate) && current.author == author) {
        chat.add(addMessage(current, position));
      } else if (date.isSameDay(currentDate) && current.author != author) {
        author = current.author;
        chat.addAll([addMessage(current, position)]);
      } else if (!date.isSameDay(currentDate) && current.author == author) {
        date = currentDate;
        chat.addAll([DateHeader(date: date), addMessage(current, position)]);
      } else {
        date = currentDate;
        author = current.author;
        chat.addAll([DateHeader(date: date), addMessage(current, position)]);
      }

      if (current.own != true) {
        authors.add(author);
      }
    }

    addAuthorTextStyles(authors.toList());
  }

  Future<void> initConversation() async {
    if (widget.newSettings == null) {
      Conversation response =
          await client.conversations.getSingleConversation(widget.id);

      settings = ConversationSettings(
        id: widget.id,
        groupChat: response.groupChat,
        onlyPrivateAnswers: response.onlyPrivateAnswers,
        noReply: response.noReply,
        author: response.parent.author,
        own: response.parent.own,
      );

      statistics = ParticipationStatistics(
          countParents: response.countParents,
          countStudents: response.countStudents,
          countTeachers: response.countTeachers,
          knownParticipants: response.knownParticipants);

      parseMessages(response);
    } else {
      settings = widget.newSettings!.settings;

      statistics = null;

      chat.addAll([
        DateHeader(date: widget.newSettings!.firstMessage.date),
        widget.newSettings!.firstMessage
      ]);
    }

    if (settings.own) {
      isSendVisible.value = true;
    } else {
      isSendVisible.value = !settings.noReply;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        floatingActionButton: ValueListenableBuilder(
            valueListenable: isSendVisible,
            builder: (context, isVisible, _) {
              return Visibility(
                visible: isVisible,
                child: FloatingActionButton.extended(
                  label: Text(AppLocalizations.of(context)!.newMessage),
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => const ConversationsSend()));
                  },
                ),
              );
            }),
        body: FutureBuilder(
            future: _conversationFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.waiting) {
                // Error content
                if (snapshot.hasError) {
                  if (snapshot.error is LanisException) {
                    return ErrorView(
                      error: snapshot.error as LanisException,
                      name: AppLocalizations.of(context)!.singleMessages,
                      fetcher: null,
                    );
                  }
                }

                return CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    SliverAppBar(
                        title: Animate(
                          effects: const [
                            FadeEffect(
                              curve: Curves.easeIn,
                            )
                          ],
                          value: 0,
                          autoPlay: false,
                          controller: appBarController,
                          child: Text(widget.title),
                        ),
                        snap: true,
                        floating: true,
                        actions: [
                          if (settings.groupChat == false &&
                              settings.onlyPrivateAnswers == false &&
                              settings.noReply == false) ...[
                            IconButton(
                                onPressed: () {
                                  showDialog(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          icon: const Icon(Icons.groups),
                                          title: Text(
                                              AppLocalizations.of(context)!
                                                  .conversationTypeName(
                                                      ChatType.openChat.name)),
                                          content: Text(
                                              AppLocalizations.of(context)!
                                                  .openChatWarning),
                                          actions: [
                                            FilledButton(
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                },
                                                child: const Text("Ok"))
                                          ],
                                        );
                                      });
                                },
                                icon: const Icon(Icons.warning))
                          ],
                          if (statistics != null) ...[
                            IconButton(
                                onPressed: () {
                                  showDialog(
                                      context: context,
                                      builder: (context) {
                                        return StatisticWidget(
                                            statistics: statistics!,
                                            otherParticipants: textStyles.keys);
                                      });
                                },
                                icon: const Icon(Icons.people)),
                          ]
                        ]),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12.0),
                                    child: Text(
                                      widget.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (settings.onlyPrivateAnswers &&
                                !settings.own) ...[
                              Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8.0, horizontal: 12.0),
                                margin: const EdgeInsets.only(top: 16.0),
                                decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHigh),
                                child: Text(
                                  "${settings.author} ${AppLocalizations.of(context)!.privateConversation}",
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  textAlign: TextAlign.center,
                                ),
                              )
                            ]
                          ],
                        ),
                      ),
                    ),
                    SliverList.builder(
                      itemCount: chat.length,
                      itemBuilder: (context, index) {
                        if (chat[index] is Message) {
                          return MessageWidget(
                              message: chat[index],
                              textStyle: textStyles[chat[index].author]);
                        } else {
                          return DateHeaderWidget(header: chat[index]);
                        }
                      },
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(
                        height: 75,
                      ),
                    )
                  ],
                );
              }
              // Waiting content
              return const Center(
                child: CircularProgressIndicator(),
              );
            }));
  }
}

class StatisticWidget extends StatelessWidget {
  final ParticipationStatistics statistics;
  final Iterable<String> otherParticipants;

  const StatisticWidget(
      {super.key, required this.statistics, required this.otherParticipants});

  @override
  Widget build(BuildContext context) {
    final Set<String> participants = statistics.knownParticipants.toSet();
    participants.addAll(otherParticipants);

    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.receivers),
      content: SizedBox(
          width: double.maxFinite,
          child: CustomScrollView(
            shrinkWrap: true,
            slivers: [
              SliverToBoxAdapter(
                  child: Column(
                children: [
                  ListTile(
                    title: Text(
                      AppLocalizations.of(context)!.statistic,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    leading: const Icon(Icons.numbers),
                    contentPadding: EdgeInsets.zero,
                  ),
                  ListTile(
                    title: Row(
                      children: [
                        Text(
                          "${statistics.countStudents}",
                        ),
                        Text(" ${AppLocalizations.of(context)!.participants}"),
                      ],
                    ),
                    leading: const Icon(Icons.person),
                    visualDensity: VisualDensity.compact,
                  ),
                  ListTile(
                    title: Row(
                      children: [
                        Text(
                          "${statistics.countTeachers}",
                        ),
                        Text(" ${AppLocalizations.of(context)!.supervisors}"),
                      ],
                    ),
                    leading: const Icon(Icons.school),
                    visualDensity: VisualDensity.compact,
                  ),
                  ListTile(
                    title: Row(
                      children: [
                        Text(
                          "${statistics.countParents}",
                        ),
                        Text(" ${AppLocalizations.of(context)!.parents}"),
                      ],
                    ),
                    leading: const Icon(Icons.supervisor_account),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              )),
              SliverToBoxAdapter(
                child: ListTile(
                  title: Text(
                    AppLocalizations.of(context)!.knownReceivers,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  leading: const Icon(Icons.people),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              SliverList.builder(
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(
                      participants.elementAt(index),
                    ),
                    visualDensity: VisualDensity.compact,
                  );
                },
                itemCount: participants.length,
              )
            ],
          )),
      actions: [
        FilledButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.back))
      ],
    );
  }
}

class DateHeaderWidget extends StatelessWidget {
  final DateHeader header;

  const DateHeaderWidget({super.key, required this.header});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Card(
          margin: const EdgeInsets.only(top: 16.0, bottom: 4.0),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Text(DateFormat(
                    "d. MMMM y", Localizations.localeOf(context).languageCode)
                .format(header.date)),
          ),
        )
      ],
    );
  }
}

class MessageWidget extends StatefulWidget {
  final Message message;
  final TextStyle? textStyle;

  const MessageWidget(
      {super.key, required this.message, required this.textStyle});

  @override
  State<MessageWidget> createState() => _MessageWidgetState();
}

class _MessageWidgetState extends State<MessageWidget>
    with SingleTickerProviderStateMixin {
  ValueNotifier<bool> tapped = ValueNotifier(false);
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double size = MediaQuery.sizeOf(context).width - 200;

    return Padding(
      padding: BubbleStructure.getMargin(widget.message.state),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: BubbleStructure.getAlignment(widget.message.own),
        children: [
          // Author name
          if (widget.message.state == MessageState.first &&
              !widget.message.own) ...[
            Text(
              widget.message.author!,
              style: widget.textStyle,
            )
          ],

          // Message bubble
          ClipPath(
            clipper: widget.message.state == MessageState.first
                ? BubbleStructure.getFirstStateClipper(widget.message.own)
                : null,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: size.clamp(350, 600),
              ),
              child: GestureDetector(
                onLongPress: () async {
                  tapped.value = false;
                  HapticFeedback.vibrate();
                  await Clipboard.setData(
                      ClipboardData(text: widget.message.text));
                  showSnackbar(
                      context, AppLocalizations.of(context)!.copiedMessage);
                  controller.value = 0;
                  controller.forward();
                },
                onTapDown: (_) async {
                  await Future.delayed(const Duration(milliseconds: 50));
                  tapped.value = true;
                },
                onTapUp: (_) async {
                  await Future.delayed(const Duration(milliseconds: 150));
                  tapped.value = false;
                },
                onTapCancel: () async {
                  setState(() {
                    tapped.value = false;
                  });
                },
                child: Animate(
                  autoPlay: false,
                  effects: const [
                    ShimmerEffect(
                      duration: Duration(milliseconds: 600),
                    )
                  ],
                  controller: controller,
                  child: ValueListenableBuilder(
                      valueListenable: tapped,
                      builder: (context, isTapped, _) {
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            color: isTapped
                                ? BubbleStyles.getStyle(widget.message.own)
                                    .pressedColor
                                : BubbleStyles.getStyle(widget.message.own)
                                    .mainColor,
                            borderRadius:
                                widget.message.state != MessageState.first
                                    ? BubbleStructure.radius
                                    : null,
                          ),
                          child: Padding(
                              padding: BubbleStructure.getPadding(
                                  widget.message.state == MessageState.first,
                                  widget.message.own),
                              child: FormattedText(
                                  text: widget.message.text,
                                  formatStyle:
                                      BubbleStyles.getStyle(widget.message.own)
                                          .textFormatStyle)),
                        );
                      }),
                ),
              ),
            ),
          ),

          // Date text
          Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: widget.message.state == MessageState.first
                      ? BubbleStructure.compensatedPadding
                      : BubbleStructure.horizontalPadding),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(DateFormat("HH:mm").format(widget.message.date),
                      style: BubbleStyles.getStyle(widget.message.own)
                          .dateTextStyle),
                  if (widget.message.own) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: Icon(
                        Icons.circle,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 3,
                      ),
                    ),
                    if (widget.message.status == MessageStatus.sending) ...[
                      const Padding(
                        padding: EdgeInsets.only(left: 2.0),
                        child: SizedBox(
                            width: 10.0,
                            height: 10.0,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                            )),
                      )
                    ] else if (widget.message.status ==
                        MessageStatus.error) ...[
                      Icon(
                        Icons.error,
                        color: Theme.of(context).colorScheme.error,
                        size: 12,
                      )
                    ] else ...[
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                        size: 12,
                      )
                    ]
                  ]
                ],
              ))
        ],
      ),
    );
  }
}