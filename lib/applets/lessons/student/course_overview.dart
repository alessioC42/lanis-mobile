import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:intl/intl.dart';
import 'package:lanis/bridge/login_telemetry.dart';
import 'package:lanis/generated/l10n.dart';

import '../../../utils/file_operations.dart' as fo;
import '../../../widgets/format_text.dart';
import 'homework_box.dart';

class CourseOverviewAnsicht extends ConsumerStatefulWidget {
  final String dataFetchURL;
  final String title;
  final int? initialTab;
  const CourseOverviewAnsicht({
    super.key,
    required this.dataFetchURL,
    required this.title,
    this.initialTab,
  });

  @override
  ConsumerState<CourseOverviewAnsicht> createState() =>
      _CourseOverviewAnsichtState();
}

class _CourseOverviewAnsichtState extends ConsumerState<CourseOverviewAnsicht> {
  static const double padding = 10.0;
  final dateFormat = DateFormat('dd.MM.yyyy');

  bool checked = false;

  late int _currentIndex = widget.initialTab ?? 0;
  bool loading = true;
  DetailedLesson? data;
  final _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String get _accountPrefix =>
      ref.read(activeAccountProvider)?.accountType?.name ?? 'student';

  Future<void> _openUpload(String url, String name, String status) async {
    final encoded = Uri.encodeComponent(url);
    final encodedName = Uri.encodeComponent(name);
    await context.push(
      '/$_accountPrefix/lessons/upload?url=$encoded&name=$encodedName&status=$status',
    );
  }

  void _openSemester1() {
    final courseId = data?.courseID;
    if (courseId == null) return;
    final title = Uri.encodeComponent(widget.title);
    context.push(
      '/$_accountPrefix/lessons/course/$courseId?title=$title&semester=1',
    );
  }

  Future<void> _loadData({bool secondTry = false, bool force = false}) async {
    try {
      if (secondTry) {
        await authenticateWithLoginTelemetry(
          ref.read(sessionProvider.notifier),
        );
      }

      String url = widget.dataFetchURL;
      data = await ref
          .read(lessonsStudentParserProvider)
          .getDetailedCourseView(url, force: force);

      if (!mounted) return;
      setState(() {
        loading = false;
      });
    } catch (e) {
      if (!secondTry) {
        await _loadData(secondTry: true);
        return;
      }
      if (!mounted) return;
      setState(() {
        loading = false;
      });
    }
  }

