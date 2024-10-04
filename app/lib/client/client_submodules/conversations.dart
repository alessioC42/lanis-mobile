import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart';

import '../../shared/apps.dart';
import '../../shared/exceptions/client_status_exceptions.dart';
import '../../shared/types/conversations.dart';
import '../client.dart';
import '../connection_checker.dart';
import '../cryptor.dart';
import '../logger.dart';

class ConversationsParser {
  late Dio dio;
  late SPHclient client;
  late OverviewFiltering filter;

  bool? cachedCanChooseType;

  ConversationsParser(Dio dioClient, this.client) {
    dio = dioClient;
    filter = OverviewFiltering();
  }

  /// Gets the entries which you can see in the overview.
  Future<List<OverviewEntry>> getOverview() async {
    if (!(client.doesSupportFeature(SPHAppEnum.nachrichten))) {
      throw NotSupportedException();
    }

    logger.i("Get new conversation data.");
    try {
      final response =
          await dio.post("https://start.schulportal.hessen.de/nachrichten.php",
              data: {
                "a": "headers",
                "getType": "All", // "unvisibleOnly", "visibleOnly" also possible
                "last": "0"
              },
              options: Options(
                headers: {
                  "Accept": "*/*",
                  "Content-Type":
                      "application/x-www-form-urlencoded; charset=UTF-8",
                  "Sec-Fetch-Dest": "empty",
                  "Sec-Fetch-Mode": "cors",
                  "Sec-Fetch-Site": "same-origin",
                  "X-Requested-With": "XMLHttpRequest",
                },
              ));

      final dynamic json = await compute(
          computeJson, [response.toString(), client.cryptor.key.bytes]);

      List<OverviewEntry> entries = [];
      for (final entry in json) {
        entries.add(OverviewEntry.fromJson(entry));
      }

      filter.entries = entries;

      return filter.filteredAndSearched(entries);
    } on (SocketException, DioException) {
      throw NetworkException();
    } on LanisException {
      rethrow;
    } catch (e) {
      throw UnknownException();
    }
  }

  // Move decrypting and decoding away from the main thread to avoid freezing.
  static dynamic computeJson(List<dynamic> args) {
    try {
      final Map<String, dynamic> encryptedJSON = jsonDecode(args[0]);

      final String? decryptedConversations = Cryptor.decryptWithKeyString(
          encryptedJSON["rows"], encrypt.Key(args[1]));

      if (decryptedConversations == null) {
        throw UnsaltedOrUnknownException();
      }

      return jsonDecode(decryptedConversations);
    } catch (e) {
      throw LanisException("Error computing the response from the SPH. This is most likely due to an teacher account we cannot support sufficiently.");
    }
  }

  /// Hides the conversation
  /// [id] is the **"Uniquid"** of the conversation.
  Future<bool> hideConversation(String id) async {
    if (!(await connectionChecker.connected)) {
      throw NoConnectionException();
    }

    try {
      final response = await dio.post(
          "https://start.schulportal.hessen.de/nachrichten.php",
          data: {"a": "deleteAll", "uniqid": id},
          options: Options(
            headers: {
              "Accept": "*/*",
              "Content-Type":
              "application/x-www-form-urlencoded; charset=UTF-8",
              "Sec-Fetch-Dest": "empty",
              "Sec-Fetch-Mode": "cors",
              "Sec-Fetch-Site": "same-origin",
              "X-Requested-With": "XMLHttpRequest",
            },
          )
      );

      return bool.parse(response.data);
    } on (SocketException, DioException) {
      throw NetworkException();
    } catch (e) {
      throw UnknownException();
    }
  }

  /// Shows a hidden conversation.
  /// [id] is the **"Uniquid"** of the conversation.
  Future<bool> showConversation(String id) async {
    if (!(await connectionChecker.connected)) {
      throw NoConnectionException();
    }

    try {
      final response = await dio.post(
          "https://start.schulportal.hessen.de/nachrichten.php",
          data: {"a": "recycleMsg", "uniqid": id},
          options: Options(
            headers: {
              "Accept": "*/*",
              "Content-Type":
              "application/x-www-form-urlencoded; charset=UTF-8",
              "Sec-Fetch-Dest": "empty",
              "Sec-Fetch-Mode": "cors",
              "Sec-Fetch-Site": "same-origin",
              "X-Requested-With": "XMLHttpRequest",
            },
          )
      );

      return bool.parse(response.data);
    } on (SocketException, DioException) {
      throw NetworkException();
    } catch (e) {
      throw UnknownException();
    }
  }

