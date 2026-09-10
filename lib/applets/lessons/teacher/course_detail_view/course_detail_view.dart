import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';

import '../widgets/course_folder_history_entry_card.dart';

import 'package:lanis/generated/l10n.dart';

import 'course_create_new_entry.dart';
import 'package:lanis/utils/root_nav.dart';

class TeacherCourseDetailView extends ConsumerStatefulWidget {
  final CourseFolderStartPage courseFolder;
  const TeacherCourseDetailView({super.key, required this.courseFolder});

  @override
  ConsumerState<TeacherCourseDetailView> createState() =>
      _TeacherCourseDetailViewState();
}

class _TeacherCourseDetailViewState
    extends ConsumerState<TeacherCourseDetailView> {
  bool _loading = true;
  bool _error = false;
  CourseFolderDetails? data;

  Future<void> loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final details = await ref
          .read(lessonsTeacherParserProvider)
          .getCourseFolderDetails(widget.courseFolder.id);
      if (!mounted) return;
      setState(() {
        data = details;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  Widget build(BuildContext context) {
    final details = data;
    return Scaffold(
      appBar: AppBar(title: Text(widget.courseFolder.name)),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _error || details == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  Icon(Icons.error_outline, size: 48),
                  Text(
                    AppLocalizations.of(context).error,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton(
                    onPressed: loadData,
                    child: Text(AppLocalizations.of(context).tryAgain),
                  ),
                ],
              ),
            )
          : details.history.isNotEmpty
          ? RefreshIndicator(
              onRefresh: loadData,
              child: ListView.builder(
                itemCount: details.history.length,
                itemBuilder: (context, index) => Padding(
                  padding: EdgeInsets.only(
                    left: 4,
                    right: 4,
                    bottom: index == details.history.length - 1 ? 80 : 0,
                  ),
                  child: CourseFolderHistoryEntryCard(
                    entry: details.history[index],
                    courseId: widget.courseFolder.id,
                    afterDeleted: () async {
                      await loadData();
                    },
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: loadData,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: [
                    SizedBox(height: 64),
                    Icon(Icons.info, size: 48),
                    Text(
                      AppLocalizations.of(context).noEntries,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: _loading || _error || details == null
          ? null
          : FloatingActionButton.extended(
              heroTag: null,
              label: Text(AppLocalizations.of(context).newEntry),
              icon: Icon(Icons.add),
              onPressed: () async {
                final result = await pushInShell<bool?>(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CourseCreateNewEntry(courseFolderDetails: details),
                  ),
                );
                if (context.mounted) {
                  if (result == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context).entryCreated,
                        ),
                      ),
                    );
                    await loadData();
                  } else if (result == false) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context).entryCreateFailed,
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
    );
  }
}
