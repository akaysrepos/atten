import 'package:atten/pages/attendance.dart';
import 'package:atten/pages/employerhome.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'login.dart';

class Search extends StatefulWidget {
  const Search({
    Key? key,
    required this.number,
    required this.staff,
    required this.business,
    required this.names,
  }) : super(key: key);
  final String number;
  final String business;
  final List staff;
  final List names;

  @override
  _SearchState createState() => _SearchState();
}

class _SearchState extends State<Search> {
  GlobalKey<ScaffoldState> sKey = GlobalKey();

  kickOut(String number) {
    showDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
              content: const Text("Delete"),
              actions: [
                ElevatedButton(
                    onPressed: () {
                      delete(number);
                      Navigator.pop(context);
                    },
                    child: const Text("Yes")),
              ],
            ));
  }

  delete(String number) async {
    firestore
        .collection("atten")
        .doc("users")
        .collection(widget.number)
        .doc(widget.business)
        .update({number: FieldValue.delete()}).whenComplete(() {
      sKey.currentState!.showSnackBar(const SnackBar(content: Text("Deleted")));
      Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.staff.isNotEmpty
        ? Scaffold(
            key: sKey,
            appBar: AppBar(
              title: const Text("Staff"),
            ),
            body: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                      itemCount: employees.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(
                            names[index],
                          ),
                          subtitle: Text(employees[index]),
                          onLongPress: () => kickOut(employees[index]),
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => Attendance(
                                          number: employees[index],
                                          name: names[index],
                                        )));
                          },
                        );
                      }),
                ),
              ],
            ),
          )
        : Scaffold(
            appBar: AppBar(
              title: const Text("Staff"),
            ),
            body: const Center(
              child: Text("Add Staff"),
            ),
          );
  }
}
