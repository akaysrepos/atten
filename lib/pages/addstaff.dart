import 'dart:io';

import 'package:atten/pages/employerhome.dart';
import 'package:atten/pages/login.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class AddStaff extends StatefulWidget {
  const AddStaff(
      {Key? key,
      required this.number,
      required this.business,
      required this.geo})
      : super(key: key);
  final String number;
  final String business;
  final GeoPoint geo;

  @override
  _AddStaffState createState() => _AddStaffState();
}

class _AddStaffState extends State<AddStaff> {
  List<Contact> _contacts = [];
  bool imported = false;
  TextEditingController mobileController = TextEditingController();
  TextEditingController nameController = TextEditingController();
  GlobalKey<ScaffoldState> sKey = GlobalKey();

  @override
  initState() {
    importContacts();
    super.initState();
  }

  importContacts() async {
    final PermissionStatus permissionStatus = await _getPermission();
    if (permissionStatus == PermissionStatus.granted) {
      _contacts = (await ContactsService.getContacts(withThumbnails: true));
      setState(() {
        imported = true;
      });
    }
  }

  String spaceRemover(String number) {
    number = number.replaceAll(" ", "");
    if (number.length == 10) {
      number = "+91" + number;
    } else if (number.length == 12) {
      number = "+" + number;
    }
    return number;
  }

  Future<PermissionStatus> _getPermission() async {
    final PermissionStatus permission = await Permission.contacts.status;
    if (permission != PermissionStatus.granted &&
        permission != PermissionStatus.denied) {
      final Map<Permission, PermissionStatus> permissionStatus =
          await [Permission.contacts].request();
      return permissionStatus[Permission.contacts] ??
          PermissionStatus.restricted;
    } else {
      return permission;
    }
  }

  checkUser(String name, String number) {
    number = spaceRemover(number);
    firestore
        .collection("atten")
        .doc("users")
        .collection(number)
        .doc("details")
        .get()
        .then((value) {
      if (value.exists && value['type'] == "Employee") {
        addToStaff(name, number);
      } else if (!value.exists) {
        Navigator.pop(context);
        showDialog(
            context: context,
            builder: (BuildContext context) => CupertinoAlertDialog(
                  title: const Text('Not Found!'),
                  content: const Text(
                      'The contact is not a user\nDo you want to Invite them to Atten?'),
                  actions: <Widget>[
                    CupertinoDialogAction(
                      child: const Text('Invite'),
                      onPressed: () {
                        _textMe(number);
                        Navigator.of(context).pop();
                      },
                    ),
                    CupertinoDialogAction(
                      child: const Text('Try Again'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    )
                  ],
                ));
      }
    });
  }

  _textMe(String number) async {
    if (Platform.isAndroid) {
      String uri = 'sms:$number?body=Invite\nlink%20below:';
      await launch(uri);
    } else if (Platform.isIOS) {
      // iOS
      String uri = 'sms:$number&body=Invite\nlink%20below:';
      await launch(uri);
    }
  }

  addToStaff(String name, String number) {
    firestore
        .collection("atten")
        .doc("users")
        .collection(widget.number)
        .doc(widget.business)
        .set({number: name}, SetOptions(merge: true)).whenComplete(() {
      firestore
          .collection("atten")
          .doc("users")
          .collection(number)
          .doc("references")
          .set({widget.number: widget.geo},
              SetOptions(merge: true)).whenComplete(() {
        sKey.currentState!.showSnackBar(
            SnackBar(content: Text("Added To ${widget.business}!")));
        Navigator.pop(context);
      });
    });
  }

  numbersPrompt(Contact contact) {
    showDialog(
        context: context,
        builder: (BuildContext context) => CupertinoAlertDialog(
              title: const Text('Add Contact'),
              content: setupAlertDialoadContainer(contact),
              actions: [
                ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel")),
              ],
            ));
  }

  Widget setupAlertDialoadContainer(Contact contact) {
    return Container(
      height: 300.0, // Change as per your requirement
      width: 300.0, // Change as per your requirement
      child: ListView.builder(
          scrollDirection: Axis.vertical,
          shrinkWrap: false,
          itemCount: contact.phones!.length,
          itemBuilder: (context, index) {
            Item item = contact.phones![index];
            return FlatButton(
                onPressed: () => checkUser(contact.displayName!, item.value!),
                child: Text(item.value!));
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: sKey,
      appBar: AppBar(
        title: const Text("Add Staff"),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          TextFormField(
            textAlign: TextAlign.center,
            controller: nameController,
            decoration: const InputDecoration(hintText: "Enter Name"),
          ),
          TextFormField(
            keyboardType: TextInputType.phone,
            textAlign: TextAlign.center,
            controller: mobileController,
            decoration: const InputDecoration(hintText: "Enter Number"),
          ),
          const SizedBox(
            width: 10.0,
            height: 10.0,
          ),
          ElevatedButton(
              onPressed: () =>
                  checkUser(nameController.text, mobileController.text),
              child: const Text("Add to Staff")),
          const Text("or Add from Contacts"),
          imported
              ? Expanded(
                  child: ListView.builder(
                      scrollDirection: Axis.vertical,
                      shrinkWrap: true,
                      itemCount: _contacts.length,
                      itemBuilder: (context, index) {
                        Contact contact = _contacts[index];
                        return ListTile(
                          title: Text(contact.displayName!),
                          onTap: () => numbersPrompt(contact),
                        );
                      }),
                )
              : const CircularProgressIndicator()
        ],
      ),
    );
  }
}
