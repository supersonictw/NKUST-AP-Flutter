import 'package:ap_common/callback/general_callback.dart';
import 'package:ap_common/config/ap_constants.dart';
import 'package:ap_common/models/course_notify_data.dart';
import 'package:ap_common/scaffold/course_scaffold.dart';
import 'package:ap_common/utils/ap_localizations.dart';
import 'package:ap_common/utils/ap_utils.dart';
import 'package:ap_common/utils/preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:nkust_ap/models/semester_data.dart';
import 'package:nkust_ap/utils/global.dart';
import 'package:nkust_ap/widgets/semester_picker.dart';

class CoursePage extends StatefulWidget {
  static const String routerName = '/course';

  @override
  CoursePageState createState() => CoursePageState();
}

class CoursePageState extends State<CoursePage> {
  final key = GlobalKey<SemesterPickerState>();

  ApLocalizations ap;

  CourseState state = CourseState.loading;

  Semester selectSemester;
  SemesterData semesterData;
  CourseData courseData;

  CourseNotifyData notifyData;

  bool isOffline = false;

  String customStateHint = '';

  String get courseNotifyCacheKey => Preferences.getString(
        ApConstants.CURRENT_SEMESTER_CODE,
        ApConstants.SEMESTER_LATEST,
      );

  @override
  void initState() {
    FirebaseAnalyticsUtils.instance
        .setCurrentScreen('CoursePage', 'course_page.dart');
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ap = ApLocalizations.of(context);
    return CourseScaffold(
      state: state,
      courseData: courseData,
      notifyData: notifyData,
      customHint: isOffline ? ap.offlineCourse : '',
      customStateHint: customStateHint,
      enableNotifyControl: semesterData != null &&
          selectSemester.code == semesterData.defaultSemester.code,
      courseNotifySaveKey: courseNotifyCacheKey,
      androidResourceIcon: Constants.ANDROID_DEFAULT_NOTIFICATION_NAME,
      itemPicker: SemesterPicker(
        key: key,
        onSelect: (semester, index) {
          setState(() {
            selectSemester = semester;
            state = CourseState.loading;
          });
          semesterData = key.currentState.semesterData;
          if (Preferences.getBool(Constants.PREF_IS_OFFLINE_LOGIN, false))
            _loadCourseData(semester.code);
          else
            _getCourseTables();
        },
      ),
      onRefresh: () async {
        await _getCourseTables();
        FirebaseAnalyticsUtils.instance.logAction('refresh', 'swipe');
        return null;
      },
      onSearchButtonClick: () {
        key.currentState.pickSemester();
      },
    );
  }

  Future<bool> _loadCourseData(String value) async {
    courseData = CourseData.load(selectSemester.cacheSaveTag);
    if (mounted) {
      setState(() {
        isOffline = true;
        if (this.courseData == null) {
          state = CourseState.offlineEmpty;
        } else {
          state = CourseState.finish;
        }
      });
    }
    return this.courseData == null;
  }

  _getCourseTables() async {
    Helper.cancelToken.cancel('');
    Helper.cancelToken = CancelToken();
    Helper.instance.getCourseTables(
      semester: selectSemester,
      callback: GeneralCallback(
        onSuccess: (CourseData data) {
          if (mounted)
            setState(() {
              if (data == null) {
                state = CourseState.empty;
              } else {
                courseData = data;
                isOffline = false;
                courseData.save(selectSemester.cacheSaveTag);
                state = CourseState.finish;
                notifyData = CourseNotifyData.load(courseNotifyCacheKey);
              }
            });
        },
        onFailure: (DioError e) async {
          if (await _loadCourseData(selectSemester.code) &&
              e.type != DioErrorType.CANCEL)
            setState(() {
              state = CourseState.custom;
              customStateHint = ApLocalizations.dioError(context, e);
            });
          if (e.hasResponse)
            FirebaseAnalyticsUtils.instance.logApiEvent(
                'getCourseTables', e.response.statusCode,
                message: e.message);
        },
        onError: (GeneralResponse generalResponse) async {
          if (await _loadCourseData(selectSemester.code))
            setState(() {
              state = CourseState.custom;
              customStateHint = generalResponse.getGeneralMessage(context);
            });
        },
      ),
    );
  }
}
