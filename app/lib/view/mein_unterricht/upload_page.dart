import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart'; // needed for MimeType declarations
import 'package:open_file/open_file.dart';
import 'package:sph_plan/shared/widgets/error_view.dart';

import '../../client/client.dart';
import '../../shared/exceptions/client_status_exceptions.dart';
import '../../shared/types/upload.dart';

class UploadScreen extends StatefulWidget {
  final String url;
  final String name;
  final String status;
  const UploadScreen(
      {super.key, required this.url, required this.name, required this.status});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  late Future _future;
  final ValueNotifier<int> _addedFiles =
      ValueNotifier(0); // Could also use a stream

  final List<MultipartFile> _multipartFiles = [];
  final List<ListTile> _fileWidgets = [];

  void forceReloadPage() {
    setState(() {
      _future = client.meinUnterricht.getUploadInfo(widget.url);
    });
  }

  @override
  void initState() {
    _future = client.meinUnterricht.getUploadInfo(widget.url);
    super.initState();
  }

  @override
  void dispose() {
    _addedFiles.dispose();
    super.dispose();
  }

  void showSnackbar({required String text, SnackBarAction? action}) {
    if (mounted) {
      // Hide the current SnackBar if one is already visible.
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(text),
            duration: const Duration(seconds: 6),
            action: action),
      );
    }
  }

  static const Divider indentedDivider = Divider(
    indent: 16,
    endIndent: 16,
  );

  Container uploadStatusContainer(String text) => Container(
        padding: const EdgeInsets.all(12.0),
        margin:
            const EdgeInsets.only(left: 16, right: 16, top: 4.0, bottom: 4.0),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12)),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge,
        ),
      );

  Container requirementsInfo(List<Widget> widgets, {Color? color}) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4.0),
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        decoration: BoxDecoration(
            color:
                color ?? Theme.of(context).colorScheme.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [...widgets],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasError && snapshot.error is LanisException) {
              return Scaffold(
                appBar: AppBar(
                  title: Text(widget.name),
                ),
                body: ErrorView(
                    error: snapshot.error as LanisException,
                    name: "einer Abgabe",
                ),
              );
            }

            final DateTime startDate = DateFormat("EEEE d.M.yy H:mm", "de")
                .parse(snapshot.data["start"]
                    .replaceAll(",", "")
                    .replaceAll(" den", "")
                    .replaceAll(" Uhr", ""));
            final DateTime now = DateTime.now();

            final DateTime deleteDate = DateFormat("d.M.yyyy", "de")
                .parse(snapshot.data["automatic_deletion"]);
            final bool filesDeleted =
                now.isAfter(deleteDate) || now.isAtSameMomentAs(deleteDate);

            final bool isBeforeStart = now.isBefore(startDate);

            return Scaffold(
              appBar: AppBar(
                title: Text(widget.name),
              ),
              floatingActionButton: ValueListenableBuilder(
                  valueListenable: _addedFiles,
                  builder: (_, filesLength, __) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (filesLength != 0) ...[
                          Column(
                            children: [
                              FloatingActionButton(
                                heroTag: null,
                                onPressed: () async {
                                  if (snapshot.data["upload_multiple_files"] ==
                                          false ||
                                      snapshot.data[
                                              "upload_any_number_of_times"] ==
                                          false) {
                                    showDialog(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          title: const Text(
                                              "Hochladen nicht möglich!"),
                                          content: const Text(
                                              "Bei dieser Abgabe ist das Hochladen mehrerer Dateien oder beliebig häufiger Dateien nicht möglich und da wir dafür noch keine Unterstützung anbieten, kannst du gerade per App noch nichts hochladen."),
                                          actions: [
                                            FilledButton(
                                              onPressed: () =>
                                                  Navigator.of(context).pop(),
                                              child: const Text("Zurück"),
                                            )
                                          ],
                                        );
                                      },
                                    );
                                    return;
                                  }

                                  showSnackbar(
                                      text:
                                          "Versuche die Datei(en) hochzuladen...");

                                  List<FileStatus> fileStatus;

                                  try {
                                    fileStatus =
                                        await client.meinUnterricht.uploadFile(
                                      course: snapshot.data["course_id"],
                                      entry: snapshot.data["entry_id"],
                                      upload: snapshot.data["upload_id"],
                                      file1: _multipartFiles[0],
                                      file2: _multipartFiles.elementAtOrNull(1),
                                      file3: _multipartFiles.elementAtOrNull(2),
                                      file4: _multipartFiles.elementAtOrNull(3),
                                      file5: _multipartFiles.elementAtOrNull(4),
                                    );
                                  } on LanisException catch (ex) {
                                    ScaffoldMessenger.of(context)
                                        .hideCurrentSnackBar();
                                    Navigator.of(context).push(
                                        MaterialPageRoute(builder: (context) {
                                      return Scaffold(
                                        appBar: AppBar(),
                                        body: ErrorView(
                                            error: ex,
                                            name:
                                                "Hochladen von einer Datei/Dateien",
                                            ),
                                      );
                                    }));
                                    return;
                                  }

                                  int successfulUploads = 0;
                                  bool renamed = false;
                                  for (final status in fileStatus) {
                                    if (status.status == "erfolgreich") {
                                      successfulUploads++;
                                      if (status.message!.contains(
                                          "Datei mit gleichem Namen schon vorhanden.")) {
                                        renamed = true;
                                      }
                                    }
                                  }

                                  showSnackbar(
                                      text:
                                          "$successfulUploads/${fileStatus.length} wurden erfolgreich hochgeladen. ${renamed == true ? 'Manche Dateien wurden jedoch umbenannt.' : ''}",
                                      action: SnackBarAction(
                                          label: "Mehr sehen",
                                          onPressed: () {
                                            // We render the Widgets before so we can have a dynamically sized AlertDialog.
                                            final List<ListTile>
                                                fileStatusWidgets = [];

                                            for (final status in fileStatus) {
                                              fileStatusWidgets.add(ListTile(
                                                leading: status.status ==
                                                        "erfolgreich"
                                                    ? const Icon(Icons.done)
                                                    : const Icon(Icons.error),
                                                title: Text(status.name),
                                                subtitle:
                                                    status.message != null &&
                                                            status.message != ""
                                                        ? Text(status.message!)
                                                        : null,
                                              ));
                                            }

                                            showDialog(
                                                context: context,
                                                builder: (context) {
                                                  return AlertDialog(
                                                    title: const Text(
                                                        "Mehr Details"),
                                                    content: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        ...fileStatusWidgets
                                                      ],
                                                    ),
                                                    actions: [
                                                      FilledButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                      context)
                                                                  .pop(),
                                                          child: const Text(
                                                              "Zurück"))
                                                    ],
                                                  );
                                                });
                                          }));

                                  _addedFiles.value = 0;
                                  _multipartFiles.clear();
                                  _fileWidgets.clear();

                                  forceReloadPage();
                                },
                                child: const Icon(Icons.upload),
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                            ],
                          ),
                        ],
                        if (filesLength < 5 &&
                            snapshot.data["course_id"] != null) ...[
                          FloatingActionButton.extended(
                            heroTag: null,
                            label: Text(
                              "$filesLength / 5",
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            icon: const Icon(Icons.add),
                            onPressed: () async {
                              FilePickerResult? file =
                                  await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions:
                                    snapshot.data["allowed_file_types"],
                              );

                              final PlatformFile firstFile = file!.files.first;

                              if (!snapshot.data["allowed_file_types"].contains(
                                  firstFile.extension?.toUpperCase())) {
                                showSnackbar(
                                    text:
                                        "Die Datei hat keinen erlaubten Dateityp!");
                                return;
                              }

                              num maxFileSize = num.parse(snapshot
                                      .data["max_file_size"]
                                      .replaceAll("MB", "")
                                      .replaceAll(",", ".")) *
                                  1000000;

                              if (firstFile.size > maxFileSize) {
                                showSnackbar(
                                    text:
                                        "Die Datei hat die maximale Dateigröße überschritten!");
                                return;
                              }

                              // Only check for filename like Lanis.
                              for (final element in _multipartFiles) {
                                if (element.filename == firstFile.name) {
                                  showSnackbar(
                                      text:
                                          "Der Name der Datei gibt es schon!");
                                  return;
                                }
                              }

                              // firstFile.extension only returns characters after the dot of the file name, not the MimeType
                              final String? mimeType =
                                  lookupMimeType(firstFile.path!);

                              if (mimeType == null) {
                                showSnackbar(
                                    text:
                                        "Beim Herausfinden des Dateityps ist ein Fehler entstanden!");
                                return;
                              }

                              // MultipartFile doesn't accept a String, only MediaType
                              final MediaType parsedMimeType =
                                  MediaType.parse(mimeType);

                              final MultipartFile multipartFile =
                                  await MultipartFile.fromFile(firstFile.path!,
                                      filename: firstFile.name,
                                      contentType: parsedMimeType);

                              _multipartFiles.add(multipartFile);
                              _fileWidgets.add(ListTile(
                                title: Text(firstFile.name),
                                trailing: const Icon(Icons.remove),
                                onTap: () {
                                  // We need to calculate the index dynamically because you can remove every tile at any index.
                                  // Maybe there is a better way.
                                  int tileIndex = _fileWidgets
                                      .indexWhere((ListTile element) {
                                    final Text textWidget =
                                        element.title as Text;
                                    final String text = textWidget.data!;

                                    return text == firstFile.name;
                                  });
                                  _fileWidgets.removeAt(tileIndex);
                                  _multipartFiles.removeAt(tileIndex);
                                  _addedFiles.value -= 1;
                                },
                              ));
                              _addedFiles.value += 1;
                            },
                          ),
                        ]
                      ],
                    );
                  }),
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    requirementsInfo([
                      ListTile(
                        title: const Text(
                          "Start",
                        ),
                        subtitle: Text(snapshot.data["start"]),
                        leading: const Icon(Icons.hourglass_top),
                      ),
                      ListTile(
                        title: const Text(
                          "Ende",
                        ),
                        subtitle: Text(snapshot.data["deadline"]),
                        leading: const Icon(Icons.hourglass_bottom),
                      ),
                    ]),
                    Visibility(
                      visible:
                          isBeforeStart || snapshot.data["course_id"] != null,
                      child: requirementsInfo([
                        ListTile(
                          title: const Text(
                            "Hochladen mehrerer Dateien",
                          ),
                          subtitle: Text(
                            snapshot.data["upload_multiple_files"]
                                ? 'Möglich'
                                : 'Nicht möglich',
                          ),
                          leading: snapshot.data["upload_multiple_files"]
                              ? const Icon(Icons.file_upload)
                              : const Icon(Icons.file_upload_off),
                        ),
                        ListTile(
                          title: const Text(
                            "Beliebig häufig hochladen",
                          ),
                          subtitle: Text(
                              snapshot.data["upload_any_number_of_times"]
                                  ? 'Möglich'
                                  : 'Nicht möglich'),
                          leading: snapshot.data["upload_any_number_of_times"]
                              ? const Icon(Icons.file_upload)
                              : const Icon(Icons.file_upload_off),
                        ),
                      ]),
                    ),
                    Visibility(
                      visible:
                          isBeforeStart || snapshot.data["course_id"] != null,
                      child: requirementsInfo([
                        ListTile(
                          title: Text(
                            "Dateien sichtbar für ${snapshot.data["visibility"]}",
                          ),
                          leading: const Icon(Icons.visibility),
                        ),
                        ListTile(
                          title: const Text(
                            "Automatische Löschung",
                          ),
                          subtitle: Text(snapshot.data["automatic_deletion"]),
                          leading: const Icon(Icons.delete_forever),
                        ),
                      ]),
                    ),
                    Visibility(
                      visible:
                          !isBeforeStart && snapshot.data["course_id"] == null,
                      child: requirementsInfo(
                        [
                          ListTile(
                            title: filesDeleted
                                ? const Text("Dateien wurden gelöscht!")
                                : const Text(
                                    "Automatische Löschung",
                                  ),
                            subtitle: filesDeleted
                                ? null
                                : Text(snapshot.data["automatic_deletion"]),
                            leading: const Icon(Icons.delete_forever),
                          ),
                        ],
                        color: filesDeleted ? Colors.redAccent : null,
                      ),
                    ),
                    Visibility(
                      visible:
                          isBeforeStart || snapshot.data["course_id"] != null,
                      child: requirementsInfo([
                        ListTile(
                          title: const Text(
                            "Erlaubte Dateitypen",
                          ),
                          subtitle: Text(snapshot.data["allowed_file_types"]
                              .toString()
                              .substring(
                                  1,
                                  snapshot.data["allowed_file_types"]
                                          .toString()
                                          .length -
                                      1)),
                          leading: const Icon(Icons.description),
                        ),
                        ListTile(
                          title: const Text(
                            "Maximale Dateigröße",
                          ),
                          subtitle: Text(snapshot.data["max_file_size"]),
                          leading: const Icon(Icons.description),
                        ),
                      ]),
                    ),
                    Visibility(
                      visible: snapshot.data["additional_text"] != null,
                      child: requirementsInfo([
                        if (snapshot.data["additional_text"] != null) ...[
                          ListTile(
                            title: const Text(
                              "Zusätzliche Informationen",
                            ),
                            subtitle:
                                Text(snapshot.data["additional_text"] ?? ""),
                            leading: const Icon(Icons.info),
                          ),
                        ]
                      ]),
                    ),
                    if (snapshot.data["public_files"].length != 0) ...[
                      indentedDivider
                    ],
                    ListView.builder(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        itemCount: snapshot.data["public_files"].length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(
                              snapshot.data["public_files"][index].name,
                              style: !filesDeleted
                                  ? Theme.of(context).textTheme.titleMedium
                                  : Theme.of(context).textTheme.bodyLarge,
                            ),
                            subtitle: Text(
                              snapshot.data["public_files"][index].person,
                              style: !filesDeleted
                                  ? Theme.of(context).textTheme.bodyMedium
                                  : null,
                            ),
                            onTap: !filesDeleted
                                ? () async {
                                    showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (BuildContext context) {
                                          return const AlertDialog(
                                            title: Text("Download..."),
                                            content: Center(
                                              heightFactor: 1.1,
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          );
                                        });
                                    client
                                        .downloadFile(
                                            snapshot.data["public_files"][index]
                                                .url,
                                            snapshot.data["public_files"][index]
                                                .name)
                                        .then((filepath) {
                                      Navigator.of(context).pop();

                                      if (filepath == "") {
                                        showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                                  title: const Text("Fehler!"),
                                                  content: Text(
                                                      "Beim Download der Datei ${snapshot.data["public_files"][index].name} ist ein unerwarteter Fehler aufgetreten. Wenn dieses Problem besteht, senden Sie uns bitte einen Fehlerbericht."),
                                                  actions: [
                                                    TextButton(
                                                      child: const Text('OK'),
                                                      onPressed: () {
                                                        Navigator.of(context)
                                                            .pop();
                                                      },
                                                    ),
                                                  ],
                                                ));
                                      } else {
                                        OpenFile.open(filepath);
                                      }
                                    });
                                  }
                                : null,
                          );
                        }),
                    indentedDivider,
                    if (snapshot.data["own_files"].length == 0) ...[
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        margin: const EdgeInsets.only(
                            left: 16, right: 16, top: 4.0, bottom: 4.0),
                        decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondary
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          "Du hast nichts abgegeben!",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    ],
                    ListView.builder(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        itemCount: snapshot.data["own_files"].length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(
                              snapshot.data["own_files"][index].name,
                              style: !filesDeleted
                                  ? Theme.of(context).textTheme.titleMedium
                                  : Theme.of(context).textTheme.bodyLarge,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  snapshot.data["own_files"][index].time,
                                  style: !filesDeleted
                                      ? Theme.of(context).textTheme.bodyMedium
                                      : null,
                                ),
                                if (snapshot.data["own_files"][index].comment !=
                                    null)
                                  Text(
                                      snapshot.data["own_files"][index].comment)
                              ],
                            ),
                            trailing: !filesDeleted
                                ? IconButton(
                                    onPressed: () async {
                                      final TextEditingController
                                          passwordController =
                                          TextEditingController();
                                      showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              title: const Text(
                                                  "Bestätige mit deinen Passwort"),
                                              content: TextField(
                                                obscureText: true,
                                                enableSuggestions: false,
                                                autocorrect: false,
                                                controller: passwordController,
                                              ),
                                              actions: [
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child:
                                                        const Text("Zurück")),
                                                FilledButton(
                                                  onPressed: () async {
                                                    Navigator.pop(context);

                                                    showSnackbar(
                                                        text:
                                                            "Versuche die Datei(en) zu löschen...");
                                                    String response;
                                                    try {
                                                      response = await client
                                                          .meinUnterricht
                                                          .deleteUploadedFile(
                                                        course: snapshot
                                                            .data["course_id"],
                                                        entry: snapshot
                                                            .data["entry_id"],
                                                        upload: snapshot
                                                            .data["upload_id"],
                                                        file: snapshot
                                                            .data["own_files"]
                                                                [index]
                                                            .index,
                                                        userPasswordEncrypted:
                                                            client.cryptor
                                                                .encryptString(
                                                                    passwordController
                                                                        .text),
                                                      );
                                                    } on LanisException catch (ex) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .hideCurrentSnackBar();
                                                      Navigator.of(context).push(
                                                          MaterialPageRoute(
                                                              builder:
                                                                  (context) {
                                                        return Scaffold(
                                                          appBar: AppBar(),
                                                          body: ErrorView(
                                                              error: ex,
                                                              name:
                                                                  "Löschen einer Datei",
                                                              ),
                                                        );
                                                      }));
                                                      return;
                                                    }

                                                    String message =
                                                        "Ein unbekannter Fehler entstand beim Löschen!";

                                                    if (response == "-1") {
                                                      message =
                                                          "Falsches Passwort!";
                                                    } else if (response ==
                                                        "-2") {
                                                      message =
                                                          "Das Löschen der Datei war nicht möglich!";
                                                    } else if (response ==
                                                        "1") {
                                                      message =
                                                          "Die Datei wurde erfolgreich gelöscht!";
                                                    }

                                                    showSnackbar(
                                                        text:
                                                            "$message ($response)");

                                                    forceReloadPage();
                                                  },
                                                  child: const Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                                right: 4.0),
                                                        child:
                                                            Icon(Icons.warning),
                                                      ),
                                                      Text("Dauerhaft löschen")
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            );
                                          });
                                    },
                                    icon: const Icon(Icons.delete))
                                : null,
                            onTap: !filesDeleted
                                ? () {
                                    showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (BuildContext context) {
                                          return const AlertDialog(
                                            title: Text("Download..."),
                                            content: Center(
                                              heightFactor: 1.1,
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          );
                                        });
                                    client
                                        .downloadFile(
                                            snapshot
                                                .data["own_files"][index].url,
                                            snapshot
                                                .data["own_files"][index].name)
                                        .then((filepath) {
                                      Navigator.of(context).pop();

                                      if (filepath == "") {
                                        showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                                  title: const Text("Fehler!"),
                                                  content: Text(
                                                      "Beim Download der Datei ${snapshot.data["own_files"][index].name} ist ein unerwarteter Fehler aufgetreten. Wenn dieses Problem besteht, senden Sie uns bitte einen Fehlerbericht."),
                                                  actions: [
                                                    TextButton(
                                                      child: const Text('OK'),
                                                      onPressed: () {
                                                        Navigator.of(context)
                                                            .pop();
                                                      },
                                                    ),
                                                  ],
                                                ));
                                      } else {
                                        OpenFile.open(filepath);
                                      }
                                    });
                                  }
                                : null,
                          );
                        }),
                    indentedDivider,
                    ValueListenableBuilder(
                        valueListenable: _addedFiles,
                        builder: (context, value, _) {
                          if (value == 0 &&
                              snapshot.data["course_id"] == null) {
                            if (now.isBefore(startDate)) {
                              String? waitingTime;

                              final Duration difference =
                                  now.difference(startDate);

                              if (difference.inHours >= 24) {
                                waitingTime = "${difference.inDays} Tag(e)";
                              } else if (difference.inHours <= 1) {
                                waitingTime =
                                    "${difference.inMinutes} Minute(n)";
                              } else {
                                waitingTime = "${difference.inHours} Stunden";
                              }

                              return uploadStatusContainer(
                                  "Die Abgabe ist in $waitingTime möglich.");
                            }

                            return uploadStatusContainer(
                                "Die Abgabe ist nicht mehr möglich.");
                          } else if (value == 0) {
                            return uploadStatusContainer(
                                "Füge dateien zum Upload hinzu.");
                          } else {
                            return Container(
                                margin: const EdgeInsets.only(
                                    top: 8, bottom: 8, left: 20, right: 20),
                                decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12)),
                                child: Column(
                                  children: [
                                    ..._fileWidgets,
                                    if (value != 5) ...[]
                                  ],
                                ));
                          }
                        }),
                    SizedBox.fromSize(
                      size: const Size(0, 104),
                    )
                  ],
                ),
              ),
            );
          }
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.name),
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        });
  }
}
