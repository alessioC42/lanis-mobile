import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/safe_launch.dart';
import 'dart:io' as dio_core;
import 'package:webview_flutter/webview_flutter.dart';

import '../utils/file_operations.dart';
import 'moodle_sso.dart';

class MoodleWebView extends ConsumerStatefulWidget {
  const MoodleWebView({super.key});

  @override
  ConsumerState<MoodleWebView> createState() => _MoodleWebViewState();
}

class _MoodleWebViewState extends ConsumerState<MoodleWebView> {
  static const noInternetError = "net::ERR_INTERNET_DISCONNECTED";

  final WebViewCookieManager cookieManager = WebViewCookieManager();
  late final WebViewController webViewController;

  ValueNotifier<bool> canGoBack = ValueNotifier(false);
  ValueNotifier<bool> canGoForward = ValueNotifier(false);
  ValueNotifier<int> progressIndicator = ValueNotifier(0);
  ValueNotifier<String> currentPageTitle = ValueNotifier("");

  String? error;
  Uri? errorUrl;

  bool isLoginError = false;
  String loginError = "";
  bool noInternetLogin = false;

  bool showWebView = true;
  bool isLoggedIn = false;

  Future<void> addWebViewCookies(
    final List<dio_core.Cookie> cookies,
    List<String> urls,
  ) async {
    for (int i = 0; i < cookies.length; i++) {
      await cookieManager.setCookie(
        WebViewCookie(
          name: cookies[i].name,
          value: cookies[i].value,
          domain: cookies[i].domain ?? Uri.parse(urls[i]).host,
          path: cookies[i].path ?? '/',
        ),
      );
    }
  }

  Future<void> getCookies() async {
    final checker = ref.read(connectionCheckerProvider);
    if (!(await checker.connected)) {
      if (!mounted) return;
      setState(() {
        isLoginError = true;
        noInternetLogin = true;
      });

      return;
    }

    if (!mounted) return;
    setState(() {
      isLoginError = false;
      noInternetLogin = false;
    });

    final account = ref.read(activeAccountProvider);
    final session = ref.read(sessionProvider).asData?.value;
    if (account == null || session == null) {
      setState(() {
        isLoginError = true;
        loginError = "No active account";
      });
      return;
    }

    try {
      final result = await performMoodleSso(
        schoolID: account.schoolID,
        username: account.username,
        password: account.password,
      );
      if (!mounted) return;

      await addWebViewCookies(
        [
          result.moProd01Cookie,
          result.moodleId1Cookie,
          result.moodleSessionCookie,
        ],
        [result.location3, result.location4, result.location4],
      );
      if (!mounted) return;

      final moodleHome = Uri.parse(result.moodleHomeUrl);
      await webViewController.loadRequest(moodleHome);
      if (!mounted) return;

      session.jar.saveFromResponse(Uri.parse(result.location3), [
        result.moProd01Cookie,
      ]);
      session.jar.saveFromResponse(Uri.parse(result.location4), [
        result.moodleId1Cookie,
        result.moodleSessionCookie,
      ]);

      if (!mounted) return;
      setState(() {
        isLoggedIn = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoginError = true;

        if (e is dio_core.SocketException || e is DioException) {
          loginError = "${AppLocalizations.of(context).networkError} - $e";
        } else {
          loginError = e.toString();
        }
      });
    }
  }

  Future<void> refresh() async {
    if (error != null) {
      error = null;
      if (errorUrl != null) {
        await webViewController.loadRequest(errorUrl!);
      }
      errorUrl = null;
      return;
    }
    await webViewController.reload();
  }

