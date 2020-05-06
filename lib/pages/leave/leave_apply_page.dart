import 'dart:io';

import 'package:ap_common/resources/ap_icon.dart';
import 'package:ap_common/resources/ap_theme.dart';
import 'package:ap_common/utils/ap_localizations.dart';
import 'package:ap_common/utils/ap_utils.dart';
import 'package:ap_common/widgets/default_dialog.dart';
import 'package:ap_common/widgets/dialog_option.dart';
import 'package:ap_common/widgets/hint_content.dart';
import 'package:ap_common/widgets/progress_dialog.dart';
import 'package:ap_common/widgets/yes_no_dialog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nkust_ap/models/error_response.dart';
import 'package:nkust_ap/models/leave_submit_info_data.dart';
import 'package:nkust_ap/models/leave_campus_data.dart';
import 'package:nkust_ap/models/leave_submit_data.dart';
import 'package:nkust_ap/pages/leave/pick_tutor_page.dart';
import 'package:nkust_ap/utils/global.dart';
import 'package:date_range_picker/date_range_picker.dart' as DateRagePicker;
import 'package:sprintf/sprintf.dart';

enum _State {
  loading,
  finish,
  error,
  empty,
  userNotSupport,
  offline,
}
enum Leave { normal, sick, official, funeral, maternity }

class LeaveApplyPage extends StatefulWidget {
  static const String routerName = "/leave/apply";

  @override
  LeaveApplyPageState createState() => LeaveApplyPageState();
}

