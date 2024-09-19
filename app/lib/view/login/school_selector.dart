import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:sph_plan/error_builders.dart';

class SchoolSelector extends StatefulWidget {
  const SchoolSelector({super.key, required this.controller, required this.outContext, required this.onSchoolSelected});
  final TextEditingController controller;
  final BuildContext outContext;
  final Function onSchoolSelected;

  @override
  State<SchoolSelector> createState() => _SchoolSelectorState();

  static String sanitize(String input) {
    return input.replaceAll(RegExp(r'\W+'), '').toLowerCase();
  }
}

class _SchoolSelectorState extends State<SchoolSelector> {
  List<RemoteSchoolBezirk>? schoolBezirke;
  RemoteSchool? selectedSchool;
  TextEditingController searchController = TextEditingController();

  Future<void> loadSchoolList() async {
    try {
      final dio = Dio();
      final response = await dio.get(
          "https://startcache.schulportal.hessen.de/exporteur.php?a=schoollist");
      List<dynamic> data = jsonDecode(response.data);
      List<RemoteSchoolBezirk> result = [];
      for (var elem in data) {
        var bezirk = RemoteSchoolBezirk(id: elem["Id"], name: elem["Name"], schools: []);
        for (var schule in elem['Schulen']) {
          bezirk.schools.add(
            RemoteSchool(
              name: schule["Name"],
              id: schule["Id"],
              city: schule["Ort"],
            ),
          );
        }
        result.add(bezirk);
      }
      setState(() {
        schoolBezirke = result;
      });
    } catch (e, stack) {
      addLogMessage(e.toString());
      addLogMessage(stack.toString());
      // Show a SnackBar to inform the user
      ScaffoldMessenger.of(widget.outContext).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(widget.outContext)!.authFailedLoadingSchools),
          duration: const Duration(seconds: 10),
        ),
      );
      Future.delayed(const Duration(seconds: 10), loadSchoolList);
    }
  }


  List<RemoteSchoolBezirk> filterSchools(String query) {
    String sanitizedQuery = SchoolSelector.sanitize(query);

    return schoolBezirke!.map((bezirk) {
      var filteredSchools = bezirk.schools.where((school) {
        if (school.id.contains(sanitizedQuery)) {
          return true;
        }
        if (school.sanitizedCity.contains(sanitizedQuery)) {
          return true;
        }
        return school.sanitizedName.contains(sanitizedQuery);
      }).toList();
      return RemoteSchoolBezirk(
        id: bezirk.id,
        name: bezirk.name,
        schools: filteredSchools,
      );
    }).toList();
  }


  @override
  void initState() {
    super.initState();
    loadSchoolList();
  }

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.account_balance),
        label: Text(selectedSchool != null ? selectedSchool!.name : AppLocalizations.of(context)!.selectSchool),
      onPressed: schoolBezirke != null ? () async {
        showDialog(
          context: context,
          builder: (context) {
            return Dialog.fullscreen(
              child: Column(
                children: [
                  Padding(padding: const EdgeInsets.all(8.0),
                    child: SearchBar(
                      leading: const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Icon(Icons.search),
                      ),
                      controller: searchController,
                      hintText: AppLocalizations.of(context)!.searchSchools,
                      autoFocus: true,
                    ),
                  ),
                  Expanded(
                    child: ListenableBuilder(
                      listenable: searchController,
                      builder: (context, listenable) {
                        final filteredSchools = filterSchools(searchController.text);

                        final List<ExpansionTile> tiles = [];
                        for (var bezirk in filteredSchools) {
                          if (bezirk.schools.isNotEmpty) {
                            tiles.add(
                                ExpansionTile(
                                  key: PageStorageKey<String>("${bezirk.id}${searchController.text}"),
                                  title: Text(
                                    bezirk.name,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  subtitle: Text(AppLocalizations.of(context)!.schoolCountString(bezirk.schools.length),
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                  initiallyExpanded: bezirk.schools.length < 4,
                                  children: bezirk.schools.map((school) {
                                    return ListTile(
                                      title: Text(school.name),
                                      subtitle: Text(school.city),
                                      trailing: Text(school.id),
                                      onTap: () {
                                        setState(() {
                                          selectedSchool = school;
                                          widget.controller.text = school.id;
                                          searchController.clear();
                                        });
                                        widget.onSchoolSelected();
                                        Navigator.pop(context);
                                      },
                                    );
                                  }).toList(),
                                ),
                            );
                          }
                        }

                        return tiles.isNotEmpty ? ListView(
                          children: tiles,
                        ) : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_off, size: 60),
                              Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Text(
                                  AppLocalizations.of(context)!.noSchoolsFound,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                            ],
                          )
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }
        );
      } : null,
    );
  }
}

class RemoteSchoolBezirk {
  final String id;
  final String name;
  final List<RemoteSchool> schools;

  RemoteSchoolBezirk({required this.id, required this.name, required this.schools});
}

class RemoteSchool {
  final String name;
  final String id;
  final String city;
  late final String sanitizedName;
  late final String sanitizedCity;

  RemoteSchool({required this.name, required this.id, required this.city}) {
    sanitizedName = SchoolSelector.sanitize(name);
    sanitizedCity = SchoolSelector.sanitize(city);
  }
}