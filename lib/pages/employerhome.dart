import 'package:atten/pages/addstaff.dart';
import 'package:atten/pages/search.dart';
import 'package:atten/splashscreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slide_digital_clock/slide_digital_clock.dart';
import 'package:table_calendar/table_calendar.dart';

import 'login.dart';

List employees = [];
List names = [];

class EmployerHome extends StatefulWidget {
  const EmployerHome({Key? key, required this.number}) : super(key: key);
  final String number;

  @override
  _EmployerHomeState createState() => _EmployerHomeState();
}

class _EmployerHomeState extends State<EmployerHome> {
  String dropdownValue = "";
  List<String> business = [];
  TextEditingController businessName = TextEditingController();
  GlobalKey<ScaffoldState> sKey = GlobalKey();
  late GeoPoint geoPoint;
  DateTime now = DateTime.now();
  String weekday = "";
  Geolocator geolocator = Geolocator();

  bool loading = true;

  @override
  initState() {
    super.initState();
    loadBusiness();
  }

  loadBusiness() async {
    business = [];
    var snap = await firestore
        .collection("atten")
        .doc("users")
        .collection(widget.number)
        .get();

    snap.docs.forEach((element) {
      if (element.exists && element.id != "details") {
        business.add(element.id);
      } else {
        setState(() {
          loading = false;
        });
      }
    });
    dropdownValue = business[0];
    loadEmployees();
  }

  loadEmployees() async {
    employees = [];
    names = [];
    firestore
        .collection("atten")
        .doc("users")
        .collection(widget.number)
        .doc(dropdownValue) //Business
        .get()
        .then((value) {
      employees.addAll(value.data()!.keys);
      names.addAll(value.data()!.values);
      geoPoint = value['geo'];
    });
    setState(() {
      loading = false;
    });
    locateGeo();
  }

  addStaff() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => AddStaff(
                  geo: geoPoint,
                  number: widget.number,
                  business:
                      dropdownValue.isEmpty ? "Team_Alpha" : dropdownValue,
                ))).whenComplete(() {
      setState(() {
        loading = true;
      });
      loadBusiness();
    });
  }

  locateGeo() async {
    if (await Permission.locationWhenInUse.serviceStatus.isEnabled) {
      geolocator = Geolocator()..forceAndroidLocationManager = true;
      Position pos = await geolocator.getCurrentPosition();
      setState(() {
        geoPoint = GeoPoint(pos.latitude, pos.longitude);
      });
    } else {
      await Permission.locationWhenInUse.request();
      await locateGeo();
    }
  }

  search() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => Search(
                  number: widget.number,
                  business: dropdownValue,
                  staff: employees,
                  names: names,
                )));
  }

  addBusiness() {
    showDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
              title: const Text('Add Business'),
              content: Container(
                height: 50.0,
                width: 50.0,
                child: Card(
                  child: TextFormField(
                    textAlign: TextAlign.center,
                    controller: businessName,
                    // validator: (value) {},
                    decoration:
                        const InputDecoration(hintText: "Business Name"),
                  ),
                ),
              ),
              actions: [
                ElevatedButton(
                    onPressed: () {
                      if (businessName.text.length > 7 &&
                          !business.contains(businessName.text)) {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => AddStaff(
                                    geo: geoPoint,
                                    number: widget.number,
                                    business: businessName.text)));
                      } else {
                        sKey.currentState!.showSnackBar(const SnackBar(
                            content: Text("Try a different name")));
                      }
                    },
                    child: const Text("Add Staff")),
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    weekday = DateFormat.EEEE().format(now);
    return !loading
        ? Scaffold(
            key: sKey,
            appBar: AppBar(
              actions: [
                DropdownButton<String>(
                  value: dropdownValue,
                  icon: const Icon(Icons.arrow_drop_down),
                  iconSize: 24,
                  elevation: 16,
                  style: const TextStyle(color: Colors.white70, fontSize: 18),
                  underline: Container(
                    height: 2,
                    color: Colors.deepPurpleAccent,
                  ),
                  onChanged: (data) {
                    setState(() {
                      dropdownValue = data!;
                      loadEmployees();
                    });
                  },
                  items: business.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        style: const TextStyle(color: Colors.black),
                      ),
                    );
                  }).toList(),
                ),
                FlatButton(
                    onPressed: addBusiness,
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                    )),
              ],
              title: Text(widget.number),
            ),
            backgroundColor: Colors.amber,
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
                  weekday == "Friday"
                      ? "Thank God It's $weekday!"
                      : "It's $weekday",
                  style: const TextStyle(
                    fontSize: 30.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(
                  width: 50.0,
                  height: 10.0,
                ),
                // ElevatedButton(
                //   child: const Text("Add staff"),
                //   onPressed: () =>
                //       dropdownValue.isNotEmpty ? addStaff() : addBusiness(),
                // ),
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
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10.0))),
                          child: Center(
                            child: ListTile(
                              onTap: () => dropdownValue.isNotEmpty
                                  ? addStaff()
                                  : addBusiness(),
                              title: const Text(
                                "Add Staff",
                                style: TextStyle(
                                    fontSize: 19, color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                              subtitle: Text(
                                dropdownValue,
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
                              borderRadius:
                                  BorderRadius.all(Radius.circular(10.0))),
                          child: Center(
                            child: ListTile(
                              onTap: () => search(),
                              title: const Text(
                                "Manage Staff",
                                style: TextStyle(
                                    fontSize: 19, color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                              subtitle: Text(
                                dropdownValue,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )),
                    ),
                  ],
                ),
                const SizedBox(
                  width: 50.0,
                  height: 50.0,
                ),
                // ElevatedButton(
                //   child: const Text("Manage Staff"),
                //   onPressed: search,
                // ),
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
                // Text(employees.toString()),
              ],
            ),
          )
        : const CircularProgressIndicator();
  }
}
