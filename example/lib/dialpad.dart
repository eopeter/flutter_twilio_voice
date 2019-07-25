import 'package:flutter/material.dart';

import 'dialbutton.dart';

class DialPad extends StatelessWidget
{
  final ValueSetter<String> makeCall;
  final textEditingController = TextEditingController();
  DialPad({this.makeCall});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(
      children: <Widget>[
        Padding(padding: EdgeInsets.all(20),child: TextField(controller: textEditingController,),),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          DialButton(title: "1", subtitle: "",),
          DialButton(title: "2", subtitle: "ABC",),
          DialButton(title: "3", subtitle: "DEF",)
        ],),
      SizedBox(height: 12,),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          DialButton(title: "4", subtitle: "GHI",),
          DialButton(title: "5", subtitle: "JKL",),
          DialButton(title: "6", subtitle: "MNO",)
        ],),
        SizedBox(height: 12,),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          DialButton(title: "7", subtitle: "PQRS",),
          DialButton(title: "8", subtitle: "TUV",),
          DialButton(title: "9", subtitle: "WXYZ",)
        ],),
        SizedBox(height: 12,),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          DialButton(title: "*", subtitle: "",),
          DialButton(title: "0", subtitle: "+",),
          DialButton(title: "#", subtitle: "",)
        ],),
        SizedBox(height: 15,),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
          GestureDetector(
            onTap: (){
              makeCall(textEditingController.text);
            },
            child: DialButton(icon: Icon(Icons.phone, size: 40, color: Colors.white,), color: Colors.green,),)
        ],)

    ],),);
  }

}