  // Sometimes usernames are the same as "SenderName", a HTML-Element.
  String fixUsername(String username) {
    if (!username.contains("fa-user")) {
      return username;
    }

    return parse(username).querySelector("span")!.text.trim();
  }

  /// Gets a whole single conversation with statistics.
  Future<Conversation> getSingleConversation(String uniqueID) async {
    if (!(await connectionChecker.connected)) {
      throw NoConnectionException();
    }

    try {
      final encryptedUniqueID = client.cryptor.encryptString(uniqueID);

      final response =
          await dio.post("https://start.schulportal.hessen.de/nachrichten.php",
              queryParameters: {"a": "read", "msg": uniqueID},
              data: {"a": "read", "uniqid": encryptedUniqueID},
              options: Options(
                headers: {
                  "Accept": "*/*",
                  "Content-Type":
                      "application/x-www-form-urlencoded; charset=UTF-8",
                  "Sec-Fetch-Dest": "empty",
                  "Sec-Fetch-Mode": "cors",
                  "Sec-Fetch-Site": "same-origin",
                  "X-Requested-With": "XMLHttpRequest",
                },
              ));

      final Map<String, dynamic> encryptedJSON =
          jsonDecode(response.toString());

      final String? decryptedConversations =
          client.cryptor.decryptString(encryptedJSON["message"]);

      if (decryptedConversations == null) {
        throw UnsaltedOrUnknownException();
      }

      final Map<String, dynamic> conversation = jsonDecode(decryptedConversations);

      final UnparsedMessage parent = UnparsedMessage(
          date: conversation["Datum"],
          author: fixUsername(conversation["username"]),
          own: conversation["own"],
          content: conversation["Inhalt"]);

      final List<UnparsedMessage> replies = [];
      for (dynamic reply in conversation["reply"]) {
        replies.add(UnparsedMessage(
            date: reply["Datum"],
            author: fixUsername(reply["username"]),
            own: reply["own"],
            content: reply["Inhalt"]));
      }

      int countStudents = conversation["statistik"]["teilnehmer"];
      int countTeachers = conversation["statistik"]["betreuer"];
      int countParents = conversation["statistik"]["eltern"];
      if (conversation["SenderArt"] == "Teilnehmer") {
        countStudents++;
      } else if (conversation["SenderArt"] == "Betreuer") {
        countTeachers++;
      } else {
        countParents++;
      }

      final Set<KnownParticipant> knownParticipants = {
        KnownParticipant(
            name: fixUsername(conversation["username"]),
            type: PersonType.fromJson(conversation["SenderArt"])
        )
      };

      for (Map reply in conversation["reply"]) {
        knownParticipants.add(
          KnownParticipant(
              name: fixUsername(reply["username"]),
              type: PersonType.fromJson(reply["SenderArt"])
          )
        );
      }

      if (conversation["empf"] is List) {
        for (String receiver in conversation["empf"]) {
          final String name = parse(receiver).querySelector("span")!.text.substring(1);
          knownParticipants.add(KnownParticipant(name: name, type: PersonType.other));
        }
      }

      if (conversation["WeitereEmpfaenger"] != "" && conversation["WeitereEmpfaenger"] != null) {
        final others =
            parse(conversation["WeitereEmpfaenger"]).querySelectorAll("span");
        for (final other in others) {
          knownParticipants.add(KnownParticipant(name: other.text.trim(), type: PersonType.group));
        }
      }

      return Conversation(
          groupChat: conversation["groupOnly"] == "ja",
          onlyPrivateAnswers: conversation["privateAnswerOnly"] == "ja",
          noReply: conversation["noAnswerAllowed"] == "ja",
          parent: parent,
          countStudents: countStudents,
          countTeachers: countTeachers,
          countParents: countParents,
          knownParticipants: knownParticipants.toList(),
          replies: replies);
    } on (SocketException, DioException) {
      throw NetworkException();
    } on LanisException {
      rethrow;
    } catch (e) {
      throw UnknownException();
    }
  }

