import 'dart:io';
import 'dart:typed_data';

import 'package:ap_common/pages/about_us_page.dart';
import 'package:ap_common/pages/open_source_page.dart';
import 'package:ap_common/resources/ap_icon.dart';
import 'package:ap_common/resources/ap_theme.dart';
import 'package:ap_common/utils/ap_localizations.dart';
import 'package:ap_common/utils/preferences.dart';
import 'package:ap_common_firebase/constants/fiirebase_constants.dart';
import 'package:ap_common_firebase/utils/firebase_analytics_utils.dart';
import 'package:ap_common_firebase/utils/firebase_utils.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nkust_ap/config/constants.dart';
import 'package:nkust_ap/pages/bus/bus_rule_page.dart';
import 'package:nkust_ap/pages/announcement/news_admin_page.dart';
import 'package:nkust_ap/pages/page.dart';
import 'package:nkust_ap/utils/app_localizations.dart';
import 'package:nkust_ap/widgets/share_data_widget.dart';

import 'api/helper.dart';
import 'models/login_response.dart';

class MyApp extends StatefulWidget {
  const MyApp({Key key}) : super(key: key);

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> with WidgetsBindingObserver {
  FirebaseAnalytics analytics;
  FirebaseMessaging firebaseMessaging;
  ThemeData themeData;
  LoginResponse loginResponse;
  Uint8List pictureBytes;
  bool offlineLogin = false;

  ThemeMode themeMode = ThemeMode.system;

  logout() {
    setState(() {
      this.offlineLogin = false;
      this.loginResponse = null;
      this.pictureBytes = null;
      Helper.clearSetting();
    });
  }

  @override
  void initState() {
    analytics = FirebaseUtils.init();
    themeMode = ThemeMode
        .values[Preferences.getInt(Constants.PREF_THEME_MODE_INDEX, 0)];
    FirebaseAnalyticsUtils.instance.logThemeEvent(themeMode);
    FirebaseAnalyticsUtils.instance
        .setUserProperty(FirebaseConstants.ICON_STYLE, ApIcon.code);
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    setState(() {});
    FirebaseAnalyticsUtils.instance.logThemeEvent(themeMode);
    super.didChangePlatformBrightness();
  }

  @override
  Widget build(BuildContext context) {
    return ShareDataWidget(
      data: this,
      child: ApTheme(
        themeMode,
        child: MaterialApp(
          localeResolutionCallback:
              (Locale locale, Iterable<Locale> supportedLocales) {
            String languageCode = Preferences.getString(
              Constants.PREF_LANGUAGE_CODE,
              ApSupportLanguageConstants.SYSTEM,
            );
            if (languageCode == ApSupportLanguageConstants.SYSTEM)
              return locale;
            else
              return Locale(
                languageCode,
                languageCode == ApSupportLanguageConstants.ZH ? 'TW' : null,
              );
          },
          onGenerateTitle: (context) => AppLocalizations.of(context).appName,
          debugShowCheckedModeBanner: false,
          routes: <String, WidgetBuilder>{
            Navigator.defaultRouteName: (context) => HomePage(),
            LoginPage.routerName: (BuildContext context) => LoginPage(),
            HomePage.routerName: (BuildContext context) => HomePage(),
            CoursePage.routerName: (BuildContext context) => CoursePage(),
            BusPage.routerName: (BuildContext context) => BusPage(),
            BusRulePage.routerName: (BuildContext context) => BusRulePage(),
            ScorePage.routerName: (BuildContext context) => ScorePage(),
            SchoolInfoPage.routerName: (BuildContext context) =>
                SchoolInfoPage(),
            SettingPage.routerName: (BuildContext context) => SettingPage(),
            AboutUsPage.routerName: (BuildContext context) =>
                HomePageState.aboutPage(context),
            OpenSourcePage.routerName: (BuildContext context) =>
                OpenSourcePage(),
            UserInfoPage.routerName: (BuildContext context) => UserInfoPage(),
            NewsAdminPage.routerName: (BuildContext context) => NewsAdminPage(),
            CalculateUnitsPage.routerName: (BuildContext context) =>
                CalculateUnitsPage(),
            LeavePage.routerName: (BuildContext context) => LeavePage(),
          },
          theme: ApTheme.light,
          darkTheme: ApTheme.dark,
          themeMode: themeMode,
          navigatorObservers: !kIsWeb && (Platform.isAndroid || Platform.isIOS)
              ? [
                  FirebaseAnalyticsObserver(analytics: analytics),
                ]
              : [],
          localizationsDelegates: [
            const AppLocalizationsDelegate(),
            const ApLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [
            const Locale('en', 'US'), // English
            const Locale('zh', 'TW'), // Chinese
          ],
        ),
      ),
    );
  }

  void update(ThemeMode mode) {
    setState(() {
      themeMode = mode;
    });
    FirebaseAnalyticsUtils.instance.logThemeEvent(themeMode);
  }

  void loadLocale(Locale locale) {
    setState(() {
      AppLocalizationsDelegate().load(locale);
      ApLocalizationsDelegate().load(locale);
    });
  }
}
