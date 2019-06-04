import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import 'package:dingding_assistant/dingding_info.dart';
import 'package:datetime_picker_formfield/datetime_picker_formfield.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flushbar/flushbar.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:analog_clock/analog_clock.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_keepscreenon/flutter_keepscreenon.dart';

enum workType {work, rest}
enum dayType {work, rest, holiday, unknown}

void main() {
	// 强制竖屏
	SystemChrome.setPreferredOrientations([
		DeviceOrientation.portraitUp,
		DeviceOrientation.portraitDown
	]);

	runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '钉钉辅助',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: '钉钉辅助'),
    );
  }
}

class TodayType {
	String day;
	dayType type;

	TodayType({this.day, this.type});
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
	Application dingdingApp;
	MemoryImage dingdingIcon;
	bool editAble = false;
	DateTime workTime, restTime;
	Timer _loopTimer;
	final String dingdingPackageName = "com.alibaba.android.rimet";
	final String selfPackageName = "com.example.dingding_assistant";
	SharedPreferences prefs;
	Application selfApp;
	TodayType todayType;
	bool isRunning = false;

	void _getSelfApp() async {
		if (selfApp == null) {
			selfApp = await DeviceApps.getApp(selfPackageName);
		}
	}

  void _getDingdingApp() async {
		if (dingdingApp == null) {
			Application _app = await DeviceApps.getApp(dingdingPackageName, true);
			setState(() {
				dingdingApp = _app;
				dingdingIcon = _app is ApplicationWithIcon ? MemoryImage(_app.icon) : null;
			});
		}
  }

  Future<void> initSharedPreferences() async {
  	prefs = await SharedPreferences.getInstance();

	  if (prefs.getInt("workTimeHour") != null && prefs.getInt("workTimeMinute") != null) {
	  	setState(() {
			  workTime = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, prefs.getInt("workTimeHour"), prefs.getInt("workTimeMinute"));
	  	});
	  }

