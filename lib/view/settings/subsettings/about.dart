import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanis/view/settings/settings_page_builder.dart';
import 'package:liblanis/liblanis.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/privacy_policy.dart';
import 'package:lanis/utils/safe_launch.dart';

import '../../../utils/logger.dart';

class AvatarTile extends StatelessWidget {
  final String networkImage;
  final String name;
  final String contributions;
  final double avatarSize;
  final EdgeInsets contentPadding;
  final void Function() onTap;
  final Color? color;

  const AvatarTile({
    super.key,
    required this.networkImage,
    required this.name,
    required this.contributions,
    required this.avatarSize,
    required this.contentPadding,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: contentPadding,
          child: Row(
            spacing: 8.0,
            children: [
              CircleAvatar(
                radius: avatarSize,
                backgroundImage: NetworkImage(networkImage),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    contributions,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AboutLink {
  final String Function(BuildContext context) title;
  final Future<void> Function(BuildContext context) onTap;

  final IconData iconData;

  const AboutLink({
    required this.title,
    required this.onTap,
    required this.iconData,
  });
}

class AboutSettings extends ConsumerSettingsColours {
  final bool showBackButton;
  const AboutSettings({super.key, this.showBackButton = true});

  @override
  ConsumerState<AboutSettings> createState() => _AboutSettingsState();
}

class _AboutSettingsState extends ConsumerSettingsColoursState<AboutSettings> {
  dynamic contributors;
  bool error = false;

  Future<dynamic> getContributors() async {
    setState(() {
      contributors = null;
      error = false;
    });

    try {
      final session = ref.read(sessionProvider).asData?.value;
      if (session == null) {
        setState(() => error = true);
        return;
      }
      final response = await session.dio.get(
        'https://api.github.com/repos/lanis-mobile/lanis/contributors',
      );
      setState(() {
        contributors = response.data;
      });
    } catch (e) {
      logger.e(e);
      setState(() {
        error = true;
      });
    }
  }

  final List<AboutLink> links = [
    AboutLink(
      title: (context) => AppLocalizations.of(context).githubRepository,
      iconData: Icons.code_outlined,
      onTap: (context) => safeLaunchUrl(
        Uri.parse("https://github.com/alessioC42/lanis-mobile"),
        context: context,
      ),
    ),
    AboutLink(
      title: (context) => AppLocalizations.of(context).discordServer,
      iconData: Icons.discord,
      onTap: (context) => safeLaunchUrl(
        Uri.parse("https://discord.gg/sWJXZ8FsU7"),
        context: context,
      ),
    ),
    AboutLink(
      title: (context) => AppLocalizations.of(context).featureRequest,
      iconData: Icons.add_comment_outlined,
      onTap: (context) => safeLaunchUrl(
        Uri.parse(
          "https://github.com/alessioC42/lanis-mobile/issues/new/choose",
        ),
        context: context,
      ),
    ),
    AboutLink(
      title: (context) => AppLocalizations.of(context).latestRelease,
      iconData: Icons.update_outlined,
      onTap: (context) => safeLaunchUrl(
        Uri.parse("https://github.com/alessioC42/lanis-mobile/releases/latest"),
        context: context,
      ),
    ),
    AboutLink(
      title: (context) => AppLocalizations.of(context).privacyPolicy,
      iconData: Icons.security_outlined,
      onTap: (context) =>
          safeLaunchUrl(Uri.parse(privacyPolicyUrl), context: context),
    ),
    AboutLink(
      title: (context) => AppLocalizations.of(context).openSourceLicenses,
      iconData: Icons.info_outline_rounded,
      onTap: (context) async => showLicensePage(context: context),
    ),
    AboutLink(
      title: (context) => AppLocalizations.of(context).buildInformation,
      iconData: Icons.build_outlined,
      onTap: (context) async {
        final packageInfo = await PackageInfo.fromPlatform();

        if (context.mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(AppLocalizations.of(context).appInformation),
                content: Text(
                  "appName: ${packageInfo.appName}\npackageName: ${packageInfo.packageName}\nversion: ${packageInfo.version}\nbuildNumber: ${packageInfo.buildNumber}\nisDebug: $kDebugMode\nisProfile: $kProfileMode\nisRelease: $kReleaseMode\n",
                ),
              );
            },
          );
        }
      },
    ),
  ];

  @override
  void initState() {
    super.initState();

    getContributors();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPageWithRefreshIndicator(
      backgroundColor: backgroundColor,
      title: Text(AppLocalizations.of(context).about),
      showBackButton: widget.showBackButton,
      onRefresh: () {
        return getContributors();
      },
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (contributors == null && error == false)
              const LinearProgressIndicator()
            else if (contributors != null && error == false) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 16.0,
                  children: [
                    Text(
                      AppLocalizations.of(context).contributors,
                      style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Column(
                      spacing: 4.0,
                      children: [
                        SizedBox(
                          height: 176.0,
                          child: Row(
                            spacing: 4.0,
                            children: [
                              Expanded(
                                flex: 4800,
                                child: Material(
                                  color: foregroundColor,
                                  borderRadius: BorderRadius.circular(12.0),
                                  child: InkWell(
                                    onTap: () => safeLaunchUrl(
                                      Uri.parse(contributors[0]['html_url']),
                                      context: context,
                                    ),
                                    borderRadius: BorderRadius.circular(12.0),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      spacing: 12.0,
                                      children: [
                                        CircleAvatar(
                                          radius: 38.0,
                                          backgroundImage: NetworkImage(
                                            contributors[0]['avatar_url'],
                                          ),
                                        ),
                                        Text(
                                          contributors[0]['login'],
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge!
                                              .copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                              ),
                                        ),
                                        Text(
                                          "${contributors[0]['contributions']} commits",
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall!
                                              .copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 5200,
                                child: Column(
                                  spacing: 4.0,
                                  children: [
                                    Expanded(
                                      flex: 5500,
                                      child: AvatarTile(
                                        networkImage:
                                            contributors[1]['avatar_url'],
                                        name: contributors[1]['login'],
                                        contributions:
                                            "${contributors[1]['contributions']} commits",
                                        avatarSize: 24.0,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16.0,
                                            ),
                                        color: foregroundColor,
                                        onTap: () => safeLaunchUrl(
                                          Uri.parse(
                                            contributors[1]['html_url'],
                                          ),
                                          context: context,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 4500,
                                      child: AvatarTile(
                                        networkImage:
                                            contributors[2]['avatar_url'],
                                        name: contributors[2]['login'],
                                        contributions:
                                            "${contributors[2]['contributions']} commits",
                                        avatarSize: 24.0,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16.0,
                                            ),
                                        color: foregroundColor,
                                        onTap: () => safeLaunchUrl(
                                          Uri.parse(
                                            contributors[2]['html_url'],
                                          ),
                                          context: context,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        for (var i = 3; i < contributors.length; i++)
                          AvatarTile(
                            networkImage: contributors[i]['avatar_url'],
                            name: contributors[i]['login'],
                            contributions:
                                "${contributors[i]['contributions']} ${contributors[i]['contributions'] == 1 ? "commit" : "commits"}",
                            avatarSize: 20.0,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                              vertical: 12.0,
                            ),
                            color: foregroundColor,
                            onTap: () => safeLaunchUrl(
                              Uri.parse(contributors[i]['html_url']),
                              context: context,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        if (!error) SizedBox(height: 24.0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            AppLocalizations.of(context).moreInformation,
            style: Theme.of(context).textTheme.labelLarge!.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        SizedBox(height: 4.0),
        for (var link in links)
          ListTile(
            leading: Icon(link.iconData),
            title: Text(link.title(context)),
            onTap: () => link.onTap(context),
          ),
        if (error) ...[
          SizedBox(height: 24.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20.0,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                SizedBox(height: 8.0),
                Text(
                  AppLocalizations.of(context).settingsErrorAbout,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: 12.0),
      ],
    );
  }
}
