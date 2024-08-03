import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../client/fetcher.dart';
import '../exceptions/client_status_exceptions.dart';

void Function() retryFetcher(Fetcher fetcher) {
  return () {
    fetcher.fetchData(forceRefresh: true);
  };
}

class ErrorView extends StatelessWidget {
  late final LanisException error;
  late final void Function()? retry;
  late final bool showAppBar;
  late final String name;
  ErrorView(
      {super.key,
      required this.error,
      required this.name,
      this.showAppBar = false,
      this.retry});
  ErrorView.fromCode(
      {super.key,
      required int data,
      required this.name,
      this.showAppBar = false,
      this.retry}) {
    error = LanisException.fromCode(data);
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (showAppBar) ...[
          const SliverAppBar(),
        ],
        SliverFillRemaining(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Icon(
                  error is! NoConnectionException ? Icons.warning : Icons.wifi_off,
                  size: 60,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                    error is! NoConnectionException
                        ? AppLocalizations.of(context)!.reportError
                        : AppLocalizations.of(context)!.noInternetConnection2,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              if (error is! NoConnectionException) ...[
                Text("Problem: ${error.cause}"),
              ],
              const SizedBox(height: 24,),
              if (retry != null) FilledButton(
                  onPressed: retry,
                  child: Text(AppLocalizations.of(context)!.tryAgain)
              ),
              if (error is! NoConnectionException) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: OutlinedButton(
                          onPressed: () {
                            launchUrl(Uri.parse("https://github.com/alessioC42/lanis-mobile/issues"));
                          },
                          child: const Text("GitHub")
                      ),
                    ),
                    OutlinedButton(
                        onPressed: () {
                          launchUrl(Uri.parse("mailto:alessioc42.dev@gmail.com"));
                        },
                        child: Text(AppLocalizations.of(context)!.startupReportButton)
                    ),
                  ],
                )
              ],
            ],
          ),
        )
      ],
    );
  }
}
