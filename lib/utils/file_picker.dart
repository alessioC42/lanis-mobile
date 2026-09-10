import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lanis/utils/file_operations.dart';
import 'package:lanis/utils/logger.dart';
import 'package:lanis/utils/root_nav.dart';

import '../generated/l10n.dart';

class PickedFile {
  String name;

  /// The size in bytes (is 0 if something went wrong)
  num? size;

  String? path;

  String get extension => name.split('.').last;

  /// May be null if no mimeType was found
  String? get mimeType => lookupMimeType(path!);

  DioMediaType? get mediaType => DioMediaType.parse(mimeType!);

  PickedFile({required this.name, this.size, this.path});
}

extension Actions on PickedFile {
  Future<MultipartFile> intoMultipart() async {
    return await MultipartFile.fromFile(
      path!,
      filename: name,
      contentType: mediaType,
    );
  }
}

/// Allows the user to pick multiple files using any supported method (only Gallery and File Manager support multiple files)
Future<List<PickedFile>> pickMultipleFiles(
  BuildContext context,
  List<String>? allowedExtensions,
) async {
  List<bool> allowedMethods = [true, true, true];
  return showPickerUI(context, allowedMethods, allowedExtensions);
}

/// Allowed Methods (Position in [List<bool>]):
/// ```
/// 0 = File Manager
/// 1 = Camera
/// 2 = Gallery (iOS Only)
/// ```
Future<List<PickedFile>> showPickerUI(
  BuildContext context,
  List<bool> allowedMethods,
  List<String>? allowedExtensions,
) async {
  List<PickedFile> pickedFiles = [];
  if (context.mounted) {
    await showRootModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (allowedMethods[0])
                    (MenuItemButton(
                      onPressed: () async {
                        pickedFiles.addAll(
                          await pickFileUsingDocumentsUI(allowedExtensions),
                        );
                        if (context.mounted && pickedFiles.isNotEmpty) {
                          Navigator.pop(context);
                        }
                      },
                      child: Row(
                        children: [
                          Padding(padding: EdgeInsets.only(left: 10.0)),
                          Icon(Icons.file_open_rounded),
                          Padding(padding: EdgeInsets.only(right: 8.0)),
                          Text(AppLocalizations.of(context).fileManager),
                        ],
                      ),
                    )),
                  if (allowedMethods[1])
                    (MenuItemButton(
                      onPressed: () async {
                        final result = await pickFileUsingCamera(context);
                        if (result != null) {
                          pickedFiles.add(result);
                        }

                        if (context.mounted && pickedFiles.isNotEmpty) {
                          Navigator.pop(context);
                        }
                      },
                      child: Row(
                        children: [
                          Padding(padding: EdgeInsets.only(left: 10.0)),
                          Icon(Icons.camera_alt_rounded),
                          Padding(padding: EdgeInsets.only(right: 8.0)),
                          Text(AppLocalizations.of(context).camera),
                        ],
                      ),
                    )),
                  if (allowedMethods[2] &&
                      Platform
                          .isIOS) // DocumentsUI supports galleries and the photo picker is horrible (from a user perspective)
                    (MenuItemButton(
                      onPressed: () async {
                        pickedFiles.addAll(
                          await pickFilesUsingGallery(context),
                        );

                        if (context.mounted && pickedFiles.isNotEmpty) {
                          Navigator.pop(context);
                        }
                      },
                      child: Row(
                        children: [
                          Padding(padding: EdgeInsets.only(left: 10.0)),
                          Icon(Icons.photo_library_rounded),
                          Padding(padding: EdgeInsets.only(right: 8.0)),
                          Text(AppLocalizations.of(context).gallery),
                        ],
                      ),
                    )),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  return pickedFiles;
}

Future<List<PickedFile>> pickFileUsingDocumentsUI(
  List<String>? allowedExtensions,
) async {
  List<PlatformFile> files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
    allowMultiple: true,
  );
  List<PickedFile> returnResult = [];

  for (final file in files) {
    returnResult.add(
      PickedFile(name: file.name, path: file.path, size: await file.length()),
    );
  }

  return returnResult;
}

Future<PickedFile?> pickFileUsingCamera(BuildContext context) async {
  final ImagePicker imagePicker = ImagePicker();
  final XFile? image;
  try {
    image = await imagePicker.pickImage(source: ImageSource.camera);
  } on PlatformException catch (e) {
    logger.w('Camera pick failed: ${e.code}');
    return null;
  }
  String? path = image?.path;

  if (path == null) {
    return null;
  }

  if (context.mounted) {
    String? name = await askFileName(context);

    if (name == null) {
      return null;
    }

    name = "$name.${path.split(".").last}";
    String newPath = "${(await getApplicationCacheDirectory()).path}/$name";
    await moveFile(path, newPath);

    return PickedFile(
      name: newPath.split("/").last,
      path: newPath,
      size: await File(newPath).length(),
    );
  }

  return null;
}

/// This will return an empty list if called on anything other than iOS
Future<List<PickedFile>> pickFilesUsingGallery(BuildContext context) async {
  List<PickedFile> result = [];
  if (Platform.isIOS) {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images;
    try {
      images = await picker.pickMultiImage();
    } on PlatformException catch (e) {
      logger.w('Gallery pick failed: ${e.code}');
      return result;
    }

    if (context.mounted) {
      final name = await askFileName(context);

      if (name == null) {
        return result;
      }

      for (final image in images) {
        final String extension = image.path.split(".").last;
        final path =
            "${(await getApplicationCacheDirectory()).path}/$name.$extension";
        await moveFile(image.path, path);
        final file = File(path);
        final size = await file.length();

        result.add(
          PickedFile(
            name: file.path.split("/").last,
            size: size,
            path: file.path,
          ),
        );
      }
    }
  }
  return result;
}

Future<String?> askFileName(BuildContext context) async {
  String? result;
  final TextEditingController controller = TextEditingController();

  await showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(AppLocalizations.of(context).filename),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            child: Text(AppLocalizations.of(context).cancel),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          FilledButton(
            child: Text(AppLocalizations.of(context).confirm),
            onPressed: () {
              Navigator.of(context).pop();
              result = controller.text;
            },
          ),
        ],
      );
    },
  );

  return result;
}
