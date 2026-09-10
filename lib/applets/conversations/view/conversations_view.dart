import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/conversations/conversations_nav.dart';
import 'package:lanis/applets/conversations/view/send.dart';
import 'package:lanis/applets/conversations/view/shared.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/applets/conversations/definition.dart';
import 'package:lanis/utils/responsive.dart';
import 'package:lanis/widgets/combined_applet_builder.dart';
import '../../../utils/keyboard_observer.dart';
import 'conversation_tile.dart';

class ConversationsView extends ConsumerStatefulWidget {
  final Function? openDrawerCb;

  /// When true, used as the master list inside [ConversationsTabletShell].
  final bool embeddedInTabletShell;

  const ConversationsView({
    super.key,
    this.openDrawerCb,
    this.embeddedInTabletShell = false,
  });

  @override
  ConsumerState<ConversationsView> createState() => _ConversationsViewState();
}

class _ConversationsViewState extends ConsumerState<ConversationsView> {
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  static const advancedSearchIcons = {
    SearchFunction.subject: Icon(Icons.subject),
    SearchFunction.name: Icon(Icons.person),
    SearchFunction.schedule: Icon(Icons.calendar_today),
  };

  bool simpleRemoveButton = false;
  Map<SearchFunction, bool> advancedRemoveButtons = {
    SearchFunction.subject: false,
    SearchFunction.name: false,
    SearchFunction.schedule: false,
  };

  bool showHidden = false;
  bool advancedSearch = false;
  bool toggleMode = false;

  OverviewFiltering get filter => ref.read(conversationsParserProvider).filter;

  final TextEditingController simpleSearchController = TextEditingController();
  final Map<SearchFunction, TextEditingController> advancedSearchControllers = {
    SearchFunction.subject: TextEditingController(),
    SearchFunction.name: TextEditingController(),
    SearchFunction.schedule: TextEditingController(),
  };
  final ScrollController scrollController = ScrollController();
  final KeyboardObserver keyboardObserver = KeyboardObserver();

  final Map<String, bool> checkedTiles = {};

  bool loadingCreateButton = false;
  bool disableToggleButton = false;

  List<String> noBadgeConversations = [];

  bool get _isTablet =>
      Responsive.isSplitView(context) || widget.embeddedInTabletShell;

  String? get _selectedConversationId =>
      conversationIdFromLocation(GoRouterState.of(context).uri.path);

  void _clearConversationSelection() {
    if (_selectedConversationId != null && _isTablet) {
      context.go(conversationsHomePath);
    }
  }