	  if (prefs.getInt("workTimeHour") != null && prefs.getInt("restTimeMinute")!= null) {
	  	setState(() {
			  restTime = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, prefs.getInt("restTimeHour"), prefs.getInt("restTimeMinute"));
	  	});
	  }
  }

  void _setKeepScreenOn() async {
		try {
			await FlutterKeepscreenon.keepScreenOn(true);
		} on PlatformException catch (e) {
			print("_setKeepScreenOn Fail! e = $e");
		}
  }

  @override
  void initState() {
	  _getDingdingApp();
	  _getSelfApp();
	  _setKeepScreenOn();

	  initSharedPreferences();
    super.initState();
  }

  @override
  void dispose() {
	  cancelLoopTimer();

    super.dispose();
  }

	void cancelLoopTimer() {
		if (_loopTimer != null && _loopTimer.isActive) {
			_loopTimer.cancel();
			_loopTimer = null;
			isRunning = false;
		}
	}

	void startAssistantLoop() {
  	if (prefs == null) {
		  Flushbar(flushbarPosition: FlushbarPosition.TOP,
			  title: "亲",
			  message: "初始化未完成！",
			  icon: Icon(
				  Icons.warning,
				  size: 28.0,
				  color: Colors.yellow[300],
			  ),
			  duration: Duration(seconds: 3),
			  leftBarIndicatorColor: Colors.blue[300],
			  backgroundColor: Colors.red,
			  backgroundGradient: LinearGradient(colors: [Colors.blueGrey, Colors.black]),
			  isDismissible: false,
		  ).show(context);

		  return;
	  }

  	if (dingdingApp == null) {
		  Flushbar(flushbarPosition: FlushbarPosition.TOP,
			  title: "亲",
			  message: "安装钉钉了么？",
			  icon: Icon(
				  Icons.error,
				  size: 28.0,
				  color: Colors.red[300],
			  ),
			  duration: Duration(seconds: 3),
			  leftBarIndicatorColor: Colors.blue[300],
			  backgroundColor: Colors.red,
			  backgroundGradient: LinearGradient(colors: [Colors.blueGrey, Colors.black]),
			  isDismissible: false,
		  ).show(context);

  		return;
	  }

  	setState(() {
  	  isRunning = true;
  	});

		_loopTimer = Timer.periodic(Duration(seconds: 30), (_) {
			_launchDingding();
		});
	}

	void openSelf() {

	}

	Future<bool> openDingding() async {
		bool _isLaunched = false;
		String currentTime;

		currentTime = DateTime.now().toString();
		_isLaunched = await DeviceApps.openApp(dingdingPackageName);
		print("Open Dingding at: $currentTime, result = $_isLaunched");

		if (_isLaunched) {
			// 等待30秒，待钉钉启动后，重新启动自己
			Timer(Duration(seconds: 30), () async {
				openSelf();
				Timer(Duration(minutes: 1), () {
					startAssistantLoop();
				});
			});
		} else {
			Flushbar(flushbarPosition: FlushbarPosition.TOP,
				title: "错误",
				message: "钉钉启动失败",
				icon: Icon(
					Icons.error,
					size: 28.0,
					color: Colors.red[300],
				),
				duration: Duration(seconds: 3),
				leftBarIndicatorColor: Colors.blue[300],
				backgroundColor: Colors.red,
				backgroundGradient: LinearGradient(
						colors: [Colors.blueGrey, Colors.black]),
				isDismissible: false,
			).show(context);
		}

		Timer(Duration(minutes: 1), () {
			startAssistantLoop();
		});

		return _isLaunched;
	}

	void calcDelay() {
		var rng = Random();
		int delta = rng.nextInt(10);
		String tmp = DateTime.now().add(Duration(minutes: delta)).toString();
		print("打开钉钉时间：$tmp");
		Flushbar(flushbarPosition: FlushbarPosition.BOTTOM,
			title: "注意",
			message: "打开钉钉时间：$tmp",
			icon: Icon(
				Icons.notification_important,
				size: 28.0,
				color: Colors.yellow[300],
			),
			duration: Duration(seconds: 5),
			leftBarIndicatorColor: Colors.blue[300],
			backgroundColor: Colors.red,
			backgroundGradient: LinearGradient(
					colors: [Colors.blueGrey, Colors.black]),
			isDismissible: false,
		).show(context);

		Timer(Duration(minutes: delta), () {
			openDingding();
		});
	}

	/*
	API地址:http://tool.bitefu.net/jiari/
	新增VIP通道功能更全:http://tool.bitefu.net/jiari/vip.php
	功能特点
	检查具体日期是否为节假日，工作日对应结果为 0, 休息日对应结果为 1, 节假日对应的结果为 2；
	* */
	Future<dayType> checkHoliday() async {
		var currentDay = DateFormat("yyyyMMdd").format(DateTime.now());
		String url = "http://tool.bitefu.net/jiari/?d=" + currentDay;
		int tmp = 999;
		dayType ret = dayType.unknown;

		final resp = await http.get(url);
		if (resp.statusCode == 200 ) {
			tmp = int.parse(resp.body);
		}

		switch (tmp) {
			case 0:
				ret = dayType.work;
				break;
			case 1:
				ret = dayType.rest;
				break;
			case 2:
				ret = dayType.holiday;
				break;
		}

		return ret;
	}

	void _launchDingding() async {
		if (workTime == null || restTime == null) {
			return;
		}

		String tmp = DateTime.now().day.toString().padLeft(2, '0');
		if (todayType == null || tmp != todayType.day) {
			dayType tmp = await checkHoliday();
			todayType = TodayType()
				..day = DateTime.now().day.toString().padLeft(2, '0')
				..type = tmp;
		}

		if (todayType.type != dayType.work) {
			return;
		}

		cancelLoopTimer();

		int currentHour, currentMinute, currentSecond;
		currentHour = DateTime.now().hour;
		currentMinute = DateTime.now().minute;
		currentSecond = DateTime.now().second;

		print("Current Time: $currentHour:$currentMinute:$currentSecond");

		if (currentHour == workTime.hour && currentMinute == workTime.minute) {
			// 上班
			calcDelay();
		} else if (currentHour == restTime.hour && currentMinute == restTime.minute) {
			// 下班
			calcDelay();
		} else {
			startAssistantLoop();
		}
	}

	void setTime(workType type, DateTime time) async {
  	if (type == workType.work) {
  		workTime = time;
		  await prefs.setInt("workTimeHour", workTime.hour);
		  await prefs.setInt("workTimeMinute", workTime.minute);
	  } else if (type == workType.rest) {
  		restTime = time;
		  await prefs.setInt("restTimeHour", restTime.hour);
		  await prefs.setInt("restTimeMinute", restTime.minute);
	  }
	}

  @override
  Widget build(BuildContext context) {
  	var card = SizedBox(
		  height: 210.0,
		  child: Card(
			  elevation: 15.0,
			  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14.0))),
			  child: Column(
				  children: <Widget>[
				  	ListTile(
						  title: Text("时间设置", style: TextStyle(fontWeight: FontWeight.w500),),
						  leading: Icon(Icons.settings_applications, color: Colors.blue,),
					  ),
					  Divider(),
					  Padding(
					    padding: const EdgeInsets.symmetric(horizontal: 20.0),
					    child: DateTimePickerFormField(
						  inputType: InputType.time,
						  format: DateFormat("HH:mm"),
						  editable: editAble,
						  initialTime: workTime != null ? TimeOfDay(hour: workTime.hour, minute: workTime.minute) : TimeOfDay(hour: 8, minute: 40),
						  decoration: InputDecoration(
								labelText: workTime != null ? workTime.hour.toString().padLeft(2, '0') + ":" + workTime.minute.toString().padLeft(2, '0') : '上班时间：',
								hasFloatingPlaceholder: false,
							  suffixIcon: Icon(Icons.work),
						  ),
						  onChanged: (dt) {
							  setTime(workType.work, dt);
						  },
					    ),
					  ),
					  Padding(
					    padding: const EdgeInsets.symmetric(horizontal: 20.0),
					    child: DateTimePickerFormField(
						  inputType: InputType.time,
						  format: DateFormat("HH:mm"),
						  editable: editAble,
						  initialTime: restTime != null ? TimeOfDay(hour: restTime.hour, minute: restTime.minute) : TimeOfDay(hour: 18, minute: 00),
						  decoration: InputDecoration(
								  labelText: restTime != null ? restTime.hour.toString().padLeft(2, '0') + ":" + restTime.minute.toString().padLeft(2, '0') : '下班时间：',
								  hasFloatingPlaceholder: false
						  ),
						  onChanged: (dt) {
							  setTime(workType.rest, dt);
						  },
					    ),
					  ),
				  ],
			  ),
		  ),
	  );

  	return Scaffold(
		  appBar: AppBar(
			  title: Text(widget.title),
			  elevation: 5.0,
		  ),
		  body: Column(
			  children: <Widget>[
			  	Expanded(
					  child: Container(
				      decoration: BoxDecoration(color: Colors.blue),
							child: DingdingInfo(dingdingApp: dingdingApp, dingdingIcon: dingdingIcon,)
					  ),
					  flex: 1,
				  ),
				  Expanded(
					  child: card,
					  flex: 3,
				  ),
				  Expanded(
					  child: AnalogClock(
//						  decoration: BoxDecoration(
//							  border: Border.all(width: 2.0, color: Colors.black),
//							  color: Colors.transparent,
//							  shape: BoxShape.circle
//						  ),
						  width: 180.0,
						  isLive: true,
						  hourHandColor: Colors.black,
						  minuteHandColor: Colors.black,
						  showSecondHand: true,
						  secondHandColor: Colors.redAccent,
						  numberColor: Colors.black87,
						  showNumbers: true,
						  textScaleFactor: 1.4,
						  showTicks: true,
						  showDigitalClock: true,
					  ),
					  flex: 3,
				  )
			  ],
		  ),
		  floatingActionButton: FloatingActionButton(
			  backgroundColor: isRunning ? Colors.green : Colors.red,
			  onPressed: () async {
			  	startAssistantLoop();
			  },
			  child: Icon(Icons.send, color: Colors.white,),
		  ),
	  );
  }
}