  /// Replies to an already existing conversation.
  ///
  /// [headId] is the **"Uniquid"** of the head message.
  ///
  /// [groupOnly] and [privateAnswerOnly] are only checked for existence and then ignored.
  ///
  /// [sender] is the **"Sender"** of the head message, you can also use **"all"**.
  ///
  /// [message] supports Lanis-styled text.
  ///
  /// If successful, it returns `true`.
  Future<bool> replyToConversation(String headId, String sender,
      String groupOnly, String privateAnswerOnly, String message) async {
    try {
      final Map replyData = {
        "to": sender,
        "groupOnly": groupOnly,
        "privateAnswerOnly": privateAnswerOnly,
        "message": message,
        "replyToMsg": headId,
      };

      String encrypted = client.cryptor.encryptString(json.encode(replyData));

      final response =
      await dio.post("https://start.schulportal.hessen.de/nachrichten.php",
          data: {
            "a": "reply",
            "c": encrypted,
          },
          options: Options(
            headers: {
              "Accept": "*/*",
              "Content-Type":
              "application/x-www-form-urlencoded; charset=UTF-8",
              "Sec-Fetch-Dest": "empty",
              "Sec-Fetch-Mode": "cors",
              "Sec-Fetch-Site": "same-origin",
              "X-Requested-With": "XMLHttpRequest",
            },
          ));

      return json
          .decode(response.data)["back"]; // "back" should be bool, id is Uniquid
    } on (SocketException, DioException) {
      throw NetworkException();
    } on LanisException {
      rethrow;
    } catch (e) {
      throw UnknownException();
    }
  }

  /// Creates a new conversation.
  ///
  /// [receivers] are Strings of Ids which you can get with `Unimplemented`.
  /// Possible receivers are _(from the point of a student)_:
  ///   - Students from the same _Lerngruppe_.
  ///   - All teachers
  ///
  /// [type] is one of the following types:
  ///   - `noAnswerAllowed`
  ///     - **Hinweis**: No answers.
  ///   - `privateAnswerOnly`
  ///     - **Mitteilung**: Answers only to sender.
  ///   - `groupOnly`
  ///     - **Gruppenchat**: Answers to everyone.
  ///   - `openChat`
  ///     - **Offener Chat**: Private messages among themselves possible.
  ///
  ///  [text] also supports Lanis-styled text.
  ///
  ///  If successful, it returns true.
  Future<CreationResponse> createConversation(
      List<String> receivers, String? type, String subject, String text) async {
    try {
      final List<Map<String, String>> createData = [
        {"name": "subject", "value": subject},
        {"name": "text", "value": text},
      ];

      if (type != null) {
        createData.add({"name": "Art", "value": type});
      }

      for (final String receiver in receivers) {
        createData.add({"name": "to[]", "value": receiver});
      }

      String encrypted = client.cryptor.encryptString(json.encode(createData));

      final response =
      await dio.post("https://start.schulportal.hessen.de/nachrichten.php",
          data: {
            "a": "newmessage",
            "c": encrypted,
          },
          options: Options(
            headers: {
              "Accept": "*/*",
              "Content-Type":
              "application/x-www-form-urlencoded; charset=UTF-8",
              "Sec-Fetch-Dest": "empty",
              "Sec-Fetch-Mode": "cors",
              "Sec-Fetch-Site": "same-origin",
              "X-Requested-With": "XMLHttpRequest",
            },
          ));

      final Map decoded = json.decode(response.data);

      return CreationResponse(
          success: decoded["back"],
          id: decoded["id"]); // "back" should be bool, id is Uniquid
    } on (SocketException, DioException) {
      throw NetworkException();
    } on LanisException {
      rethrow;
    } catch (e) {
      throw UnknownException();
    }
  }

  Future<bool> canChooseType() async {
    if (cachedCanChooseType != null) {
      return cachedCanChooseType!;
    }

    if (!(await connectionChecker.connected)) {
      throw NoConnectionException();
    }

    try {
      final html =
      await dio.get("https://start.schulportal.hessen.de/nachrichten.php",
          options: Options(
            headers: {
              "Accept": "*/*",
              "Sec-Fetch-Dest": "document",
              "Sec-Fetch-Mode": "navigate",
              "Sec-Fetch-Site": "none",
            },
          ));

      final document = parse(html.data);

      cachedCanChooseType = document.querySelector("#MsgOptions") != null;

      return cachedCanChooseType!;
    } on (SocketException, DioException) {
      throw NetworkException();
    } catch (e) {
      throw UnknownException();
    }
  }