class LeaveApplyPageState extends State<LeaveApplyPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  ApLocalizations ap;

  _State state = _State.loading;

  var _formKey = GlobalKey<FormState>();

  LeaveSubmitInfoData leaveSubmitInfo;

  int typeIndex = 0;

  LeavesTeacher teacher;

  List<LeaveModel> leaveModels = [];

  bool isDelay = false;

  var _reason = TextEditingController();

  var _delayReason = TextEditingController();

  File image;

  String get errorTitle {
    switch (state) {
      case _State.loading:
      case _State.finish:
        return '';
      case _State.error:
      case _State.empty:
        return ap.somethingError;
      case _State.userNotSupport:
        return ap.userNotSupport;
        break;
      case _State.offline:
        return ap.offlineMode;
        break;
    }
    return '';
  }

  @override
  void initState() {
    FA.setCurrentScreen("LeaveApplyPage", "leave_apply_page.dart");
    _getLeavesInfo();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ap = ApLocalizations.of(context);
    return _body();
  }

  Widget _body() {
    switch (state) {
      case _State.loading:
        return Container(
          child: CircularProgressIndicator(),
          alignment: Alignment.center,
        );
      case _State.error:
      case _State.empty:
      case _State.offline:
      case _State.userNotSupport:
        return FlatButton(
          onPressed: null,
          child: HintContent(
            icon: state == _State.offline
                ? ApIcon.offlineBolt
                : ApIcon.permIdentity,
            content: errorTitle,
          ),
        );
      default:
        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.symmetric(vertical: 24),
              children: <Widget>[
                ListTile(
                  onTap: () {
                    showDialog<int>(
                      context: context,
                      builder: (BuildContext context) => AlertDialog(
                        title: Text(ap.leaveType),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(8),
                          ),
                        ),
                        contentPadding: EdgeInsets.all(0.0),
                        content: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.7,
                          child: ListView.separated(
                            shrinkWrap: true,
                            controller: ScrollController(
                                initialScrollOffset: typeIndex * 40.0),
                            itemCount: leaveSubmitInfo.type.length,
                            itemBuilder: (BuildContext context, int index) {
                              return DialogOption(
                                text: leaveSubmitInfo.type[index].title,
                                check: typeIndex == index,
                                onPressed: () {
                                  setState(() {
                                    typeIndex = index;
                                  });
                                  Navigator.pop(context);
                                },
                              );
                            },
                            separatorBuilder:
                                (BuildContext context, int index) {
                              return Divider(height: 6.0);
                            },
                          ),
                        ),
                      ),
                    );
                    FA.logAction('leave_type', 'click');
                  },
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  leading: Icon(
                    ApIcon.insertDriveFile,
                    size: 30,
                    color: ApTheme.of(context).grey,
                  ),
                  trailing: Icon(
                    ApIcon.keyboardArrowDown,
                    size: 30,
                    color: ApTheme.of(context).grey,
                  ),
                  title: Text(
                    ap.leaveType,
                    style: TextStyle(fontSize: 20),
                  ),
                  subtitle: Text(
                    leaveSubmitInfo.type[typeIndex].title,
                    style: TextStyle(fontSize: 20),
                  ),
                ),
                SizedBox(height: 16),
                Divider(color: ApTheme.of(context).grey, height: 1),
                SizedBox(height: 16),
                FractionallySizedBox(
                  widthFactor: 0.3,
                  child: RaisedButton(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(30.0),
                      ),
                    ),
                    padding: EdgeInsets.all(4.0),
                    color: ApTheme.of(context).blueAccent,
                    onPressed: () async {
                      final List<DateTime> picked =
                          await DateRagePicker.showDatePicker(
                        context: context,
                        initialFirstDate: DateTime.now(),
                        initialLastDate:
                            (DateTime.now()).add(Duration(days: 7)),
                        firstDate: DateTime(2015),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null && picked.length == 2) {
                        DateTime dateTime = picked[0],
                            end = picked[1].add(Duration(days: 1));
                        while (dateTime.isBefore(end)) {
                          bool hasRepeat = false;
                          for (var i = 0; i < leaveModels.length; i++) {
                            if (leaveModels[i].isSameDay(dateTime))
                              hasRepeat = true;
                          }
                          if (!hasRepeat) {
                            leaveModels.add(
                              LeaveModel(
                                dateTime,
                                leaveSubmitInfo.timeCodes.length,
                              ),
                            );
                          }
                          dateTime = dateTime.add(Duration(days: 1));
                        }
                        checkIsDelay();
                        setState(() {});
                      }
                    },
                    child: Text(
                      ap.addDate,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  height: leaveModels.length == 0 ? 0 : 280,
                  child: ListView.builder(
                    itemCount: leaveModels.length,
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (_, index) {
                      return Card(
                        elevation: 4.0,
                        margin: EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 8.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Column(
                            children: <Widget>[
                              SizedBox(height: 4.0),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: <Widget>[
                                  Text('${leaveModels[index].dateTime.year}/'
                                      '${leaveModels[index].dateTime.month}/'
                                      '${leaveModels[index].dateTime.day}'),
                                  IconButton(
                                    padding: EdgeInsets.all(0.0),
                                    icon: Icon(
                                      ApIcon.cancel,
                                      size: 20.0,
                                      color: ApTheme.of(context).red,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        leaveModels.removeAt(index);
                                        checkIsDelay();
                                      });
                                    },
                                  ),
                                ],
                              ),
                              Container(
                                height: 200,
                                width: 200,
                                child: GridView.builder(
                                  physics: NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    childAspectRatio: 1.0,
                                  ),
                                  itemBuilder: (context, sectionIndex) {
                                    return FlatButton(
                                      padding: EdgeInsets.all(0.0),
                                      child: Container(
                                        margin: EdgeInsets.all(4.0),
                                        padding: EdgeInsets.all(2.0),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(4.0),
                                          ),
                                          border: Border.all(
                                              color: ApTheme.of(context)
                                                  .blueAccent),
                                          color: leaveModels[index]
                                                  .selected[sectionIndex]
                                              ? ApTheme.of(context).blueAccent
                                              : null,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '${leaveSubmitInfo.timeCodes[sectionIndex]}',
                                          style: TextStyle(
                                            color: leaveModels[index]
                                                    .selected[sectionIndex]
                                                ? Colors.white
                                                : ApTheme.of(context)
                                                    .blueAccent,
                                          ),
                                        ),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          leaveModels[index]
                                                  .selected[sectionIndex] =
                                              !leaveModels[index]
                                                  .selected[sectionIndex];
                                        });
                                      },
                                    );
                                  },
                                  itemCount: leaveSubmitInfo.timeCodes.length,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: leaveModels.length == 0 ? 0 : 16.0),
                Divider(color: ApTheme.of(context).grey, height: 1),
                ListTile(
                  enabled: leaveSubmitInfo.tutor == null,
                  onTap: leaveSubmitInfo.tutor == null
                      ? () async {
                          var teacher = await Navigator.of(context).push(
                            CupertinoPageRoute(builder: (BuildContext context) {
                              return PickTutorPage();
                            }),
                          );
                          if (teacher != null) {
                            setState(() {
                              this.teacher = teacher;
                            });
                          }
                        }
                      : null,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  leading: Icon(
                    ApIcon.person,
                    size: 30,
                    color: ApTheme.of(context).grey,
                  ),
                  trailing: Icon(
                    ApIcon.keyboardArrowDown,
                    size: 30,
                    color: ApTheme.of(context).grey,
                  ),
                  title: Text(
                    ap.tutor,
                    style: TextStyle(fontSize: 20),
                  ),
                  subtitle: Text(
                    leaveSubmitInfo.tutor == null
                        ? (teacher?.name ?? ap.pleasePick)
                        : (leaveSubmitInfo.tutor?.name ?? ''),
                    style: TextStyle(fontSize: 20),
                  ),
                ),
                Divider(color: ApTheme.of(context).grey, height: 1),
                ListTile(
                  onTap: () {
                    ImagePicker.pickImage(source: ImageSource.gallery).then(
                      (image) async {
                        if (image != null) {
                          FA.logLeavesImageSize(image);
                          print(
                              'resize before: ${(image.lengthSync() / 1024 / 1024)}');
                          if ((image.lengthSync() / 1024 / 1024) >=
                              Constants.MAX_IMAGE_SIZE) {
                            resizeImage(image);
                          } else {
                            setState(() {
                              this.image = image;
                            });
                          }
                        }
                      },
                    );
                  },
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  leading: Icon(
                    ApIcon.insertDriveFile,
                    size: 30,
                    color: ApTheme.of(context).grey,
                  ),
                  trailing: Icon(
                    ApIcon.keyboardArrowDown,
                    size: 30,
                    color: ApTheme.of(context).grey,
                  ),
                  title: Text(
                    ap.leaveProof,
                    style: TextStyle(fontSize: 20),
                  ),
                  subtitle: Text(
                    image?.path?.split('/')?.last ?? ap.leaveProofHint,
                    style: TextStyle(fontSize: 20),
                  ),
                ),
                Divider(color: ApTheme.of(context).grey, height: 1),
                SizedBox(height: 36),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: TextFormField(
                    maxLines: 2,
                    controller: _reason,
                    validator: (value) {
                      if (value.isEmpty) {
                        return ap.doNotEmpty;
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      fillColor: ApTheme.of(context).blueAccent,
                      labelStyle: TextStyle(
                        color: ApTheme.of(context).grey,
                      ),
                      labelText: ap.reason,
                    ),
                  ),
                ),
                if (isDelay) ...[
                  SizedBox(height: 36),
                  Divider(color: ApTheme.of(context).grey, height: 1),
                  SizedBox(height: 36),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: TextFormField(
                      maxLines: 2,
                      validator: (value) {
                        if (isDelay && value.isEmpty) {
                          return ap.doNotEmpty;
                        }
                        return null;
                      },
                      controller: _delayReason,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        fillColor: ApTheme.of(context).blueAccent,
                        labelStyle: TextStyle(
                          color: ApTheme.of(context).grey,
                        ),
                        labelText: ap.delayReason,
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 36),
                FractionallySizedBox(
                  widthFactor: 0.8,
                  child: RaisedButton(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(30.0),
                      ),
                    ),
                    padding: EdgeInsets.all(14.0),
                    onPressed: () {
                      _leaveSubmit();
                      FA.logAction('leave_submit', 'click');
                    },
                    color: ApTheme.of(context).blueAccent,
                    child: Text(
                      ap.confirm,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.0,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 24),
              ],
            ),
          ),
        );
    }
  }

  Future _getLeavesInfo() async {
    Helper.instance.getLeavesSubmitInfo().then((leaveSubmitInfo) {
      if (leaveSubmitInfo != null) {
        setState(() {
          this.state = _State.finish;
          this.leaveSubmitInfo = leaveSubmitInfo;
        });
      }
    }).catchError((e) {
      if (e is DioError) {
        switch (e.type) {
          case DioErrorType.RESPONSE:
            if (e.response.statusCode == 401 || e.response.statusCode == 403) {
              setState(() {
                state = _State.userNotSupport;
              });
            } else {
              setState(() {
                state = _State.error;
              });
              Utils.handleResponseError(
                  context, 'getLeaveSubmitInfo', mounted, e);
            }
            break;
          case DioErrorType.DEFAULT:
            if (mounted) {
              setState(() {
                state = _State.error;
                ApUtils.showToast(context, ap.busFailInfinity);
              });
            }
            break;
          case DioErrorType.CANCEL:
            break;
          default:
            if (mounted) {
              setState(() {
                state = _State.error;
                Utils.handleDioError(context, e);
              });
            }
            break;
        }
      } else {
        throw (e);
      }
    });
  }

  void checkIsDelay() {
    isDelay = false;
    for (var i = 0; i < leaveModels.length; i++) {
      if (leaveModels[i].dateTime.isBefore(
            DateTime.now().add(
              Duration(days: 7),
            ),
          )) isDelay = true;
    }
    if (isDelay) {
      ApUtils.showToast(context, ap.leaveDelayHint);
    }
  }

  void _leaveSubmit() async {
    List<Day> days = [];
    leaveModels.forEach((leaveModel) {
      bool isNotEmpty = false;
      String date = '${leaveModel.dateTime.year}/'
          '${leaveModel.dateTime.month}/'
          '${leaveModel.dateTime.day}';
      List<String> sections = [];
      for (var i = 0; i < leaveModel.selected.length; i++) {
        if (leaveModel.selected[i]) {
          isNotEmpty = true;
          sections.add(leaveSubmitInfo.timeCodes[i]);
        }
      }
      if (isNotEmpty) {
        days.add(
          Day(
            day: date,
            dayClass: sections,
          ),
        );
      }
    });
    if (days.length == 0) {
      ApUtils.showToast(context, ap.pleasePickDateAndSection);
    } else if (leaveSubmitInfo.tutor == null && teacher == null) {
      ApUtils.showToast(context, ap.pickTeacher);
    } else if (_formKey.currentState.validate()) {
      //TODO submit summary
      String tutorId, tutorName;
      if (leaveSubmitInfo.tutor == null) {
        tutorId = teacher.id;
        tutorName = teacher.name;
      } else {
        tutorId = leaveSubmitInfo.tutor.id;
        tutorName = leaveSubmitInfo.tutor.name;
      }
      var data = LeaveSubmitData(
        days: days,
        leaveTypeId: leaveSubmitInfo.type[typeIndex].id,
        teacherId: tutorId,
        reasonText: _reason.text ?? '',
        delayReasonText: isDelay ? (_delayReason.text ?? '') : '',
      );
      showDialog(
        context: context,
        builder: (BuildContext context) => YesNoDialog(
          title: ap.leaveSubmit,
          contentWidgetPadding: EdgeInsets.all(0.0),
          contentWidget: SizedBox(
            height: MediaQuery.of(context).size.height *
                ((image == null) ? 0.3 : 0.5),
            width: MediaQuery.of(context).size.width * 0.7,
            child: ListView(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(
                    top: 16.0,
                    left: 30.0,
                    right: 30.0,
                  ),
                  child: RichText(
                    textAlign: TextAlign.left,
                    text: TextSpan(
                      style: TextStyle(
                          color: ApTheme.of(context).grey,
                          height: 1.5,
                          fontSize: 16.0),
                      children: [
                        TextSpan(
                          text: '${ap.leaveType}：',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                            text: '${leaveSubmitInfo.type[typeIndex].title}\n'),
                        TextSpan(
                          text: '${ap.tutor}：',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: '$tutorName\n'),
                        TextSpan(
                          text: '${ap.reason}：\n',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: '${_reason.text}'),
                        if (isDelay) ...[
                          TextSpan(
                            text: '${ap.delayReason}：\n',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: '${_delayReason.text}\n'),
                        ],
                        TextSpan(
                          text: '${ap.leaveDateAndSection}：\n',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        for (var day in days)
                          TextSpan(text: '${day.toString()}\n'),
                        TextSpan(
                          text:
                              '${ap.leaveProof}：${(image == null ? ap.none : '')}\n',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                if (image != null)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 16.0,
                      left: 30.0,
                      right: 30.0,
                    ),
                    child: Image.file(image),
                  ),
              ],
            ),
          ),
          leftActionText: ap.cancel,
          rightActionText: ap.submit,
          leftActionFunction: null,
          rightActionFunction: () {
            _leaveUpload(data);
            ApUtils.showToast(context, '上傳中，測試功能');
          },
        ),
      );
    }
  }

  void _leaveUpload(LeaveSubmitData data) {
    showDialog(
      context: context,
      builder: (BuildContext context) => WillPopScope(
        child: ProgressDialog(ap.leaveSubmitUploadHint),
        onWillPop: () async {
          return false;
        },
      ),
      barrierDismissible: false,
    );
    Helper.instance.sendLeavesSubmit(data, image).then((Response response) {
      Navigator.of(context, rootNavigator: true).pop();
      showDialog(
        context: context,
        builder: (BuildContext context) => DefaultDialog(
          title: response.statusCode == 200
              ? ap.leaveSubmit
              : '${response.statusCode}',
          contentWidget: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                color: ApTheme.of(context).grey,
                height: 1.3,
                fontSize: 16.0,
              ),
              children: [
                TextSpan(
                  text: response.statusCode == 200
                      ? ap.leaveSubmitSuccess
                      : '${response.data}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          actionText: ap.iKnow,
          actionFunction: () =>
              Navigator.of(context, rootNavigator: true).pop(),
        ),
      );
    }).catchError((e) {
      Navigator.of(context, rootNavigator: true).pop();
      if (e is DioError) {
        switch (e.type) {
          case DioErrorType.RESPONSE:
            String text = ap.somethingError;
            if (e.response.data is Map<String, dynamic>) {
              ErrorResponse errorResponse =
                  ErrorResponse.fromJson(e.response.data);
              text = errorResponse.description;
            }
            showDialog(
              context: context,
              builder: (BuildContext context) => DefaultDialog(
                title: ap.leaveSubmitFail,
                contentWidget: Text(
                  text,
                  style: TextStyle(
                    color: ApTheme.of(context).grey,
                    height: 1.3,
                    fontSize: 16.0,
                  ),
                ),
                actionText: ap.iKnow,
                actionFunction: () {
                  Navigator.of(context, rootNavigator: true).pop();
                },
              ),
            );
            break;
          case DioErrorType.DEFAULT:
            setState(() {
              state = _State.error;
            });
            ApUtils.showToast(context, ap.somethingError);
            break;
          case DioErrorType.CANCEL:
            break;
          default:
            Utils.handleDioError(context, e);
            break;
        }
      } else {
        throw e;
      }
    });
  }

  Future resizeImage(File image) async {
    File result = await Utils.resizeImageByNative(image);
    print('resize after: ${(result.lengthSync() / 1024 / 1024)}');
    FA.logLeavesImageCompressSize(image, result);
    if ((result.lengthSync() / 1024 / 1024) <= Constants.MAX_IMAGE_SIZE) {
      ApUtils.showToast(
        context,
        sprintf(
          ap.imageCompressHint,
          [
            Constants.MAX_IMAGE_SIZE,
            (result.lengthSync() / 1024 / 1024),
          ],
        ),
      );
      setState(() {
        this.image = result;
      });
    } else {
      ApUtils.showToast(context, ap.imageTooBigHint);
      FA.logEvent('leave_pick_fail');
    }
  }
}

class LeaveModel {
  DateTime dateTime;
  List<bool> selected = [];

  LeaveModel(this.dateTime, int count) {
    for (var i = 0; i < count; i++) {
      selected.add(false);
    }
  }

  bool isSameDay(DateTime dateTime) {
    return (dateTime.year == this.dateTime.year &&
        dateTime.month == this.dateTime.month &&
        dateTime.day == this.dateTime.day);
  }
}