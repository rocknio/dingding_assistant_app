import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';

class DingdingInfo extends StatefulWidget {
	final Application dingdingApp;
	final MemoryImage dingdingIcon;

	DingdingInfo({Key key, this.dingdingApp, this.dingdingIcon}) : super(key: key);

  @override
  _DingdingInfoState createState() => _DingdingInfoState();
}

class _DingdingInfoState extends State<DingdingInfo> {
  @override
  Widget build(BuildContext context) {
    return Row(
	    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
	      widget.dingdingApp == null ? Container(
          child: Center(
            child: Container(
              width: 60.0,
              height: 60.0,
              child: Image.asset("assets/images/loading.gif")
            ),
          ),
        ) :
	      Center(
			    child: InkWell(
			      child: Container(
              width: 60.0,
              height: 60.0,
              child: Image.memory(widget.dingdingIcon.bytes)
			      ),
				    onTap: () {
			      	DeviceApps.openApp(widget.dingdingApp.packageName);
				    },
			    ),
	      ),
        widget.dingdingApp == null ? Container(
          child: Text("搜索钉钉...", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 20.0))
        ) :
		    Column(
			    crossAxisAlignment: CrossAxisAlignment.start,
			    mainAxisAlignment: MainAxisAlignment.center,
			    children: <Widget>[
	          Text(
              widget.dingdingApp.appName, 
              style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 20.0),
            ),
				    Text(
              widget.dingdingApp.packageName + ": " + widget.dingdingApp.versionCode.toString(), 
              style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey,)
            ),
			    ],
		    ),
      ],
    );
  }
}