  /// Searches for teachers using at least 2 chars.
  ///
  /// Returns an empty list or a list of [ReceiverEntry].
  Future<List<ReceiverEntry>> searchTeacher(String name) async {
    if (name.length < 2 || !(await connectionChecker.connected)) {
      return [];
    }

    try {
      final response =
      await dio.get("https://start.schulportal.hessen.de/nachrichten.php",
          queryParameters: {"a": "searchRecipt", "q": name},
          options: Options(
            headers: {
              "Accept": "*/*",
              "Sec-Fetch-Dest": "document",
              "Sec-Fetch-Mode": "navigate",
              "Sec-Fetch-Site": "none",
            },
          ));

      /// total_count (don't need), incomplete_results (?, don't need),
      /// items => type: (lul, sus for students?, parents?, groups?),
      ///          id: (l-xxxx..., s-xxx.... for students?, parents?, groups?),
      ///          logo: (font awesome icons like: fa fa-user),
      ///          text: (name)
      ///       or empty
      final data = json.decode(response.data);

      if (data["items"] != null && data["items"].isNotEmpty) {
        final List<ReceiverEntry> teacherEntries = [];

        for (final teacher in data["items"]) {
          teacherEntries.add(ReceiverEntry.fromJson(teacher));
        }

        return teacherEntries;
      }

      return [];
    } on (SocketException, DioException) {
      throw NetworkException();
    } catch (e) {
      throw UnknownException();
    }
  }
}

/// Collection of filter functions for the search.
enum SearchFunction {
  subject,
  schedule, // can't use "date" bc of l10n
  name;

  static final functions = {
    SearchFunction.subject: (OverviewEntry entry, String search) =>
        entry.title.toLowerCase().contains(search.toLowerCase()),
    SearchFunction.name: (OverviewEntry entry, String search) =>
        (entry.shortName != null &&
            entry.shortName!.toLowerCase().contains(search.toLowerCase())) ||
        entry.fullName.toLowerCase().contains(search.toLowerCase()),
    SearchFunction.schedule: (OverviewEntry entry, String search) =>
        entry.date.toLowerCase().contains(search.toLowerCase()),
  };

  call(OverviewEntry entry, String search) {
    return functions[this]!(entry, search);
  }
}

/// A useful class to directly modify the most recent downloaded overview stream,
/// so it's fast.
class OverviewFiltering {
  /// Cached overview entries set by a [getOverview] call.
  List<OverviewEntry> entries = [];

  /// Skip current options when in toggle mode.
  bool toggleMode = false;

  bool showHidden = false;
  String simpleSearch = "";

  final advancedSearch = {
    SearchFunction.subject: "",
    SearchFunction.name: "",
    SearchFunction.schedule: "",
  };

  OverviewFiltering();

  void supply() {
    client.fetchers.conversationsFetcher.supply(filteredAndSearched(entries));
  }
  
  void toggleEntry(String id, {bool? hidden, bool? unread}) {
    final index = entries.indexWhere((entry) => entry.id == id);
    entries.replaceRange(index, index + 1, [entries[index].copyWith(
        hidden: hidden == null || hidden == false ? null : !entries[index].hidden,
        unread: unread == null || unread == false ? null : !entries[index].unread,
    )]);
  }

  List<OverviewEntry> filteredAndSearched(List<OverviewEntry> entries) {
    return searched(filtered(entries));
  }

  /// Show all conversations or just non-hidden ones.
  List<OverviewEntry> filtered(List<OverviewEntry> entries) {
    if (showHidden || toggleMode) {
      return entries;
    }

    return entries.where((entry) => entry.hidden == false).toList();
  }

  List<OverviewEntry> advancedSearched(List<OverviewEntry> entries, SearchFunction function) {
    return entries.where((entry) => function.call(entry, advancedSearch[function]!)).toList();
  }

  List<OverviewEntry> searched(List<OverviewEntry> entries) {
    List<OverviewEntry> newEntries = [];

    // Basic search which often is enough.
    for (int i = 0; i < entries.length; i++) {
      bool add = false;
      for (final function in SearchFunction.values) {
        if (function.call(entries[i], simpleSearch)) {
          add = true;
          break;
        }
      }

      if (add) {
        newEntries.add(entries[i]);
      }
    }

    // Search with the expanded precision search.
    for (final function in advancedSearch.keys) {
      newEntries = advancedSearched(newEntries, function);
    }

    return newEntries;
  }
}