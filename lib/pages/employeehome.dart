import 'package:atten/pages/attendance.dart';
import 'package:atten/pages/login.dart';
import 'package:atten/pages/markattendance.dart';
import 'package:atten/splashscreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_clean_calendar/flutter_clean_calendar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slide_digital_clock/slide_digital_clock.dart';
import 'package:table_calendar/table_calendar.dart';

class EmployeeHome extends StatefulWidget {
  const EmployeeHome({Key? key, required this.number, required this.name})
      : super(key: key);
  final String number;
  final String name;

  @override
  _EmployeeHomeState createState() => _EmployeeHomeState();
}

class _EmployeeHomeState extends State<EmployeeHome> {
  DateTime now = DateTime.now();
  String weekday = "";
  bool isInOffice = false;
  List offices = [];
  Geolocator geolocator = Geolocator();

  GlobalKey<ScaffoldState> sKey = GlobalKey();

  @override
  initState() {
    super.initState();
    getOffices();
  }

  getOffices() {
    firestore
        .collection("atten")
        .doc("users")
        .collection(widget.number)
        .doc("references")
        .get()
        .then((value) {
      offices.addAll(value.data()!.values);
      // sKey.currentState!
      inOffice();
      //     .showSnackBar(SnackBar(content: Text(offices.toString())));
    });
  }

  inOffice() async {
    if (await Permission.locationWhenInUse.serviceStatus.isEnabled) {
      geolocator = Geolocator()..forceAndroidLocationManager = true;
      Position pos = await geolocator.getCurrentPosition();
      offices.forEach((element) async {
        double dis = await geolocator.distanceBetween(
            pos.latitude, pos.longitude, element.latitude, element.longitude);
        // sKey.currentState!.showSnackBar(SnackBar(content: Text("this works")));
        // sKey.currentState!.showSnackBar(SnackBar(content: Text("$dis")));
        if (dis.round() < 800) {
          // sKey.currentState!.showSnackBar(SnackBar(content: Text("$dis")));
          setState(() {
            isInOffice = true;
          });
        }
        // sKey.currentState!.showSnackBar(SnackBar(content: Text("$dis")));
      });
    } else {
      await Permission.locationWhenInUse.request();
      await inOffice();
    }
  }

  punchOut() {
    if (isInOffice) {
      now = DateTime.now();
      String month = DateFormat.MMMM().format(now);
      firestore
          .collection("atten")
          .doc("users")
          .collection(widget.number)
          .doc(month)
          .get()
          .then((value) {
        String status = value["${now.day}"];
        if (status.split("_").length == 4) {
          sKey.currentState!.showSnackBar(
              const SnackBar(content: Text("Already Punched out!")));
        } else if (status.split("_").length == 3) {
          firestore
              .collection("atten")
              .doc("users")
              .collection(widget.number)
              .doc(month)
              .set({"${now.day}": status + now.toString() + "_"},
                  SetOptions(merge: true)).then((value) {
            sKey.currentState!
                .showSnackBar(const SnackBar(content: Text("Punched out!")));
          });
        }
      });
    } else {
      sKey.currentState!.showSnackBar(
          const SnackBar(content: Text("Not in office permises!")));
    }
  }

  addStaff() {
    if (isInOffice) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => MarkAttendance(number: widget.number)));
    } else {
      sKey.currentState!.showSnackBar(
          const SnackBar(content: Text("Not in office permises!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    weekday = DateFormat.EEEE().format(now);
    return Scaffold(
      key: sKey,
      appBar: AppBar(
        title: const Text("Home"),
        centerTitle: true,
      ),
      backgroundColor: Colors.blue[100],
      body: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(
            width: 50.0,
            height: 50.0,
          ),
          DigitalClock(
            digitAnimationStyle: Curves.elasticOut,
            is24HourTimeFormat: false,
            areaDecoration: const BoxDecoration(
              color: Colors.transparent,
            ),
            hourMinuteDigitTextStyle: const TextStyle(
              color: Colors.blueGrey,
              fontSize: 50,
            ),
            amPmDigitTextStyle: const TextStyle(
                color: Colors.blueGrey, fontWeight: FontWeight.bold),
          ),
          const SizedBox(
            width: 50.0,
            height: 20.0,
          ),
          Text(
            weekday == "Friday" ? "Thank God It's $weekday!" : "It's $weekday",
            style: const TextStyle(
              fontSize: 30.0,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(
            width: 50.0,
            height: 10.0,
          ),
          TableCalendar(
            availableCalendarFormats: const {CalendarFormat.week: "week"},
            calendarFormat: CalendarFormat.week,
            firstDay: DateTime.utc(2010, 10, 16),
            lastDay: DateTime.utc(2030, 3, 14),
            focusedDay: DateTime.now(),
          ),
          const SizedBox(
            width: 50.0,
            height: 50.0,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(
                height: MediaQuery.of(context).size.width / 3,
                width: MediaQuery.of(context).size.width / 3,
                color: Colors.transparent,
                child: Container(
                    decoration: const BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.all(Radius.circular(10.0))),
                    child: Center(
                      child: ListTile(
                        onTap: addStaff,
                        title: const Text(
                          "Mark Attendance",
                          style: TextStyle(fontSize: 19, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        subtitle: const Text(
                          "Punch In",
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )),
              ),
              Container(
                height: MediaQuery.of(context).size.width / 3,
                width: MediaQuery.of(context).size.width / 3,
                color: Colors.transparent,
                child: Container(
                    decoration: const BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.all(Radius.circular(10.0))),
                    child: Center(
                      child: ListTile(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => Attendance(
                                    number: widget.number, name: widget.name))),
                        title: const Text(
                          "Statistics",
                          style: TextStyle(fontSize: 19, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        subtitle: const Text(
                          "Performance",
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )),
              ),
            ],
          ),
          // ElevatedButton(
          //   child: const Text("Mark Attendance"),
          //   onPressed: () => addStaff(),
          // ),
          // ElevatedButton(
          //   child: const Text("Statistics"),
          //   onPressed: () => Navigator.push(
          //       context,
          //       MaterialPageRoute(
          //           builder: (context) =>
          //               Attendance(number: widget.number, name: widget.name))),
          // ),
          const SizedBox(
            width: 50.0,
            height: 50.0,
          ),
          FlatButton(
              child: const Text(
                "Logout?",
                textAlign: TextAlign.center,
              ),
              onPressed: () async {
                Future<SharedPreferences> _prefs =
                    SharedPreferences.getInstance();
                final SharedPreferences prefs = await _prefs;
                prefs.setBool("isLoggedIn", false);
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SplashScreen()));
              }),
          Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: EdgeInsets.all(5.0),
                child: ElevatedButton(
                  child: const Text("Punch Out!"),
                  onPressed: punchOut,
                ),
              ))
          // Text(business.toString()),
        ],
      ),
    );
  }
}
