import 'dart:async';
import 'dart:convert';
import 'package:rxdart/rxdart.dart';
import 'package:sph_plan/client/client_submodules/substitutions.dart';
import 'package:sph_plan/client/storage.dart';
import 'package:sph_plan/shared/apps.dart';
import 'package:sph_plan/shared/exceptions/client_status_exceptions.dart';

import '../shared/types/lesson.dart';
import '../shared/types/timetable.dart';
import '../shared/types/calendar_event.dart';
import 'client.dart';
import 'connection_checker.dart';

enum FetcherStatus {
  fetching,
  done,
  error;
}

class FetcherResponse<T> {
  late final FetcherStatus status;
  late final T? content;
  late final LanisException? error;

  FetcherResponse({required this.status, this.content, this.error});
}

abstract class Fetcher<T> {
  final BehaviorSubject<FetcherResponse<T>> _controller = BehaviorSubject();
  late Timer timer;
  late Duration? validCacheDuration;
  bool isEmpty = true;
  StorageKey? storageKey;

  ValueStream<FetcherResponse<T>> get stream => _controller.stream;

  Fetcher(this.validCacheDuration, {this.storageKey}) {
    if (validCacheDuration != null) {
      Timer.periodic(validCacheDuration!, (timer) async {
        if (await connectionChecker.connected) {
          await fetchData(forceRefresh: true);
        }
      });
    }
  }

  void _addResponse(final FetcherResponse<T> data) =>
      _controller.sink.add(data);

  Future<void> fetchData({forceRefresh = false, secondTry = false}) async {
    if (!(await connectionChecker.connected)) {
      if (isEmpty) {
        _addResponse(FetcherResponse(
            status: FetcherStatus.error, error: NoConnectionException()));
      }

      return;
    }

    if (isEmpty || forceRefresh) {
      _addResponse(FetcherResponse(status: FetcherStatus.fetching));

      _get().then((data) async {
        _addResponse(
            FetcherResponse<T>(status: FetcherStatus.done, content: data));
        isEmpty = false;
        if (storageKey == null) return;
        globalStorage.write(key: storageKey!, value: jsonEncode(data));
        return;
      }).catchError((ex) async {
        if (!secondTry) {
          await client.login();
          await fetchData(forceRefresh: true, secondTry: true);
          return;
        }
        _addResponse(
            FetcherResponse<T>(status: FetcherStatus.error, error: ex));
      }, test: (e) => e is LanisException);
    }
  }

  Future<T> _get();
}

class SubstitutionsFetcher extends Fetcher<SubstitutionPlan> {
  SubstitutionsFetcher(super.validCacheDuration, {super.storageKey});
  @override
  Future<SubstitutionPlan> _get() async {
    return await client.substitutions.getAllSubstitutions(filtered: true);
  }
}

class MeinUnterrichtFetcher extends Fetcher<Lessons> {
  MeinUnterrichtFetcher(super.validCacheDuration, {super.storageKey});

  @override
  Future<Lessons> _get() {
    return client.meinUnterricht.getOverview();
  }
}

class VisibleConversationsFetcher extends Fetcher<dynamic> {
  VisibleConversationsFetcher(super.validCacheDuration, {super.storageKey});

  @override
  Future<dynamic> _get() {
    return client.conversations.getOverview(false);
  }
}

class InvisibleConversationsFetcher extends Fetcher<dynamic> {
  InvisibleConversationsFetcher(super.validCacheDuration, {super.storageKey});

  @override
  Future<dynamic> _get() {
    return client.conversations.getOverview(true);
  }
}

class CalendarFetcher extends Fetcher<List<CalendarEvent>> {
  CalendarFetcher(super.validCacheDuration, {super.storageKey});
  String searchQuery = "";

  @override
  Future<List<CalendarEvent>> _get() {
    DateTime currentDate = DateTime.now();
    DateTime sixMonthsAgo = currentDate.subtract(const Duration(days: 180));
    DateTime oneYearLater = currentDate.add(const Duration(days: 365));

    return client.calendar
        .getCalendar(startDate: sixMonthsAgo, endDate: oneYearLater, searchQuery: searchQuery);
  }
}

class TimeTableFetcher extends Fetcher<TimeTable?> {
  TimeTableFetcher(super.validCacheDuration, {super.storageKey});

  @override
  Future<TimeTable?> _get() {
    return client.timetable.getPlan();
  }
}

class GlobalFetcher {
  late final SubstitutionsFetcher substitutionsFetcher;
  late final MeinUnterrichtFetcher meinUnterrichtFetcher;
  late final VisibleConversationsFetcher visibleConversationsFetcher;
  late final InvisibleConversationsFetcher invisibleConversationsFetcher;
  late final CalendarFetcher calendarFetcher;
  late final TimeTableFetcher timeTableFetcher;

  GlobalFetcher() {
    if (client.doesSupportFeature(SPHAppEnum.vertretungsplan)) {
      substitutionsFetcher = SubstitutionsFetcher(const Duration(minutes: 5),
          storageKey: StorageKey.lastSubstitutionData);
    }
    if (client.doesSupportFeature(SPHAppEnum.meinUnterricht)) {
      meinUnterrichtFetcher =
          MeinUnterrichtFetcher(const Duration(minutes: 20));
    }
    if (client.doesSupportFeature(SPHAppEnum.nachrichten)) {
      visibleConversationsFetcher =
          VisibleConversationsFetcher(const Duration(minutes: 5));
      invisibleConversationsFetcher =
          InvisibleConversationsFetcher(const Duration(minutes: 5));
    }
    if (client.doesSupportFeature(SPHAppEnum.kalender)) {
      calendarFetcher = CalendarFetcher(null);
    }
    if (client.doesSupportFeature(SPHAppEnum.stundenplan)) {
      timeTableFetcher =
          TimeTableFetcher(null, storageKey: StorageKey.lastTimetableData);
    }
  }
}
