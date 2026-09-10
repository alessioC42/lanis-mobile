import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:flutter/services.dart';
import 'package:lanis/utils/file_operations.dart';
import 'package:lanis/view/settings/settings.dart';
import 'package:lanis/view/settings/settings_page_builder.dart';
import 'package:lanis/generated/l10n.dart';

class CalendarExport extends SettingsColours {
  final bool showBackButton;
  const CalendarExport({super.key, this.showBackButton = true});

  @override
  State<CalendarExport> createState() => _CalendarExportState();
}

class _CalendarExportState extends SettingsColoursState<CalendarExport> {
  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      backgroundColor: backgroundColor,
      title: Text(AppLocalizations.of(context).calendarExport),
      showBackButton: widget.showBackButton,
      children: [
        FutureBuilder(
          future: ProviderScope.containerOf(
            context,
          ).read(calendarParserProvider).getExports(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return LinearProgressIndicator();
            } else if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).errorOccurred,
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 24.0),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  Text(
                    AppLocalizations.of(context).calendarExportHint,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: 24.0),
                  SettingsTileWidget(
                    tile: SettingsTile(
                      title: (context) => "PDF",
                      subtitle: (context) async =>
                          AppLocalizations.of(context).dayWeekYearsList,
                      icon: Icons.picture_as_pdf,
                      screen: (context) async => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CalendarExportFile(
                            title: AppLocalizations.of(context).pdfExport,
                            fileType: "pdf",
                            entries: [
                              ExportGroup(
                                groupTitle: AppLocalizations.of(context).day,
                                entries: [
                                  (
                                    title: AppLocalizations.of(context).today,
                                    link:
                                        "https://start.schulportal.hessen.de/kalender.php?a=export&export=pdf&day=1",
                                    type: AppLocalizations.of(
                                      context,
                                    ).today.toLowerCase(),
                                  ),
                                  (
                                    title: AppLocalizations.of(
                                      context,
                                    ).tomorrow,
                                    link:
                                        "https://start.schulportal.hessen.de/kalender.php?a=export&export=pdf&day=2",
                                    type: AppLocalizations.of(
                                      context,
                                    ).tomorrow.toLowerCase(),
                                  ),
                                ],
                              ),
                              ExportGroup(
                                groupTitle: AppLocalizations.of(context).week,
                                entries: [
                                  (
                                    title: AppLocalizations.of(
                                      context,
                                    ).currentWeek,
                                    link:
                                        "https://start.schulportal.hessen.de/kalender.php?a=export&export=pdf&week=1",
                                    type: AppLocalizations.of(context)
                                        .currentWeek
                                        .toLowerCase()
                                        .replaceAll(" ", "-"),
                                  ),
                                  (
                                    title: AppLocalizations.of(
                                      context,
                                    ).nextWeek,
                                    link:
                                        "https://start.schulportal.hessen.de/kalender.php?a=export&export=pdf&week=2",
                                    type: AppLocalizations.of(context).nextWeek
                                        .toLowerCase()
                                        .replaceAll(" ", "-"),
                                  ),
                                ],
                              ),
                              for (int year in snapshot.data!.years) ...[
                                ExportGroup(
                                  groupTitle: "$year / ${year + 1}",
                                  entries: [
                                    (
                                      title: AppLocalizations.of(
                                        context,
                                      ).shortenedCalendar,
                                      link:
                                          "https://start.schulportal.hessen.de/kalender.php?a=export&export=pdf&year=$year",
                                      type:
                                          "${AppLocalizations.of(context).short}-$year",
                                    ),
                                    (
                                      title: AppLocalizations.of(
                                        context,
                                      ).extendedCalendar,
                                      link:
                                          "https://start.schulportal.hessen.de/kalender.php?a=export&export=pdf-extended&year=$year",
                                      type:
                                          "${AppLocalizations.of(context).extended}-$year",
                                    ),
                                    (
                                      title: AppLocalizations.of(
                                        context,
                                      ).wallCalendar,
                                      link:
                                          "https://start.schulportal.hessen.de/kalender.php?a=export&export=wandkalender&year=$year",
                                      type:
                                          "${AppLocalizations.of(context).wall}-$year",
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    disableSetState: true,
                    foregroundColor: foregroundColor,
                    index: 0,
                    length: 3,
                  ),
                  SettingsTileWidget(
                    tile: SettingsTile(
                      title: (context) => "iCal / ICS",
                      subtitle: (context) async => AppLocalizations.of(
                        context,
                      ).updatesYearsImportableList,
                      icon: Icons.date_range,
                      screen: (context) async => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CalendarExportFile(
                            title: AppLocalizations.of(context).iCalICSExport,
                            fileType: "ics",
                            entries: [
                              ExportGroup(
                                groupTitle: AppLocalizations.of(context).years,
                                entries: [
                                  for (int year in snapshot.data!.years) ...[
                                    (
                                      title: "$year / ${year + 1}",
                                      link:
                                          "https://start.schulportal.hessen.de/kalender.php?a=export&export=ical&year=$year",
                                      type: "$year",
                                    ),
                                  ],
                                ],
                              ),
                            ],
                            customChild: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: foregroundColor,
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppLocalizations.of(context).subscription,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium!
                                          .copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                          ),
                                    ),
                                    Text(
                                      AppLocalizations.of(
                                        context,
                                      ).subscriptionHint,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                    SizedBox(height: 24.0),
                                    SizedBox(
                                      height: 36.0,
                                      child: Material(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(
                                          12.0,
                                        ),
                                        child: InkWell(
                                          onTap: () {
                                            Clipboard.setData(
                                              ClipboardData(
                                                text: snapshot
                                                    .data!
                                                    .subscriptionLink,
                                              ),
                                            );
                                            ScaffoldMessenger.of(
                                              context,
                                            ).hideCurrentSnackBar();
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  AppLocalizations.of(
                                                    context,
                                                  ).linkCopied,
                                                ),
                                              ),
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(
                                            12.0,
                                          ),
                                          child: ListView(
                                            scrollDirection: Axis.horizontal,
                                            shrinkWrap: true,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  8.0,
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.copy,
                                                      size: 18.0,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onPrimaryContainer,
                                                    ),
                                                    SizedBox(width: 4.0),
                                                    Text(
                                                      snapshot
                                                          .data!
                                                          .subscriptionLink,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium!
                                                          .copyWith(
                                                            color: Theme.of(context)
                                                                .colorScheme
                                                                .onPrimaryContainer,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    disableSetState: true,
                    foregroundColor: foregroundColor,
                    index: 1,
                    length: 3,
                  ),
                  SettingsTileWidget(
                    tile: SettingsTile(
                      title: (context) => "CSV",
                      subtitle: (context) async =>
                          AppLocalizations.of(context).yearsImportableList,
                      icon: Icons.description,
                      screen: (context) async => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CalendarExportFile(
                            title: AppLocalizations.of(context).csvExport,
                            fileType: "csv",
                            entries: [
                              ExportGroup(
                                groupTitle: AppLocalizations.of(context).years,
                                entries: [
                                  for (int year in snapshot.data!.years) ...[
                                    (
                                      title: "$year / ${year + 1}",
                                      link:
                                          "https://start.schulportal.hessen.de/kalender.php?a=export&export=csv&year=$year",
                                      type: "$year",
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    disableSetState: true,
                    foregroundColor: foregroundColor,
                    index: 2,
                    length: 3,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class ExportGroup {
  final String groupTitle;
  final List<({String title, String link, String type})> entries;
  ExportGroup({required this.groupTitle, required this.entries});
}

class CalendarExportFile extends SettingsColours {
  final String title;
  final String fileType;
  final List<ExportGroup> entries;
  final Widget? customChild;
  const CalendarExportFile({
    super.key,
    required this.title,
    required this.fileType,
    required this.entries,
    this.customChild,
  });

  @override
  State<CalendarExportFile> createState() => _CalendarExportFileState();
}

class _CalendarExportFileState
    extends SettingsColoursState<CalendarExportFile> {
  ({String type, String link})? selected;

  void onChanged(({String type, String link})? value) {
    setState(() {
      selected = value!;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      title: Text(widget.title),
      backgroundColor: backgroundColor,
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: selected != null
            ? () async {
                showFileModal(
                  context,
                  DownloadableFile(
                    name:
                        "${DateTime.now().day}${DateTime.now().month}${DateTime.now().year}-${selected!.type}-${AppLocalizations.of(context).calendar.toLowerCase()}.${widget.fileType}",
                    url: Uri.parse(selected!.link),
                  ),
                );
              }
            : null,
        foregroundColor: selected == null
            ? Theme.of(context).colorScheme.onSurfaceVariant
            : null,
        backgroundColor: selected == null
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : null,
        child: Icon(Icons.download),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.customChild != null) ...[
                widget.customChild!,
                SizedBox(height: 24.0),
              ],
              for (var group in widget.entries) ...[
                Text(
                  group.groupTitle,
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                SizedBox(height: 8.0),
                for (var entry in group.entries) ...[
                  RadioListTile(
                    value: (type: entry.type, link: entry.link),
                    groupValue: selected,
                    onChanged: onChanged,
                    title: Text(entry.title),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
                SizedBox(height: 24.0),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
