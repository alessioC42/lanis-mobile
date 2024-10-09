import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import '../../shared/types/calendar_event.dart';

import 'package:dio/dio.dart';
import 'package:sph_plan/client/client.dart';

import '../../shared/apps.dart';
import '../../shared/exceptions/client_status_exceptions.dart';
import '../connection_checker.dart';

class CalendarParser {
  late Dio dio;
  late SPHclient client;

  CalendarParser(Dio dioClient, this.client) {
    dio = dioClient;
  }

  Future<List<CalendarEvent>> getCalendar(
      {required DateTime startDate,
      required DateTime endDate,
      String searchQuery = ''}) async {
    if (!client.doesSupportFeature(SPHAppEnum.kalender)) {
      throw NotSupportedException();
    }

    final formatter = DateFormat('yyyy-MM-dd');

    try {
      final response =
          await dio.post("https://start.schulportal.hessen.de/kalender.php",
              queryParameters: {
                "f": "getEvents",
                "s": searchQuery,
                "start": formatter.format(startDate),
                "end": formatter.format(endDate),
              },
              data: 'f=getEvents&start=$startDate&end=$endDate&s=$searchQuery',
              options: Options(
                headers: {
                  "Accept": "*/*",
                  "Content-Type":
                      "application/x-www-form-urlencoded; charset=UTF-8",
                  "Sec-Fetch-Dest": "empty",
                  "Sec-Fetch-Mode": "cors",
                  "Sec-Fetch-Site": "same-origin",
                },
              ));
      final data = jsonDecode(response.data);
      List<CalendarEvent> finalData = [];
      for (int i = 0; i < (data as List<dynamic>).length; i++) {
        finalData.add(CalendarEvent.fromLanisJson(data[i]));
      }

      return finalData;
    } on SocketException {
      throw NetworkException();
    } catch (e) {
      throw UnknownException();
    }
  }

  Future<Map<String, dynamic>?> getEvent(String id) async {
    if (!(await connectionChecker.connected)) {
      throw NoConnectionException();
    }

    try {
      final response =
          await dio.post("https://start.schulportal.hessen.de/kalender.php",
              data: {
                "f": "getEvent",
                "id": id,
              },
              options: Options(
                headers: {
                  "Accept": "*/*",
                  "Content-Type":
                      "application/x-www-form-urlencoded; charset=UTF-8",
                  "Sec-Fetch-Dest": "empty",
                  "Sec-Fetch-Mode": "cors",
                  "Sec-Fetch-Site": "same-origin",
                },
              ));
      final data = jsonDecode(response.toString());
      if (data['id'] == '' || data['id'] == null) return null;

      return data;
    } on SocketException {
      throw NetworkException();
    } catch (e) {
      throw UnknownException();
    }
  }
}
