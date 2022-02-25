import 'package:atten/pages/employeehome.dart';
import 'package:atten/pages/employerhome.dart';
import 'package:atten/pages/signup.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;
final FirebaseFirestore firestore = FirebaseFirestore.instance;

class Login extends StatefulWidget {
  const Login({
    Key? key,
  }) : super(key: key);

  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  String? label;
  bool isLoading = false;

  TextEditingController mobileController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  void login() async {
    String mobile = mobileController.text;
    setState(() {
      isLoading = true;
    });
    await checkInFirestore(mobile);
    setState(() {
      isLoading = false;
    });
  }

  verify(String mobile, String type) async {
    setState(() {
      isLoading = true;
    });
    _auth.verifyPhoneNumber(
        phoneNumber: mobile,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (_credential) async {
          logUser(mobile, type);
          setState(() {
            isLoading = false;
          });
          if (type == "Employee") {
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => EmployeeHome(
                          number: mobile,
                          name: "Me",
                        )));
          } else if (type == "Employer") {
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => EmployerHome(number: mobile)));
          }
        },
        codeSent: (String verificationId, [int? forceResendingToken]) {
          //show dialog to take input from the user
          setState(() {
            isLoading = false;
          });
          showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                    title: const Text("Enter SMS Code"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        TextFormField(
                          // initialValue: widget.otp,
                          controller: _codeController,
                        ),
                      ],
                    ),
                    actions: <Widget>[
                      FlatButton(
                        child: const Text("Done"),
                        textColor: Colors.white,
                        color: Colors.redAccent,
                        onPressed: () {
                          String smsCode = _codeController.text.trim();

                          var _credential = PhoneAuthProvider.credential(
                              verificationId: verificationId, smsCode: smsCode);
                          _auth.signInWithCredential(_credential).then((value) {
                            logUser(mobile, type);
                            if (type == "Employee") {
                              Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => EmployeeHome(
                                            number: mobile,
                                            name: "Me",
                                          )));
                            } else if (type == "Employer") {
                              Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          EmployerHome(number: mobile)));
                            }
                          }).catchError((e) {
                            print(e);
                          });
                        },
                      )
                    ],
                  ));
        },
        verificationFailed: (FirebaseAuthException error) {},
        codeAutoRetrievalTimeout: (String verificationId) {});
  }

  logUser(String number, String type) async {
    Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
    final SharedPreferences prefs = await _prefs;
    await prefs.setBool("isLoggedIn", true);
    await prefs.setString("number", number);
    await prefs.setString("type", type);
  }

  checkInFirestore(String mobile) async {
    firestore
        .collection("atten")
        .doc("users")
        .collection(mobile)
        .doc("details")
        .get()
        .then((value) async {
      if (value.exists) {
        verify(mobile, value['type']);
      } else {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => const SignUp()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return !isLoading
        ? Scaffold(
            body: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                TextFormField(
                  // initialValue: widget.number,
                  keyboardType: TextInputType.phone,
                  textAlign: TextAlign.center,
                  controller: mobileController,
                  decoration: const InputDecoration(hintText: "Enter Number"),
                ),
                ElevatedButton(onPressed: login, child: const Text("Login"))
              ],
            ),
          )
        : const Center(child: CircularProgressIndicator());
  }
}
