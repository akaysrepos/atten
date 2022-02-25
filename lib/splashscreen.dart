import 'dart:async';

import 'package:atten/locator.dart';
import 'package:atten/pages/employeehome.dart';
import 'package:atten/pages/employerhome.dart';
import 'package:atten/pages/login.dart';
import 'package:atten/pages/signup.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:atten/services/face_detector_service.dart';
import 'package:atten/services/ml_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool isLogged = true;
  late CameraDescription cameraDescription;
  MLService _mlService = locator<MLService>();
  FaceDetectorService _mlKitService = locator<FaceDetectorService>();

  @override
  void initState() {
    permit();

    super.initState();
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

  permit() async {
    final PermissionStatus permissionStatus = await _getPermission();
    if (permissionStatus == PermissionStatus.granted) {
      isLoggedIn();
    } else {
      //If permissions have been denied show standard cupertino alert dialog
      setState(() {
        isLogged = true;
      });
      showDialog(
          context: context,
          builder: (BuildContext context) => CupertinoAlertDialog(
                title: const Text('Permissions error'),
                content: const Text('Please enable contacts access '
                    'permission in system settings'),
                actions: <Widget>[
                  CupertinoDialogAction(
                    child: const Text('OK'),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ));
    }
  }

  void isLoggedIn() async {
    Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
    final SharedPreferences prefs = await _prefs;
    bool? log = prefs.getBool("isLoggedIn");
    String? type = prefs.getString("type");
    if (log == null || log == false) {
      setState(() {
        isLogged = false;
      });
    } else {
      setState(() {
        isLogged = true;
      });
      Timer(const Duration(seconds: 2), () {
        String? number = prefs.getString("number");
        if (type != null && type == "Employee") {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => EmployeeHome(
                        number: number!,
                        name: "Me",
                      )));
        } else {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => EmployerHome(number: number!)));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.amber,
      body: !isLogged
          ? Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Atten",
                    style:
                        TextStyle(fontStyle: FontStyle.italic, fontSize: 30.0),
                  ),
                  const SizedBox(height: 10.0, width: 20.0),
                  ElevatedButton(
                      onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const Login())),
                      child: const Text("Login")),
                  ElevatedButton(
                      onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SignUp())),
                      child: const Text("Sign Up")),
                ],
              ),
            )
          : const Center(
              child: Text(
                "Atten",
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 30.0),
              ),
            ),
    );
  }
}
