import 'package:dart_date/dart_date.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:flutter_masonry_view/flutter_masonry_view.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:intl/intl.dart';
import 'package:lanis/applets/substitutions/definition.dart';
import 'package:lanis/applets/substitutions/substitutions_listtile.dart';
import 'package:lanis/utils/cached_network_image.dart';
import 'package:lanis/utils/root_nav.dart';
import 'package:liblanis/liblanis.dart';

import '../../utils/url_modal.dart';
import '../../widgets/combined_applet_builder.dart';

class SubstitutionsView extends ConsumerStatefulWidget {
  final Function? openDrawerCb;
  const SubstitutionsView({super.key, this.openDrawerCb});

  @override
  ConsumerState<SubstitutionsView> createState() => _SubstitutionsViewState();
}

class _SubstitutionsViewState extends ConsumerState<SubstitutionsView>
    with TickerProviderStateMixin {
  static const double padding = 12.0;

  List<GlobalKey<RefreshIndicatorState>> globalKeys = [
    GlobalKey<RefreshIndicatorState>(),
  ];
  TabController? _tabController;
  String? _selectedDate;

  void _ensureGlobalKeys(int dayCount) {
    final needed = dayCount == 0 ? 1 : dayCount + 1;
    if (globalKeys.length != needed) {
      globalKeys = List.generate(
        needed,
        (_) => GlobalKey<RefreshIndicatorState>(),
      );
    }
  }

  Widget lastWidget({required int entriesLength, required DateTime lastEdit}) {
    return ListTile(
      title: Center(
        child: Text(
          AppLocalizations.of(context).noFurtherEntries,
          style: const TextStyle(fontSize: 22),
        ),
      ),
      subtitle: Center(
        child: Text(
          AppLocalizations.of(
            context,
          ).substitutionsEndCardMessage(lastEdit.format('dd.MM.yyyy HH:mm')),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  List<Widget> getSubstitutionViews(
    SubstitutionPlan substitutionPlan,
    RefreshFunction? refresh,
  ) {
    double deviceWidth = MediaQuery.of(context).size.width;

    List<Widget> substitutionViews = [];

    for (
      int dayIndex = 0;
      dayIndex < substitutionPlan.days.length;
      dayIndex++
    ) {
      final int entriesLength =
          substitutionPlan.days[dayIndex].substitutions.length;

      substitutionViews.add(
        RefreshIndicator(
          key: globalKeys[dayIndex + 1],
          notificationPredicate: refresh != null
              ? (_) => true
              : (_) =>
                    false, // Hide refresh indicator without bloating the code
          onRefresh: refresh ?? () async {},
          child: Padding(
            padding: EdgeInsets.only(
              left: padding,
              right: padding,
              top: padding,
            ),
            child: ListView(
              children: [
                if (_tabController != null &&
                    substitutionPlan.days[dayIndex].infos != null &&
                    substitutionPlan.days[dayIndex].infos!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 8.0,
                      right: 8.0,
                      left: 8.0,
                    ),
                    child: ElevatedButton(
                      onPressed: () => showSubstitutionInformation(
                        context,
                        substitutionPlan.days[dayIndex].infos!,
                      ),
                      child: Text(
                        AppLocalizations.of(
                          context,
                        ).substitutionsInformationMessage,
                      ),
                    ),
                  ),
                MasonryView(
                  listOfItem: substitutionPlan.days[dayIndex].substitutions,
                  numberOfColumn: deviceWidth ~/ 350 == 0
                      ? 1
                      : deviceWidth ~/ 350,
                  itemPadding: 4.0,
                  itemBuilder: (data) {
                    return Card(
                      child: SubstitutionListTile(substitutionData: data),
                    );
                  },
                ),
                lastWidget(
                  entriesLength: entriesLength,
                  lastEdit: substitutionPlan.lastUpdated,
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );
    }

    return substitutionViews;
  }

  List<Tab> getTabs(SubstitutionPlan substitutionPlan) {
    List<Tab> tabs = [];

    for (SubstitutionDay day in substitutionPlan.days) {
      String entryCount = day.substitutions.length.toString();
      tabs.add(
        Tab(
          icon: day.substitutions.isNotEmpty
              ? Badge(
                  label: Text(entryCount),
                  child: const Icon(Icons.calendar_today),
                )
              : const Icon(Icons.calendar_today),
          text: formatDate(day.parsedDate),
        ),
      );
    }

    return tabs;
  }

  void showSubstitutionInformation(
    BuildContext context,
    List<SubstitutionInfo> infos,
  ) {
    showRootModalBottomSheet(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.only(right: 16, left: 16, bottom: 16),
          child: ListView(
            shrinkWrap: true,
            children: [
              ...infos.map(
                (info) => Column(
                  spacing: 4.0,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.header,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SelectionArea(
                      child: HtmlWidget(
                        info.values.join('<br>'),
                        renderMode: RenderMode.column,
                        onTapUrl: (url) {
                          openUrlModal(context, Uri.parse(url));
                          return true;
                        },
                        customStylesBuilder: (element) {
                          if (element.localName == 'a' &&
                              element.attributes['style'] != null) {
                            RegExp regex = RegExp(
                              r'background-color:\s*[^;]+;',
                            );
                            element.attributes['style'] = element
                                .attributes['style']!
                                .replaceAll(regex, '');
                          }
                          return null;
                        },
                        onTapImage: (imageMetadata) {
                          if (imageMetadata.sources.isNotEmpty) {
                            pushOverlay(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FullScreenImageView(
                                  imageData: imageMetadata.sources.first.url,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    SizedBox(height: 8.0),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).asData?.value;
    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final parser = ref.watch(substitutionsParserProvider);
    return CombinedAppletBuilder<SubstitutionPlan>(
      accountType:
          session.accountTypeOrNull ??
          ref.read(activeAccountProvider)?.accountType ??
          AccountType.student,
      parser: parser,
      phpUrl: substitutionDefinition.appletPhpUrl,
      settingsDefaults: substitutionDefinition.settingsDefaults,
      loadingAppBar: AppBar(
        title: Text(substitutionDefinition.label(context)),
        leading: widget.openDrawerCb != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => widget.openDrawerCb!(),
              )
            : null,
      ),
      builder: (context, data, accountType, settings, updateSetting, refresh) {
        if (data.days.isEmpty) {
          _ensureGlobalKeys(0);
          return Scaffold(
            appBar: AppBar(
              title: Text(substitutionDefinition.label(context)),
              leading: widget.openDrawerCb != null
                  ? IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => widget.openDrawerCb!(),
                    )
                  : null,
            ),
            floatingActionButton: FloatingActionButton(
              heroTag: null,
              onPressed: () async {
                await context.push('/common/substitutions/filter');
              },
              child: const Icon(Icons.filter_alt),
            ),
            body: RefreshIndicator(
              key: globalKeys[0],
              notificationPredicate: refresh != null
                  ? (_) => true
                  : (_) => false,
              onRefresh: refresh ?? () async {},
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Spacer(),
                        const Icon(Icons.sentiment_dissatisfied, size: 60),
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            AppLocalizations.of(context).noEntries,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Spacer(),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          child: Text(
                            AppLocalizations.of(context).substitutionsLastEdit(
                              data.lastUpdated.format('dd.MM.yyyy HH:mm'),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          _ensureGlobalKeys(data.days.length);
          int currentIndex = _selectedDate != null
              ? data.days
                    .indexWhere((day) => day.parsedDate == _selectedDate)
                    .clamp(0, data.days.length)
              : 0;

          if (_tabController == null ||
              _tabController!.length != data.days.length) {
            final old = _tabController;
            _tabController = TabController(
              length: data.days.length,
              vsync: this,
              initialIndex: currentIndex.clamp(0, data.days.length - 1),
            );
            _tabController!.addListener(() {
              _selectedDate = data.days[_tabController!.index].parsedDate;
            });
            if (old != null) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => old.dispose(),
              );
            }
          } else if (_tabController!.index != currentIndex &&
              currentIndex < data.days.length) {
            _tabController!.index = currentIndex;
          }

          return Scaffold(
            appBar: AppBar(
              title: Text(substitutionDefinition.label(context)),
              leading: widget.openDrawerCb != null
                  ? IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => widget.openDrawerCb!(),
                    )
                  : null,
            ),
            floatingActionButton: FloatingActionButton(
              heroTag: null,
              onPressed: () async {
                await context.push('/common/substitutions/filter');
              },
              child: const Icon(Icons.filter_alt),
            ),
            body: Column(
              children: [
                TabBar(
                  isScrollable: true,
                  controller: _tabController,
                  tabs: getTabs(data),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: getSubstitutionViews(data, refresh),
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }
}

String formatDate(String dateString) {
  final inputFormat = DateFormat('dd.MM.yyyy');
  final dateTime = inputFormat.parse(dateString);

  final germanFormat = DateFormat('E dd.MM.yyyy', 'de');
  return germanFormat.format(dateTime);
}

class FullScreenImageView extends StatelessWidget {
  final String imageData;

  const FullScreenImageView({super.key, required this.imageData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.black,
      body: InteractiveViewer(
        panEnabled: true,
        minScale: 0.5,
        maxScale: 4.0,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.center,
          child: CachedNetworkImage(
            placeholder: const CircularProgressIndicator(),
            imageUrl: Uri.parse(imageData),
            builder: (context, imageProvider) {
              return Image(image: imageProvider);
            },
          ),
        ),
      ),
    );
  }
}