  Future<void> _handleMoodleDownload(Uri uri) async {
    double fileSize = 0;
    final storage = ref.read(storageManagerProvider);
    final fallbackName =
        storage?.generateUniqueHash(uri.toString()) ??
        uri.toString().hashCode.toString();
    String fileName = fallbackName;

    try {
      final session = ref.read(sessionProvider).asData?.value;
      if (session != null) {
        final response = await session.dio.headUri(uri);

        final disposition = response.headers.value('content-disposition');
        if (disposition != null) {
          final match = RegExp(r'filename="?([^"]+)"?').firstMatch(disposition);
          if (match != null) {
            fileName = match.group(1) ?? fallbackName;
          }
        }

        final length = response.headers.value('content-length');
        if (length != null) {
          fileSize = double.parse(length) / 1000000;
        }
      }
    } catch (_) {
      // Get filename the dirty way if HEAD request fails
      if (uri.pathSegments.isNotEmpty && uri.pathSegments.last.contains('.')) {
        fileName = uri.pathSegments.last;
      }
    }

    if (!mounted) return;
    showFileModal(
      context,
      DownloadableFile(
        name: fileName,
        url: uri,
        size: fileSize > 0 ? "(${fileSize.toStringAsFixed(2)} MB)" : "(N/A)",
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (progress == 100) {
              progressIndicator.value = 0;
            } else {
              progressIndicator.value = progress;
            }
          },
          onPageStarted: (String url) async {
            error = null;
            errorUrl = null;
            canGoBack.value = await webViewController.canGoBack();
            canGoForward.value = await webViewController.canGoForward();
          },
          onPageFinished: (String url) async {
            progressIndicator.value = 0;
            currentPageTitle.value = await webViewController.getTitle() ?? "";

            // Hide logout buttons
            await webViewController.runJavaScript('''
              var dropdownLogout = document.querySelector("div#user-action-menu a.dropdown-item[href*='/login/logout.php']");
              if (dropdownLogout) dropdownLogout.style.display = "none";
              var navLogout = document.querySelector("div.navbar li a[href*='index.php?logout=']");
              if (navLogout) navLogout.style.display = "none";
              ''');
          },
          onWebResourceError: (WebResourceError resourceError) {
            error = resourceError.description;
            errorUrl = Uri.tryParse(resourceError.url ?? "");
            progressIndicator.value = 0;
            setState(() {});
          },
          onNavigationRequest: (NavigationRequest request) async {
            error = null;
            final Uri? parsedUri = Uri.tryParse(request.url);

            if (parsedUri != null) {
              // Block logout URLs
              if (isSchulportalDomain(parsedUri) &&
                  (parsedUri.path == '/login/logout.php' ||
                      (parsedUri.path == '/index.php' &&
                          parsedUri.queryParameters['logout'] == 'all'))) {
                return NavigationDecision.prevent;
              }

              // Handle navigation to lanis
              if (parsedUri.host.toLowerCase() ==
                  'start.schulportal.hessen.de') {
                setState(() {
                  showWebView = false;
                });
                if (mounted) Navigator.pop(context);
                return NavigationDecision.prevent;
              }

              // Intercept file downloads
              if (parsedUri.path.contains('pluginfile.php') ||
                  parsedUri.queryParameters.containsKey('forcedownload')) {
                _handleMoodleDownload(parsedUri);
                return NavigationDecision.prevent;
              }
            }

            // Open external URLs in browser
            if (parsedUri == null || !isSchulportalDomain(parsedUri)) {
              await safeLaunchUrl(Uri.parse(request.url), context: context);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      );
    getCookies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Moodle"),
        leading: IconButton(
          onPressed: () async {
            setState(() {
              showWebView = false;
            });

            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Stack(
        children: [
          PopScope(
            canPop: false,
            onPopInvokedWithResult: (bool res, _) async {
              if (res) {
                return;
              }

              if (await webViewController.canGoBack()) {
                webViewController.goBack();
              } else {
                setState(() {
                  showWebView = false;
                });

                if (context.mounted) Navigator.pop(context);
              }
            },
            child: Visibility(
              visible: showWebView,
              child: RefreshIndicator(
                color: Theme.of(context).colorScheme.primary,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                onRefresh: refresh,
                child: WebViewWidget(controller: webViewController),
              ),
            ),
          ),

          // Background
          if (!isLoggedIn || error != null) ...[
            Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: SizedBox(
                    width: double.maxFinite,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Login
          if (!isLoggedIn && !isLoginError) ...[
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    AppLocalizations.of(context).logInTitle,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ),
          ] else if (!isLoggedIn) ...[
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (noInternetLogin) ...[
                    const Icon(Icons.wifi_off, size: 60),
                    SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context).noInternetConnection2,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ] else ...[
                    const Icon(Icons.warning, size: 60),
                    SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context).errorOccurred,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        loginError,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                  SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      await getCookies();
                    },
                    child: Text(AppLocalizations.of(context).tryAgain),
                  ),
                ],
              ),
            ),
          ],

          // Error
          if (error != null) ...[
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    error == noInternetError ? Icons.wifi_off : Icons.warning,
                    size: 60,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      error == noInternetError
                          ? AppLocalizations.of(context).noInternetConnection2
                          : AppLocalizations.of(context).errorOccurredWebsite,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (error != noInternetError) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                                horizontal: 8.0,
                              ),
                              child: Text(
                                AppLocalizations.of(context).error,
                                style: Theme.of(context).textTheme.labelLarge!
                                    .copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              error ?? "",
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4.0,
                              horizontal: 8.0,
                            ),
                            child: Text(
                              "URL",
                              style: Theme.of(context).textTheme.labelLarge!
                                  .copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            errorUrl?.toString() ?? "Unknown error",
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: isLoggedIn
          ? SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder(
                    valueListenable: progressIndicator,
                    builder: (context, progress, _) {
                      return Visibility(
                        visible: progress != 0,
                        maintainSize: true,
                        maintainState: true,
                        maintainAnimation: true,
                        child: LinearProgressIndicator(value: progress / 100),
                      );
                    },
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: refresh,
                        icon: const Icon(Icons.refresh),
                      ),
                      IconButton(
                        onPressed: () async {
                          if (error != null) {
                            await Clipboard.setData(
                              ClipboardData(
                                text: errorUrl?.toString() ?? "Unknown error",
                              ),
                            );
                            return;
                          }

                          final currentUrl = await webViewController
                              .currentUrl();
                          if (currentUrl != null) {
                            await Clipboard.setData(
                              ClipboardData(text: currentUrl),
                            );
                          }
                        },
                        icon: const Icon(Icons.link),
                      ),
                      Expanded(
                        child: error == null
                            ? Center(
                                child: ValueListenableBuilder(
                                  valueListenable: currentPageTitle,
                                  builder: (context, title, _) => Text(
                                    title,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelLarge,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      ValueListenableBuilder(
                        valueListenable: canGoBack,
                        builder: (context, can, _) {
                          return IconButton(
                            onPressed: can
                                ? () {
                                    webViewController.goBack();
                                  }
                                : null,
                            icon: const Icon(Icons.arrow_back),
                          );
                        },
                      ),
                      ValueListenableBuilder(
                        valueListenable: canGoForward,
                        builder: (context, can, _) {
                          return IconButton(
                            onPressed: can
                                ? () {
                                    webViewController.goForward();
                                  }
                                : null,
                            icon: const Icon(Icons.arrow_forward),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            )
          : SizedBox.shrink(),
    );
  }
}
