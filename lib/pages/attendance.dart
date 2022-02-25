import 'dart:collection';

import 'package:atten/pages/login.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_clean_calendar/flutter_clean_calendar.dart';
import 'package:intl/intl.dart';

class Attendance extends StatefulWidget {
  const Attendance({Key? key, required this.number, required this.name})
      : super(key: key);
  final String number;
  final String name;
  @override
  _AttendanceState createState() => _AttendanceState();
}

class _AttendanceState extends State<Attendance> {
  bool loading = true;
  late DocumentSnapshot<Map<String, dynamic>> doc;
  DateTime selectedDay = DateTime.now();
  String month = "";
  Map<String, DocumentSnapshot<Map<String, dynamic>>> attendance = {};
  Map<DateTime, List<CleanCalendarEvent>> _events = {};
  late List<CleanCalendarEvent> selectedEvent;
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();
  int present = 0, absent = 0, halfdays = 0;

  @override
  void initState() {
    super.initState();
    // DateFormat dt = DateFormat.MMMM();
    // month = dt.format(DateTime.now());
    getData(selectedDay);
    selectedEvent = _events[selectedDay] ?? [];
  }

  getData(DateTime month) async {
    // await firestore
    //     .collection("atten")
    //     .doc("users")
    //     .collection(widget.number)
    //     .doc(month)
    //     .get()
    //     .then((value) {
    //   doc = value;
    //   buildEvents(doc, month);
    // });

    var snap = await firestore
        .collection("atten")
        .doc("users")
        .collection(widget.number)
        .get();

    snap.docs.forEach((element) {
      if (element.exists && element.id != "details") {
        attendance.putIfAbsent(element.id, () => element);
      }
    });
    buildEvents(attendance, month);
  }

  buildEvents(Map<String, DocumentSnapshot<Map<String, dynamic>>> doc,
      DateTime date) async {
    DateTime mock = DateTime.parse("2022-02-19 00:00:00.000");
    DateTime now = DateTime.now();

    DateFormat dt = DateFormat.MMMM();
    month = dt.format(date);
    Map<DateTime, List<CleanCalendarEvent>> events = {};
    DocumentSnapshot<Map<String, dynamic>>? doc1 = doc[month];
    if (doc1 != null) {
      doc1.data()!.keys.forEach((element) {
        String record = doc1[element];
        List st = record.split("_");
        String status = st[0];
        String inTime = st[1].toString().isNotEmpty ? st[1] : mock.toString();
        String outTime = st[2].toString().isNotEmpty ? st[2] : mock.toString();
        // key.currentState!.showSnackBar(SnackBar(content: Text(date.toString())));
        if (date.month == now.month && int.parse(element) <= now.day) {
          // key.currentState!.showSnackBar(SnackBar(content: Text(element)));

          events.putIfAbsent(
              DateTime(date.year, date.month, int.parse(element)),
              () => [
                    CleanCalendarEvent(
                      status,
                      startTime: DateTime.parse(inTime),
                      endTime: DateTime.parse(outTime),
                    ),
                  ]);
          getStats(status);
        } else if (date.month < now.month) {
          String status = doc1[element];
          events.putIfAbsent(
              DateTime(date.year, date.month, int.parse(element)),
              () => [
                    CleanCalendarEvent(
                      status,
                      startTime: DateTime.parse(inTime),
                      endTime: DateTime.parse(outTime),
                    )
                  ]);
          getStats(status);
        }
      });
    }
    setState(() {
      loading = false;
      _events = events;
    });
  }

  getStats(String status) {
    if (status == "present") {
      present = present + 1;
    } else if (status == "absent") {
      absent = absent + 1;
    } else if (status == "halfday") {
      halfdays = halfdays + 1;
    }
    setState(() {});
  }

  void _handleData(date) async {
    buildEvents(attendance, date);
    setState(() {
      present = 0;
      absent = 0;
      halfdays = 0;
      selectedDay = date;
      selectedEvent = _events[selectedDay] ?? [];
    });
    print(selectedDay);
  }

  Widget stats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Container(
          height: MediaQuery.of(context).size.width / 4,
          width: MediaQuery.of(context).size.width / 4,
          color: Colors.transparent,
          child: Container(
              decoration: const BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.all(Radius.circular(10.0))),
              child: Center(
                child: ListTile(
                  title: Text(
                    "$present",
                    style: const TextStyle(fontSize: 22, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  subtitle: const Text(
                    "present",
                    textAlign: TextAlign.center,
                  ),
                ),
              )),
        ),
        Container(
          height: MediaQuery.of(context).size.width / 4,
          width: MediaQuery.of(context).size.width / 4,
          color: Colors.transparent,
          child: Container(
              decoration: const BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.all(Radius.circular(10.0))),
              child: Center(
                child: ListTile(
                  title: Text(
                    "$absent",
                    style: const TextStyle(fontSize: 22, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  subtitle: const Text(
                    "absent",
                    textAlign: TextAlign.center,
                  ),
                ),
              )),
        ),
        Container(
          height: MediaQuery.of(context).size.width / 4,
          width: MediaQuery.of(context).size.width / 4,
          color: Colors.transparent,
          child: Container(
              decoration: const BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.all(Radius.circular(10.0))),
              child: Center(
                child: ListTile(
                  title: Text(
                    "$halfdays",
                    style: const TextStyle(fontSize: 22, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  subtitle: const Text(
                    "halfdays",
                    textAlign: TextAlign.center,
                  ),
                ),
              )),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: key,
      appBar: AppBar(
        title: const Text('Attendance'),
        centerTitle: true,
      ),
      body: !loading
          ? Column(children: [
              Expanded(
                child: Container(
                  child: Calendar(
                    onMonthChanged: (value) {
                      buildEvents(attendance, value);
                      setState() {
                        selectedDay = value;
                        selectedEvent = _events[selectedDay] ?? [];
                      }
                    },
                    startOnMonday: true,
                    selectedColor: Colors.blue,
                    todayColor: Colors.red,
                    eventColor: Colors.green,
                    eventDoneColor: Colors.amber,
                    bottomBarColor: Colors.deepOrange,
                    onRangeSelected: (range) {
                      print('selected Day ${range.from},${range.to}');
                    },
                    onDateSelected: (date) {
                      return _handleData(date);
                    },
                    events: _events,
                    isExpanded: true,
                    dayOfWeekStyle: const TextStyle(
                      fontSize: 15,
                      color: Colors.black12,
                      fontWeight: FontWeight.w100,
                    ),
                    bottomBarTextStyle: const TextStyle(
                      color: Colors.white,
                    ),
                    hideBottomBar: false,
                    hideArrows: false,
                    weekDays: const [
                      'Mon',
                      'Tue',
                      'Wed',
                      'Thu',
                      'Fri',
                      'Sat',
                      'Sun'
                    ],
                  ),
                ),
              ),
              Text(
                widget.name,
                style: const TextStyle(fontSize: 20.0),
              ),
              Expanded(
                child: stats(),
              )
            ])
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