  Widget toggleModeAppBar() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceDim,
      height: 64,
      width: double.infinity,
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.close,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            constraints: BoxConstraints.tightFor(
              width: kToolbarHeight,
              height: kToolbarHeight,
            ),
            onPressed: () {
              closeToggleMode();
              for (final tile in checkedTiles.keys) {
                checkedTiles[tile] = false;
              }
            },
          ),
          SizedBox(width: 16),
          Text(
            AppLocalizations.of(context).hideShowConversations,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }

  /// Height of the floating list header (search / toggle bar).
  ///
  /// Kept explicit so [SliverAppBar] can size itself — [SliverFloatingHeader]
  /// crashes when its child is rebuilt before layout (`child!.hasSize`).
  double get _listHeaderHeight {
    if (toggleMode) return 64;
    const searchBarHeight = 56.0;
    const bottomPad = 8.0;
    if (!advancedSearch) return searchBarHeight + bottomPad;
    return filter.advancedSearch.length * (searchBarHeight + bottomPad) +
        searchBarHeight +
        bottomPad;
  }

  Widget searchWidget() {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 0, bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Advanced search
          if (advancedSearch) ...[
            ...List<Padding>.generate(filter.advancedSearch.length, (i) {
              SearchFunction function = filter.advancedSearch.keys.elementAt(i);

              filterFunction(String text) {
                filter.advancedSearch[function] = text;
                filter.pushEntries();

                if (text.isEmpty) {
                  setState(() {
                    advancedRemoveButtons[function] = false;
                  });
                }

                if (advancedRemoveButtons[function] == false &&
                    text.isNotEmpty) {
                  setState(() {
                    advancedRemoveButtons[function] = true;
                  });
                }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: SearchBar(
                  hintText: AppLocalizations.of(
                    context,
                  ).individualSearchHint(function.name),
                  textInputAction: TextInputAction.search,
                  controller: advancedSearchControllers[function],
                  onSubmitted: filterFunction,
                  onChanged: filterFunction,
                  onTapOutside: (event) {
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: advancedSearchIcons[function],
                  ),
                  trailing: [
                    Visibility(
                      visible: advancedRemoveButtons[function]!,
                      child: IconButton(
                        onPressed: () {
                          filter.advancedSearch[function] = "";
                          advancedSearchControllers[function]!.clear();
                          filter.pushEntries();

                          setState(() {
                            advancedRemoveButtons[function] = false;
                          });
                        },
                        icon: const Icon(Icons.delete),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          // Simple search
          SearchBar(
            hintText: AppLocalizations.of(context).searchHint,
            textInputAction: TextInputAction.search,
            controller: simpleSearchController,
            onSubmitted: (String text) {
              filter.simpleSearch = text;
              filter.pushEntries();
            },
            onChanged: (String text) {
              filter.simpleSearch = text;
              filter.pushEntries();

              if (text.isEmpty) {
                setState(() {
                  simpleRemoveButton = false;
                });
              }

              if (simpleRemoveButton == false && text.isNotEmpty) {
                setState(() {
                  simpleRemoveButton = true;
                });
              }
            },
            onTapOutside: (event) {
              FocusManager.instance.primaryFocus?.unfocus();
            },
            trailing: [
              Visibility(
                visible: simpleRemoveButton,
                child: IconButton(
                  onPressed: () {
                    filter.simpleSearch = "";
                    simpleSearchController.clear();
                    filter.pushEntries();

                    setState(() {
                      simpleRemoveButton = false;
                    });
                  },
                  icon: const Icon(Icons.delete),
                ),
              ),
              MenuAnchor(
                builder: (context, controller, _) => IconButton(
                  onPressed: () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      controller.open();
                    }
                  },
                  icon: const Icon(Icons.more_vert),
                ),
                menuChildren: [
                  MenuItemButton(
                    leadingIcon: advancedSearch
                        ? Icon(Icons.search_off)
                        : Icon(Icons.search),
                    onPressed: () {
                      setState(() {
                        advancedSearch = !advancedSearch;
                      });
                    },
                    child: Text(
                      advancedSearch
                          ? AppLocalizations.of(context).simpleSearch
                          : AppLocalizations.of(context).advancedSearch,
                    ),
                  ),
                  MenuItemButton(
                    leadingIcon: showHidden
                        ? const Icon(Icons.visibility_off)
                        : const Icon(Icons.visibility),
                    onPressed: () {
                      setState(() {
                        if (showHidden) {
                          _clearConversationSelection();
                        }
                        showHidden = !showHidden;
                      });

                      final oldEntries = ref
                          .read(conversationsParserProvider)
                          .stream
                          .value
                          .content;
                      if (oldEntries == null) return;

                      filter.showHidden = showHidden;
                      filter.pushEntries();

                      final newEntries = ref
                          .read(conversationsParserProvider)
                          .stream
                          .value
                          .content;
                      if (newEntries == null) return;

                      jumpToTopTile(newEntries, oldEntries);
                    },
                    child: Text(
                      showHidden
                          ? AppLocalizations.of(context).showOnlyVisible
                          : AppLocalizations.of(context).showAll,
                    ),
                  ),
                  const Divider(),
                  MenuItemButton(
                    leadingIcon: Icon(Icons.restore_from_trash),
                    onPressed: () {
                      final oldEntries = ref
                          .read(conversationsParserProvider)
                          .stream
                          .value
                          .content;
                      if (oldEntries == null) return;

                      openToggleMode();

                      final newEntries = ref
                          .read(conversationsParserProvider)
                          .stream
                          .value
                          .content;
                      if (newEntries == null) return;

                      jumpToTopTile(newEntries, oldEntries);
                    },
                    child: Text(AppLocalizations.of(context).hideShow),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Switching between two lists of overview entries messes up the scroll controller, so we just try to jump to the top visible tile and anchor to it.
  // If top tile is not visible in the new list, we try to find the first visible tile above the top tile and jump to it.
  void jumpToTopTile(
    final List<OverviewEntry> entries,
    final List<OverviewEntry> oldEntries,
  ) {
    if (oldEntries.isEmpty) return;

    final offsetTopIndex = (scrollController.offset / 80).toInt();

    double position = 0;
    if (!(entries.contains(oldEntries[offsetTopIndex]))) {
      for (int i = offsetTopIndex; i >= 0; i--) {
        if (entries.contains(oldEntries[i])) {
          final index = entries.indexOf(oldEntries[i]);
          position = index * tileSize;
          break;
        }
      }
    } else {
      final index = entries.indexOf(oldEntries[offsetTopIndex]);
      position = index * tileSize;
    }

    final viewport = scrollController.position.viewportDimension;
    final size = (entries.length + 2.5) * tileSize;

    if (size < viewport) {
      return;
    }

    if (position >= size - viewport) {
      scrollController.jumpTo(size - viewport + 64);
    } else {
      scrollController.jumpTo(
        position + (scrollController.offset - (offsetTopIndex * tileSize)),
      );
    }
  }

  void openToggleMode() {
    setState(() {
      toggleMode = true;
    });
    filter.toggleMode = true;
    filter.pushEntries();
    ref.read(conversationsParserProvider).toggleSuspend();
  }

  void closeToggleMode() {
    setState(() {
      toggleMode = false;
      disableToggleButton = false;
    });

    final oldEntries = ref
        .read(conversationsParserProvider)
        .stream
        .value
        .content;
    if (oldEntries == null) return;

    filter.toggleMode = false;
    filter.pushEntries();

    ref.read(conversationsParserProvider).toggleSuspend();

    final newEntries = ref
        .read(conversationsParserProvider)
        .stream
        .value
        .content;
    if (newEntries == null) return;

    jumpToTopTile(newEntries, oldEntries);
  }

  @override
  void initState() {
    super.initState();

    ref.read(conversationsParserProvider).fetchData();

    keyboardObserver.addDefaultCallback();

    simpleSearchController.text = filter.simpleSearch;

    for (final value in SearchFunction.values) {
      advancedSearchControllers[value]!.text =
          filter.advancedSearch[value] ?? "";
    }
  }

  @override
  void dispose() {
    super.dispose();

    simpleSearchController.dispose();
    for (final value in SearchFunction.values) {
      advancedSearchControllers[value]!.dispose();
    }

    keyboardObserver.dispose();

    scrollController.dispose();
  }

  void openCreateConversation() async {
    bool? canChooseType = ref
        .read(conversationsParserProvider)
        .cachedCanChooseType;

    if (canChooseType == null) {
      setState(() {
        loadingCreateButton = true;
      });

      try {
        canChooseType = await ref
            .read(conversationsParserProvider)
            .canChooseType();
      } catch (_) {
        if (!mounted) return;
        setState(() {
          loadingCreateButton = false;
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).error)),
          );
        }
        return;
      }

      if (!mounted) return;
      setState(() {
        loadingCreateButton = false;
      });
    }

    if (mounted) {
      final chatData = await context.push<ChatCreationData>(
        '/common/conversations/compose',
      );
      if (chatData == null) return;
      final text = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) =>
              FullScreenConversationsMessageInput(creationData: chatData),
        ),
      );
      if (text == null || text.trim().isEmpty) return;
      if (mounted) {
        newConversation(text, chatData);
      }
    }
  }

  Future<void> newConversation(
    String text,
    ChatCreationData creationData,
  ) async {
    final bool status = await ref.read(connectionCheckerProvider).connected;
    if (!status) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              icon: const Icon(Icons.wifi_off),
              title: Text(AppLocalizations.of(context).noInternetConnection2),
              actions: [
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(context);
                  },
                  child: const Text("Ok"),
                ),
              ],
            );
          },
        );
      }
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

    final CreationResponse response;
    try {
      response = await ref
          .read(conversationsParserProvider)
          .createConversation(
            creationData.receivers,
            creationData.type?.name,
            creationData.subject,
            text,
          );
    } catch (_) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              icon: const Icon(Icons.error),
              title: Text(
                AppLocalizations.of(context).errorCreatingConversation,
              ),
              actions: [
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(context);
                  },
                  child: const Text("Ok"),
                ),
              ],
            );
          },
        );
      }
      return;
    }

    if (response.success) {
      ref.read(conversationsParserProvider).fetchData(forceRefresh: true);

      if (mounted) {
        setState(() {
          noBadgeConversations.add(response.id!);
        });
        openConversationRoute(
          context,
          id: response.id!,
          title: creationData.subject,
          extra: NewConversationSettings(
            firstMessage: textMessage,
            settings: ConversationSettings(
              id: response.id!,
              groupChat: creationData.type == ChatType.groupOnly,
              onlyPrivateAnswers:
                  creationData.type == ChatType.privateAnswerOnly,
              noReply: creationData.type == ChatType.noAnswerAllowed,
              own: true,
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              icon: const Icon(Icons.error),
              title: Text(
                AppLocalizations.of(context).errorCreatingConversation,
              ),
              actions: [
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(context);
                  },
                  child: const Text("Ok"),
                ),
              ],
            );
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activeAccountIdProvider, (previous, next) {
      if (previous == next) return;
      setState(() {
        showHidden = false;
        advancedSearch = false;
        toggleMode = false;
        simpleRemoveButton = false;
        advancedRemoveButtons = {
          SearchFunction.subject: false,
          SearchFunction.name: false,
          SearchFunction.schedule: false,
        };
        checkedTiles.clear();
        noBadgeConversations = [];
        simpleSearchController.clear();
        for (final controller in advancedSearchControllers.values) {
          controller.clear();
        }
      });
      if (_selectedConversationId != null) {
        context.go(conversationsHomePath);
      }
    });
    if (ref.watch(sessionProvider).asData?.value == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(conversationsDefinition.label(context)),
          automaticallyImplyLeading: !widget.embeddedInTabletShell,
          scrolledUnderElevation: 0.0,
          // M3 still swaps surface → surfaceContainer when scrolled-under,
          // even with scrolledUnderElevation: 0. Lock the color explicitly.
          backgroundColor: Theme.of(context).colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          leading: widget.openDrawerCb != null
              ? IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => widget.openDrawerCb!(),
                )
              : null,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final selectedId = _selectedConversationId;
    final surface = Theme.of(context).colorScheme.surface;

    return Scaffold(
      appBar: AppBar(
        title: Text(conversationsDefinition.label(context)),
        automaticallyImplyLeading: !widget.embeddedInTabletShell,
        scrolledUnderElevation: 0.0,
        // M3 still swaps surface → surfaceContainer when scrolled-under,
        // even with scrolledUnderElevation: 0. Lock the color explicitly.
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        leading: widget.openDrawerCb != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => widget.openDrawerCb!(),
              )
            : null,
      ),
      backgroundColor: surface,
      body: NotificationListener(
        onNotification: (notification) {
          if (notification is CheckTileNotification) {
            if (!toggleMode) {
              openToggleMode();
            }

            setState(() {
              checkedTiles[notification.id!] =
                  !(checkedTiles[notification.id!] ?? false);
            });
            return true;
          } else if (notification is JumpToNotification) {
            scrollController.jumpTo(notification.position!);
            return true;
          }

          return false;
        },
        child: Scaffold(
          backgroundColor: surface,
          body: CombinedAppletBuilder<List<OverviewEntry>>(
            parser: ref.watch(conversationsParserProvider),
            phpUrl: conversationsDefinition.appletPhpUrl,
            settingsDefaults: conversationsDefinition.settingsDefaults,
            accountType:
                ref.watch(sessionProvider).asData?.value?.accountTypeOrNull ??
                ref.watch(activeAccountProvider)?.accountType ??
                AccountType.student,
            builder:
                (context, data, accountType, settings, updateSetting, refresh) {
                  return RefreshIndicator(
                    key: _refreshKey,
                    edgeOffset: _listHeaderHeight,
                    onRefresh: refresh!,
                    child: CustomScrollView(
                      controller: scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverAppBar(
                          primary: false,
                          floating: true,
                          snap: true,
                          pinned: false,
                          automaticallyImplyLeading: false,
                          backgroundColor: Colors.transparent,
                          surfaceTintColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          elevation: 0.0,
                          scrolledUnderElevation: 0.0,
                          toolbarHeight: 0,
                          bottom: PreferredSize(
                            preferredSize: Size.fromHeight(_listHeaderHeight),
                            child: SizedBox(
                              height: _listHeaderHeight,
                              width: double.infinity,
                              child: toggleMode
                                  ? toggleModeAppBar()
                                  : searchWidget(),
                            ),
                          ),
                        ),
                        SliverVariedExtentList.builder(
                          itemCount: data.length + 1,
                          itemExtentBuilder: (index, _) {
                            if (index > data.length - 1) {
                              return tileSize * 2.5;
                            }

                            return tileSize;
                          },
                          itemBuilder: (context, index) {
                            if (index > data.length - 1) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                  top: 12.0,
                                  left: 12.0,
                                  right: 12.0,
                                ),
                                child: ListTile(
                                  subtitle: Text(
                                    AppLocalizations.of(
                                      context,
                                    ).conversationNote,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            }

                            return ConversationTile(
                              entry: data[index],
                              isOpen: selectedId == data[index].id,
                              toggleMode: toggleMode,
                              loadedConversationId: selectedId,
                              noBadgeConversations: noBadgeConversations,
                              checked: checkedTiles[data[index].id] ?? false,
                              onTap: (entry) {
                                setState(() {
                                  noBadgeConversations.add(entry.id);
                                });
                                if (entry.unread == true) {
                                  ref
                                      .read(conversationsParserProvider)
                                      .filter
                                      .toggleEntry(entry.id, unread: true);
                                  ref
                                      .read(conversationsParserProvider)
                                      .filter
                                      .pushEntries();
                                }
                                openConversationRoute(
                                  context,
                                  id: entry.id,
                                  title: entry.title,
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
          ),
          floatingActionButton: toggleMode
              ? disableToggleButton
                    ? FloatingActionButton(
                        heroTag: null,
                        onPressed: null,
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: const CircularProgressIndicator(),
                        ),
                      )
                    : FloatingActionButton.extended(
                        heroTag: null,
                        icon: Icon(Icons.visibility),
                        label: Text(AppLocalizations.of(context).hideShow),
                        onPressed: () async {
                          setState(() {
                            disableToggleButton = true;
                          });
                          _clearConversationSelection();

                          // So you don't see each tile being toggled
                          Map<String, bool> toggled = {};

                          for (final tile in checkedTiles.entries) {
                            if (tile.value == true) {
                              final isHidden = filter.entries
                                  .where((element) => element.id == tile.key)
                                  .first
                                  .hidden;

                              late bool result;
                              try {
                                if (isHidden) {
                                  result = await ref
                                      .read(conversationsParserProvider)
                                      .showConversation(tile.key);
                                } else {
                                  result = await ref
                                      .read(conversationsParserProvider)
                                      .hideConversation(tile.key);
                                }
                              } catch (e) {
                                if (!mounted) return;
                                setState(() {
                                  disableToggleButton = false;
                                });

                                if (context.mounted) {
                                  final isOffline = e is NoConnectionException;
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      icon: Icon(
                                        isOffline
                                            ? Icons.wifi_off
                                            : Icons.error,
                                      ),
                                      title: Text(
                                        isOffline
                                            ? AppLocalizations.of(
                                                context,
                                              ).noInternetConnection2
                                            : AppLocalizations.of(
                                                context,
                                              ).error,
                                      ),
                                      actions: [
                                        FilledButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                          child: Text(
                                            AppLocalizations.of(context).back,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return;
                              }

                              if (!result) {
                                setState(() {
                                  disableToggleButton = false;
                                });

                                if (context.mounted) {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      icon: const Icon(Icons.error),
                                      title: Text(
                                        AppLocalizations.of(
                                          context,
                                        ).errorOccurred,
                                      ),
                                      actions: [
                                        FilledButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                          child: Text(
                                            AppLocalizations.of(context).back,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return;
                              }

                              toggled.addEntries([tile]);
                              checkedTiles[tile.key] = false;
                            }
                          }

                          for (final id in toggled.keys) {
                            filter.toggleEntry(id, hidden: true);
                          }

                          filter.pushEntries();
                          closeToggleMode();
                        },
                      )
              : FloatingActionButton(
                  heroTag: null,
                  onPressed: openCreateConversation,
                  child: loadingCreateButton
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: const CircularProgressIndicator(),
                        )
                      : const Icon(Icons.edit),
                ),
        ),
      ),
    );
  }
}
