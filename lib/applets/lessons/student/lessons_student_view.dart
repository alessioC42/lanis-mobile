import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/applets/lessons/definition.dart';
import 'package:lanis/widgets/combined_applet_builder.dart';
import 'package:liblanis/liblanis.dart';

import 'lesson_list_tile.dart';

class LessonsStudentView extends ConsumerStatefulWidget {
  final Function? openDrawerCb;
  const LessonsStudentView({super.key, this.openDrawerCb});

  @override
  ConsumerState<LessonsStudentView> createState() => _LessonsStudentViewState();
}

class _LessonsStudentViewState extends ConsumerState<LessonsStudentView>
    with TickerProviderStateMixin {
  Widget noDataScreen(context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.search, size: 60),
        Text(AppLocalizations.of(context).noCoursesFound),
      ],
    ),
  );

  Map<String, dynamic>? globalSettings;
  Future<void> Function(String, dynamic)? globalUpdateSetting;
  Lessons? homeworkLessons;

  @override
  Widget build(BuildContext context) {
    ref.listen(activeAccountIdProvider, (previous, next) {
      if (previous == next) return;
      globalSettings = null;
      globalUpdateSetting = null;
      homeworkLessons = null;
    });
    final session = ref.watch(sessionProvider).asData?.value;
    if (session == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(lessonsDefinition.label(context)),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(lessonsDefinition.label(context)),
        leading: widget.openDrawerCb != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => widget.openDrawerCb!(),
              )
            : null,
        actions:
            globalSettings != null &&
                globalUpdateSetting != null &&
                homeworkLessons != null &&
                homeworkLessons!.isNotEmpty
            ? [
                globalSettings!['showHomework'] == true
                    ? Tooltip(
                        message: AppLocalizations.of(context).lessons,
                        child: IconButton(
                          icon: const Icon(Icons.school_outlined),
                          onPressed: () {
                            globalUpdateSetting!('showHomework', false);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setState(() {});
                            });
                          },
                        ),
                      )
                    : Tooltip(
                        message: AppLocalizations.of(context).homework,
                        child: IconButton(
                          icon: const Icon(Icons.task_outlined),
                          onPressed: () {
                            globalUpdateSetting!('showHomework', true);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setState(() {});
                            });
                          },
                        ),
                      ),
              ]
            : null,
      ),
      body: CombinedAppletBuilder<Lessons>(
        parser: ref.watch(lessonsStudentParserProvider),
        phpUrl: lessonsDefinition.appletPhpUrl,
        settingsDefaults: lessonsDefinition.settingsDefaults,
        accountType:
            session.accountTypeOrNull ??
            ref.read(activeAccountProvider)?.accountType ??
            AccountType.student,
        builder:
            (context, lessons, accountType, settings, updateSetting, refresh) {
              Lessons? attendanceLessons;
              homeworkLessons = lessons
                  .where((element) => element.currentEntry?.homework != null)
                  .toList();

              if (globalUpdateSetting == null || globalSettings == null) {
                globalUpdateSetting = updateSetting;
                globalSettings = settings;
                if (settings['showHomework'] == true &&
                    homeworkLessons!.isEmpty) {
                  updateSetting('showHomework', false);
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() {});
                });
              }

              if (settings['showHomework'] == true) {
                lessons = homeworkLessons!;

                lessons.sort((a, b) {
                  if (a.currentEntry!.homework!.homeWorkDone ==
                      b.currentEntry?.homework?.homeWorkDone) {
                    if (a.currentEntry?.topicDate != null &&
                        b.currentEntry?.topicDate != null) {
                      return a.currentEntry!.topicDate!.compareTo(
                        b.currentEntry!.topicDate!,
                      );
                    } else {
                      return a.currentEntry?.topicDate == null ? 1 : -1;
                    }
                  }
                  return (a.currentEntry?.homework?.homeWorkDone ?? false)
                      ? 1
                      : -1;
                });
              } else {
                attendanceLessons = lessons
                    .where((element) => element.attendances != null)
                    .toList();
              }

              return Scaffold(
                body: RefreshIndicator(
                  onRefresh: () => refresh!(),
                  child: lessons.isNotEmpty
                      ? ListView.builder(
                          itemCount: lessons.length,
                          itemBuilder: (BuildContext context, int index) =>
                              Padding(
                                padding: EdgeInsets.only(
                                  top: 4,
                                  bottom: index == lessons.length - 1 ? 80 : 0,
                                  left: 8,
                                  right: 8,
                                ),
                                child: LessonListTile(
                                  lesson: lessons[index],
                                  accountType: accountType,
                                ),
                              ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [noDataScreen(context)],
                        ),
                ),
                floatingActionButton: Visibility(
                  visible:
                      attendanceLessons != null && attendanceLessons.isNotEmpty,
                  child: FloatingActionButton.extended(
                    heroTag: null,
                    onPressed: () {
                      context.push('/${accountType.name}/lessons/attendances');
                    },
                    label: Text(AppLocalizations.of(context).attendances),
                    icon: const Icon(Icons.access_alarm),
                  ),
                ),
              );
            },
      ),
    );
  }
}
