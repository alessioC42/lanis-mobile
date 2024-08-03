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
  bool? canChooseTypeCached;

  ConversationsParser(Dio dioClient, this.client) {
    dio = dioClient;
  }

  Future<dynamic> getOverview(bool invisible) async {
    if (!(client.doesSupportFeature(SPHAppEnum.nachrichten))) {
      throw NotSupportedException();
    }

    logger.i("Get new conversation data. Invisible: $invisible.");
    try {
      final response =
          await dio.post("https://start.schulportal.hessen.de/nachrichten.php",
              data: {
                "a": "headers",
                "getType": invisible ? "unvisibleOnly" : "visibleOnly",
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

      return compute(
          computeJson, [response.toString(), client.cryptor.key.bytes]);
    } on (SocketException, DioException) {
      throw NetworkException();
    } on LanisException {
      rethrow;
    } catch (e) {
      throw UnknownException();
    }
  }

  static dynamic computeJson(List<dynamic> args) {
    final Map<String, dynamic> encryptedJSON = jsonDecode(args[0]);

    final String? decryptedConversations = Cryptor.decryptWithKeyString(
        encryptedJSON["rows"], encrypt.Key(args[1]));

    if (decryptedConversations == null) {
      throw UnsaltedOrUnknownException();
    }

    return jsonDecode(decryptedConversations);
  }

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
          author: conversation["username"],
          own: conversation["own"],
          content: conversation["Inhalt"]);

      final List<UnparsedMessage> replies = [];
      for (dynamic reply in conversation["reply"]) {
        replies.add(UnparsedMessage(
            date: reply["Datum"],
            author: reply["username"],
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
            name: conversation["username"],
            type: PersonType.fromJson(conversation["SenderArt"])
        )
      };

      for (Map reply in conversation["reply"]) {
        knownParticipants.add(
          KnownParticipant(
              name: reply["username"],
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

      if (conversation["WeitereEmpfaenger"] != "") {
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
    if (canChooseTypeCached != null) {
      return canChooseTypeCached!;
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

      canChooseTypeCached = document.querySelector("#MsgOptions") != null;

      return canChooseTypeCached!;
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
