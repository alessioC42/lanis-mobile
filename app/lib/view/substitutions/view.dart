import 'package:dart_date/dart_date.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sph_plan/client/client_submodules/substitutions.dart';
import 'package:sph_plan/shared/exceptions/client_status_exceptions.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../client/fetcher.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/substitutions/substitutions_gridtile.dart';
import '../../shared/widgets/substitutions/substitutions_listtile.dart';
import 'filtersettings.dart';

/// Core UI for the [SubstitutionPlan] class.
class StaticSubstitutionsView extends StatefulWidget {
  final SubstitutionPlan? plan;
  final LanisException? lanisException;
  final Fetcher? fetcher;
  final Future<void> Function()? refresh;
  final bool loading;
  const StaticSubstitutionsView({super.key, this.plan, this.lanisException, this.fetcher, required this.refresh, this.loading = false});

  @override
  State<StatefulWidget> createState() => _StaticSubstitutionsViewState();
}


class _StaticSubstitutionsViewState extends State<StaticSubstitutionsView> with TickerProviderStateMixin{

  final double padding = 12.0;

  List<GlobalKey<RefreshIndicatorState>> globalKeys = [
    GlobalKey<RefreshIndicatorState>()
  ];
  TabController? _tabController;

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Widget lastWidget({required int entriesLength, required DateTime lastEdit}) {
    return ListTile(
      title: Center(
        child: Text(AppLocalizations.of(context)!.noFurtherEntries,
            style: const TextStyle(fontSize: 22)),
      ),
      subtitle: Center(
        child: Text(
          AppLocalizations.of(context)!
              .substitutionsEndCardMessage(lastEdit.format('dd.MM.yyyy HH:mm')),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  List<Widget> getSubstitutionViews(SubstitutionPlan substitutionPlan) {
    double deviceWidth = MediaQuery.of(context).size.width;

    List<Widget> substitutionViews = [];

    for (int dayIndex = 0;
    dayIndex < substitutionPlan.days.length;
    dayIndex++) {
      final int entriesLength =
          substitutionPlan.days[dayIndex].substitutions.length;

      substitutionViews.add(RefreshIndicator(
        key: globalKeys[dayIndex + 1],
        notificationPredicate: widget.refresh != null ? (_) => true : (_) => false, // Hide refresh indicator without bloating the code
        onRefresh: widget.refresh == null ? () async {} : widget.refresh!,
        child: Padding(
          padding: EdgeInsets.only(left: padding, right: padding, top: padding),
          child: (deviceWidth > 505)
              ? GridView.builder(
            itemCount: entriesLength + 1,
            itemBuilder: (context, entryIndex) {
              if (entryIndex == entriesLength) {
                return Padding(
                  padding: EdgeInsets.only(bottom: padding),
                  child: lastWidget(
                      entriesLength: entriesLength,
                      lastEdit: substitutionPlan.lastUpdated),
                );
              }

              return Card(
                child: SubstitutionGridTile(
                    substitutionData: substitutionPlan
                        .days[dayIndex].substitutions[entryIndex]),
              );
            },
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 500, childAspectRatio: 20 / 11),
          )
              : ListView.builder(
            itemCount: entriesLength + 1,
            itemBuilder: (context, entryIndex) {
              if (entryIndex == entriesLength) {
                return Padding(
                  padding: EdgeInsets.only(bottom: padding),
                  child: lastWidget(
                      entriesLength: entriesLength,
                      lastEdit: substitutionPlan.lastUpdated),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: SubstitutionListTile(
                      substitutionData: substitutionPlan
                          .days[dayIndex].substitutions[entryIndex]),
                ),
              );
            },
          ),
        ),
      ));
    }

    return substitutionViews;
  }

  List<Tab> getTabs(SubstitutionPlan substitutionPlan) {
    List<Tab> tabs = [];

    for (SubstitutionDay day in substitutionPlan.days) {
      String entryCount = day.substitutions.length.toString();
      tabs.add(Tab(
        icon: Badge(
          label: Text(entryCount),
          child: const Icon(Icons.calendar_today),
        ),
        text: formatDate(day.date),
      ));
    }

    return tabs;
  }

  Widget getBody() {
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    } else if (widget.lanisException != null || widget.plan == null) {
      return ErrorView(
        error: widget.lanisException!,
        name: AppLocalizations.of(context)!.substitutions,
        retry: retryFetcher(widget.fetcher!),
      );
    } else if (widget.plan!.days.isEmpty) {
      // GlobalKeys for RefreshIndicator and Refresh-FAB
      globalKeys += List.generate(widget.plan!.days.length,
              (index) => GlobalKey<RefreshIndicatorState>());
      return RefreshIndicator(
        key: globalKeys[0],
        notificationPredicate: widget.refresh != null ? (_) => true : (_) => false,
        onRefresh: widget.refresh == null ? () async {} : widget.refresh!,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.sentiment_dissatisfied, size: 60),
                  Padding(
                    padding: const EdgeInsets.all(35),
                    child: Text(AppLocalizations.of(context)!.noEntries,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        )),
                  ),
                ],
              ),
            )
          ],
        ),
      );
    } else {
      globalKeys += List.generate(widget.plan!.days.length,
              (index) => GlobalKey<RefreshIndicatorState>());

      _tabController = TabController(
          length: widget.plan!.days.length, vsync: this);
      return Column(
        children: [
          TabBar(
              isScrollable: true,
              controller: _tabController,
              tabs: getTabs(widget.plan!)),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: getSubstitutionViews(widget.plan!),
            ),
          )
        ],
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: getBody(),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (widget.refresh != null) ...[
            FloatingActionButton(
              onPressed: () => {
                for (GlobalKey<RefreshIndicatorState> globalKey in globalKeys)
                  {globalKey.currentState?.show()}
              },
              heroTag: "RefreshSubstitutions",
              child: const Icon(Icons.refresh),
            ),
            const SizedBox(
              height: 10,
            ),
            FloatingActionButton(
              onPressed: () => {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FilterSettingsScreen(),
                  ),
                ).then((value) => widget.refresh!())
              },
              child: const Icon(Icons.filter_alt),
            )
          ],
        ],
      ),
    );
  }
  
}

String formatDate(String dateString) {
  final inputFormat = DateFormat('dd.MM.yyyy');
  final dateTime = inputFormat.parse(dateString);

  final germanFormat = DateFormat('E dd.MM.yyyy', 'de');
  return germanFormat.format(dateTime);
}
