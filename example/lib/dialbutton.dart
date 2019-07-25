import 'package:flutter/material.dart';

class DialButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final Icon icon;

  DialButton({this.title, this.subtitle, this.color, this.icon});

  @override
  Widget build(BuildContext context) {

    return GestureDetector(
      onTap: (){
        print(title);
      },
      child: ClipOval(
        child: Container(
          color: color != null ? color : Colors.blue,
          height: 80.0, // height of the button
          width: 80.0, // width of the button
          child: Center(
              child: icon == null ? subtitle != null
                  ? Column(
                children: <Widget>[Padding(padding: EdgeInsets.only(top:8), child: Text(
                  title,
                  style: TextStyle(fontSize: 40),
                )), Text(subtitle)],
              )
                  : Padding(padding: EdgeInsets.only(top:8), child: Text(
                title,
                style: TextStyle(fontSize: 40),
              )) : icon),
        )),);
  }
}