  Widget noDataScreen(BuildContext context) => Center(
    child: CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.search, size: 60),
              Text(AppLocalizations.of(context).noDataFound),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildBody() {
    if (data == null) {
      return noDataScreen(context);
    }

    switch (_currentIndex) {
      case 0: // historie
        return data!.history.isNotEmpty
            ? ListView.builder(
                itemCount: data!.semester1URL != null
                    ? data!.history.length + 1
                    : data!.history.length,
                itemBuilder: (context, index) {
                  //last item in list
                  if (index == data!.history.length) {
                    // Match history Card outer inset: list padding + Card margin (4).
                    return Padding(
                      padding: const EdgeInsets.only(
                        left: padding + 4,
                        right: padding + 4,
                        bottom: padding,
                      ),
                      child: ElevatedButton(
                        onPressed: _openSemester1,
                        child: Text(
                          AppLocalizations.of(context).toSemesterOne,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    );
                  }

                  List<GestureDetector> files = [];
                  for (FileInfo file in data!.history[index].files) {
                    final foFile = fo.DownloadableFile(
                      name: file.name,
                      size: file.size,
                      url: file.url,
                    );
                    files.add(
                      GestureDetector(
                        onLongPress: () {
                          fo.showFileModal(context, foFile);
                        },
                        child: ActionChip(
                          label: Text(file.name ?? "..."),
                          onPressed: () =>
                              fo.launchFile(context, foFile, () {}),
                        ),
                      ),
                    );
                  }

                  List<Widget> uploads = [];
                  for (var upload in data!.history[index].uploads) {
                    if (upload.status == "open") {
                      uploads.add(
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.inversePrimary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          height: 40,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FilledButton(
                                onPressed: () async {
                                  await _openUpload(
                                    upload.url.toString(),
                                    upload.name,
                                    'open',
                                  );
                                  setState(() {
                                    _loadData();
                                  });
                                },
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  children: [
                                    const Icon(Icons.upload, size: 20),
                                    Text(upload.name),
                                    if (upload.uploaded != null) ...[
                                      Badge(
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
                                        label: Text(
                                          upload.uploaded!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                              ),
                                        ),
                                        largeSize: 20,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 6.0,
                                  right: 12.0,
                                ),
                                child: Text(
                                  upload.date ?? "",
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    } else {
                      uploads.add(
                        OutlinedButton(
                          onPressed: () => _openUpload(
                            upload.url.toString(),
                            upload.name,
                            'closed',
                          ),
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              const Icon(Icons.file_upload_off, size: 18),
                              Text(upload.name),
                              if (upload.uploaded != null) ...[
                                Badge(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  label: Text(
                                    upload.uploaded!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                        ),
                                  ),
                                  largeSize: 20,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }
                  }

                  return Padding(
                    padding: EdgeInsets.only(
                      left: padding,
                      right: padding,
                      bottom: index == data!.history.length - 1 ? 14 : 8,
                    ),
                    child: Card(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Padding(
                                            padding: EdgeInsets.only(
                                              right: 4.0,
                                            ),
                                            child: Icon(
                                              Icons.calendar_today,
                                              size: 15,
                                            ),
                                          ),
                                          Text(
                                            AppLocalizations.of(
                                              context,
                                            ).dateWithHours(
                                              dateFormat.format(
                                                data!.history[index].topicDate!,
                                              ),
                                              data!
                                                      .history[index]
                                                      .schoolHours ??
                                                  "",
                                            ),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.labelSmall,
                                          ),
                                        ],
                                      ),
                                      Visibility(
                                        visible:
                                            data!.history[index].presence !=
                                            null,
                                        child: Row(
                                          children: [
                                            Text(
                                              (data!.history[index].presence ??
                                                      '')
                                                  .replaceAll(
                                                    "andere schulische Veranstaltung",
                                                    "a.s.V.",
                                                  ),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color:
                                                        data!
                                                                .history[index]
                                                                .presence ==
                                                            'fehlend'
                                                        ? Colors.red[300]
                                                        : null,
                                                  ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 4.0,
                                              ),
                                              child: Icon(
                                                Icons.meeting_room,
                                                color:
                                                    data!
                                                            .history[index]
                                                            .presence ==
                                                        'fehlend'
                                                    ? Colors.red[300]
                                                    : null,
                                                size: 15,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (data!.history[index].topicTitle !=
                                    null) ...[
                                  Text(
                                    data!.history[index].topicTitle!,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                ],
                                if (data!.history[index].description !=
                                    null) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 4,
                                      bottom: 4,
                                    ),
                                    child: FormattedText(
                                      text: data!.history[index].description!,
                                      formatStyle: DefaultFormatStyle(
                                        context: context,
                                      ),
                                    ),
                                  ),
                                ],
                                if (data!.history[index].homework != null)
                                  HomeworkBox(
                                    currentEntry: data!.history[index],
                                    courseID: data!.courseID,
                                  ),
                                Visibility(
                                  visible: files.isNotEmpty,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Wrap(spacing: 8, children: files),
                                  ),
                                ),
                                Visibility(
                                  visible: uploads.isNotEmpty,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Wrap(
                                      runSpacing: 8,
                                      spacing: 8,
                                      children: uploads,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              )
            : noDataScreen(context);
      case 1: // leistungen
        return data!.marks.isNotEmpty
            ? ListView.builder(
                itemCount: data!.marks.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      left: padding,
                      right: padding,
                      bottom: index == data!.marks.length - 1 ? 14 : 8,
                    ),
                    child: Card(
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(
                              data!.marks[index].name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            trailing: Text(
                              data!.marks[index].mark,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20.0,
                              ),
                            ),
                            subtitle: Text(
                              data!.marks[index].date,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          if (data!.marks[index].comment != null)
                            ListTile(
                              title: Text(
                                "${AppLocalizations.of(context).comment}: ",
                                style: Theme.of(context).textTheme.titleSmall,
                                textAlign: TextAlign.left,
                              ),
                              subtitle: Text(
                                data!.marks[index].comment ?? "",
                                style: TextStyle(
                                  fontSize: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium!.fontSize,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              )
            : noDataScreen(context);
      case 2: //Leistungskontrollen
        return data!.exams.isNotEmpty
            ? ListView.builder(
                itemCount: data!.exams.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      left: padding,
                      right: padding,
                      bottom: index == data!.exams.length - 1 ? 14 : 8,
                    ),
                    child: Card(
                      child: ListTile(
                        title: Text(
                          data!.exams[index].name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: Text(
                          data!.exams[index].value ?? '',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  );
                },
              )
            : noDataScreen(context);
      case 3:
        return data!.attendances.isNotEmpty
            ? ListView.builder(
                itemCount: data!.attendances.length,
                itemBuilder: (context, index) {
                  final String key = data!.attendances.keys.elementAt(index);
                  final String value = data!.attendances[key] ?? "";
                  return Padding(
                    padding: EdgeInsets.only(
                      left: padding,
                      right: padding,
                      bottom: index == data!.attendances.length - 1 ? 14 : 8,
                    ),
                    child: Card(
                      child: ListTile(
                        title: Text(toBeginningOfSentenceCase(key)),
                        trailing: Text(
                          value,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20.0,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              )
            : noDataScreen(context);
      default:
        return const Placeholder();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: () async => await _loadData(force: true),
        child: _buildBody(),
      ),
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (data?.semester1URL != null)
            IconButton(
              icon: const Icon(Icons.looks_one_outlined),
              onPressed: _openSemester1,
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.history),
            selectedIcon: const Icon(Icons.history_outlined),
            label: AppLocalizations.of(context).history,
          ),
          NavigationDestination(
            icon: const Icon(Icons.star),
            selectedIcon: const Icon(Icons.star_outline),
            label: AppLocalizations.of(context).performance,
          ),
          NavigationDestination(
            icon: const Icon(Icons.draw),
            selectedIcon: const Icon(Icons.draw_outlined),
            label: AppLocalizations.of(context).exams,
          ),
          NavigationDestination(
            icon: const Icon(Icons.list),
            selectedIcon: const Icon(Icons.list_outlined),
            label: AppLocalizations.of(context).attendances,
          ),
        ],
      ),
    );
  }
}
