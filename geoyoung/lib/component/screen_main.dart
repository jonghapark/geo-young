import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geoyoung/models/model_logdata.dart';
import '../models/model_bleDevice.dart';
import '../models/model_userDevice.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'package:location/location.dart' as loc;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../utils/util.dart';
import 'package:wakelock/wakelock.dart';
import 'package:flutter_android_pip/flutter_android_pip.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class Scanscreen extends StatefulWidget {
  @override
  ScanscreenState createState() => ScanscreenState();
}

class ScanscreenState extends State<Scanscreen> {
  BleManager _bleManager = BleManager();
  bool _isScanning = false;
  bool _connected = false;
  String currentMode = 'normal';
  String message = '';
  Peripheral _curPeripheral; // 연결된 장치 변수
  List<BleDeviceItem> deviceList = []; // BLE 장치 리스트 변수
  List<DeviceInfo> savedDeviceList = []; // 저장된 BLE 장치 리스트 변수
  List<String> savedList = []; // 추가된 장치 리스트 변수
  bool beforeInit = true;
  //List<BleDeviceItem> myDeviceList = [];
  String _statusText = ''; // BLE 상태 변수
  loc.LocationData currentLocation;
  int dataSize = 0;
  loc.Location location;
  StreamSubscription<loc.LocationData> _locationSubscription;
  StreamSubscription monitoringStreamSubscription;
  String _error;
  String geolocation;
  String currentDeviceName = '';
  String errorResult = '';
  String beforePhoneNumber = '';
  Timer _timer;
  int _start = 0;
  bool isStart = false;
  Map<String, String> idMapper;
  // double width;
  TextEditingController _textFieldController;
  String currentState = '';

  String firstImagePath = '';
  String secondImagePath = '';
  Future<List<DeviceInfo>> _allDeviceTemp;
  UserDeviceList userList;

  var _flutterLocalNotificationsPlugin;

  // Future<List<DateTime>> allDatetime;

  String currentTemp;
  String currentHumi;
  String resultText = '';

  String strMapper(String input) {
    if (input == 'scan') {
      return '대기 중';
    } else if (input == 'connecting') {
      return '연결 중';
    } else if (input == 'end') {
      return '전송 완료';
    } else if (input == 'connect') {
      return '데이터 전송 중';
    } else
      return '';
  }

  @override
  void initState() {
    // _allDeviceTemp = DBHelper().getAllDevices();
    super.initState();
    _textFieldController = TextEditingController(text: '');

    // getDeviceList();
    Wakelock.enable();

    currentDeviceName = '';
    currentTemp = '-';
    currentHumi = '-';
    setState(() {
      getCurrentLocation();
    });
    var initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    // var initializationSettingsIOS = IOSInitializationSettings();

    var initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    _flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onSelectNotification: onSelectNotification);
  }

  Future<void> onSelectNotification(String payload) async {
    debugPrint("$payload");
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: Text('Notification Payload'),
              content: Text('Payload: $payload'),
            ));
  }

  Future<void> _showNotification(String devicename, String destName) async {
    var android = AndroidNotificationDetails('geo_young_channel',
        'geo_young_channel', 'this is geo_young push channel',
        importance: Importance.max, priority: Priority.high);

    var ios = IOSNotificationDetails();
    var detail = NotificationDetails(android: android);

    await _flutterLocalNotificationsPlugin.show(
      Random().nextInt(1000),
      '🚨 온도 이탈 알림 🚨',
      destName + ' [ ' + devicename + ' ] 적정 온도를 이탈했습니다.',
      detail,
      payload: 'Hello Flutter',
    );
  }

  getDeviceList() async {
    String temp = this._textFieldController.text;
    String phoneNumber = '';
    phoneNumber += temp.substring(0, 3);
    phoneNumber += '-';
    phoneNumber += temp.substring(3, 7);
    phoneNumber += '-';
    phoneNumber += temp.substring(7, 11);

    // TODO: 배송중 회송
    try {
      var client = http.Client();
      var uri = Uri.parse('http://175.126.232.236:8987/bb');
      var uriResponse = await client.post(uri,
          headers: {"Content-Type": "application/x-www-form-urlencoded"},
          body: {"ZONE_NM": phoneNumber});
      print('뭐라고');
      print(uriResponse.body.toString().substring(34));
      String result = uriResponse.body.toString().substring(34);
      // print(json.decode(result));
      UserDeviceList list = UserDeviceList.fromJson(json.decode(result));
      print('end ! ');
      print('HTTP Result Code : ' + uriResponse.statusCode.toString());
      if (uriResponse.statusCode == 200) {
        setState(() {
          userList = list;

          // print(userList.userDevices[0].destName);
          // print(userList.userDevices[1].destName);
          // print(userList.userDevices[1].deviceName);
          // print(userList.userDevices[1].deviceNumber);

          //TODO: 더미 데이터 삭제 !
          // userList.userDevices.add(new UserDevice(
          //     deviceNumber: 'TESTSENSOR_EC5906',
          //     deviceName: 'GC123',
          //     destName: '굿 병원_3'));
          // userList.userDevices.add(new UserDevice(
          //     deviceNumber: 'TESTSENSOR_677199',
          //     deviceName: 'GC123',
          //     destName: 'Good 병굿_2'));
          // userList.userDevices.add(new UserDevice(
          //     deviceNumber: 'TESTSENSOR_0C5682',
          //     deviceName: 'GC555',
          //     destName: '굿 병원_1'));
          beforeInit = false;
        });
        if (beforePhoneNumber == '') {
          startTimer();
          init();
          beforePhoneNumber = phoneNumber;
        }
      } else {
        setState(() {
          errorResult = '다시 시도해주세요';
        });

        print('다시 시도해봐 !');
      }
    } catch (e) {
      print(e);
      setState(() {
        errorResult = '번호와 일치하는 정보가 없습니다.';
      });
    }
  }

  @override
  void dispose() {
    // ->> 사라진 위젯에서 cancel하려고 해서 에러 발생
    super.dispose();
    // _stopMonitoringTemperature();
    _bleManager.destroyClient();
  }

  Future<String> sendtoServer(List<LogData> list, String devicename,
      int battery, String device_Name, int state, String destName) async {
    // var client = http.Client();
    // print(socket.port);
    Socket socket = await Socket.connect('175.126.232.236', 9982);
    if (socket != null) {
      bool isOver = false;
      for (int i = 0; i < list.length; i += 5) {
        String body = '';
        if (list[i].temperature > 9 || list[i].temperature < 1) isOver = true;
        body += devicename +
            '|0|' +
            list[i].timestamp.toString() +
            '|' +
            list[i].timestamp.toString() +
            '|N|' +
            currentLocation.latitude.toString() +
            '|E|' +
            currentLocation.longitude.toString() +
            '|' +
            list[i].temperature.toString() +
            '|' +
            list[i].humidity.toString() +
            '|0|0|0|' +
            battery.toString() +
            '|' +
            state.toString() +
            ';';

        socket.write(body);
      }
      print('connected server & Sended to server');
      socket.close();
      if (isOver) {
        await _showNotification(device_Name, destName);
      }
      return 'success';
    } else {
      print('Fail Send to Server');
      return 'fail';
    }

    // try {
    //   for (int i = 0; i < list.length; i++) {
    //     print('$i send');
    //     var uriResponse = await client
    //         .post('http://175.126.232.236/_API/saveData.php', body: {
    //       "isRegularData": "true",
    //       "tra_datetime": list[i].timestamp.toString(),
    //       "tra_temp": list[i].temperature.toString(),
    //       "tra_humidity": list[i].humidity.toString(),
    //       "tra_lat": "",
    //       "tra_lon": "",
    //       "de_number": devicename,
    //       "tra_battery": battery.toString(),
    //       "tra_impact": ""
    //     });
    //     print(await client.get(uriResponse.body.toString()));
    //   }
    // } catch (e) {
    //   print('HTTP에러발생에러발생에러발생에러발생에러발생에러발생');
    //   print(e);
    //   return null;
    // } finally {
    //   print('send !');
    //   client.close();
    // }
  }

  Future<void> monitorCharacteristic(BleDeviceItem device, flag) async {
    await _runWithErrorHandling(() async {
      Service service = await device.peripheral.services().then((services) =>
          services.firstWhere((service) =>
              service.uuid == '00001000-0000-1000-8000-00805f9b34fb'));

      List<Characteristic> characteristics = await service.characteristics();
      Characteristic characteristic = characteristics.firstWhere(
          (characteristic) =>
              characteristic.uuid == '00001002-0000-1000-8000-00805f9b34fb');

      _startMonitoringTemperature(
          characteristic.monitor(transactionId: device.peripheral.identifier),
          device.peripheral,
          flag);
    });
  }

  Uint8List getMinMaxTimestamp(Uint8List notifyResult) {
    return notifyResult.sublist(12, 18);
  }

  void _stopMonitoringTemperature() async {
    monitoringStreamSubscription?.cancel();
  }

  void _startMonitoringTemperature(Stream<Uint8List> characteristicUpdates,
      Peripheral peripheral, flag) async {
    monitoringStreamSubscription?.cancel();

    monitoringStreamSubscription = characteristicUpdates.listen(
      (notifyResult) async {
        // print('혹시 이거임 ?' + notifyResult.toString());
        //데이터 삭제 읽기
        // if (notifyResult[10] == 0x0a) {
        //   \
        //   await showMyDialog_StartTransport(context);
        //   Navigator.of(context).pop();
        // }
        //
        if (notifyResult[10] == 0x03) {
          int index = -1;
          for (var i = 0; i < deviceList.length; i++) {
            if (deviceList[i].peripheral.identifier == peripheral.identifier) {
              index = i;
              break;
            }
          }
          // 최소 최대 인덱스
          if (index != -1) {
            Uint8List minmaxStamp = getMinMaxTimestamp(notifyResult);

            int startStamp = threeBytesToint(minmaxStamp.sublist(0, 3));

            int tempstamp = threeBytesToint(minmaxStamp.sublist(3, 6)) - 60;
            if (tempstamp <= 0) tempstamp += 60;
            int endStamp = threeBytesToint(minmaxStamp.sublist(3, 6));
            final startTest = Util.convertInt2Bytes(tempstamp, Endian.big, 3);
            Uint8List startIndex = Uint8List.fromList(startTest);
            // Uint8List startIndex = intToThreeBytes(tempstamp);
            Uint8List endindex = minmaxStamp.sublist(3, 6);
            print('Start Index : ' + startIndex.toString());
            print('End Index : ' + endindex.toString());

            deviceList[index].logDatas.clear();
            // 인덱스 이전 60개만 즉, 한 시간 데이터만 가져와서 비교
            if (peripheral.name == 'T301') {
              var writeCharacteristics = await peripheral.writeCharacteristic(
                  '00001000-0000-1000-8000-00805f9b34fb',
                  '00001001-0000-1000-8000-00805f9b34fb',
                  Uint8List.fromList([0x55, 0xAA, 0x01, 0x05] +
                      deviceList[index].getMacAddress() +
                      [0x04, 0x06] +
                      startIndex +
                      endindex),
                  true);
            } else if (peripheral.name == 'T306') {
              var writeCharacteristics = await peripheral.writeCharacteristic(
                  '00001000-0000-1000-8000-00805f9b34fb',
                  '00001001-0000-1000-8000-00805f9b34fb',
                  Uint8List.fromList([0x55, 0xAA, 0x01, 0x06] +
                      deviceList[index].getMacAddress() +
                      [0x04, 0x06] +
                      startIndex +
                      endindex),
                  true);
            }
          }
        }
        if (notifyResult[10] == 0x05) {
          int index = -1;
          for (var i = 0; i < deviceList.length; i++) {
            if (deviceList[i].peripheral.identifier == peripheral.identifier) {
              index = i;
              break;
            }
          }
          if (index != -1) {
            LogData temp = transformData(notifyResult);
            // print(temp.temperature.toString());
            if (deviceList[index].lastUpdateTime != null) {
              if (temp.timestamp
                  .toLocal()
                  .isAfter(deviceList[index].lastUpdateTime)) {
                deviceList[index].logDatas.add(temp);
              }
            } else {
              deviceList[index].logDatas.add(temp);
            }
          }
        }
        if (notifyResult[10] == 0x06) {
          int index = -1;
          for (var i = 0; i < deviceList.length; i++) {
            if (deviceList[i].peripheral.identifier == peripheral.identifier) {
              index = i;
              break;
            }
          }

          // Data sendData = new Data(
          //   battery: '',
          //   deviceName: 'Sensor_' + deviceList[index].getserialNumber(),
          //   humi: '',
          //   temper: deviceList[index].getTemperature().toString(),
          //   lat: '',
          //   lng: '',
          //   time: new DateTime.now().toLocal().toString(),
          //   lex: '',
          // );
          // 전송 시작
          print('전송 시작');
          String result = await sendtoServer(
              deviceList[index].logDatas,
              'SENSOR_' + deviceList[index].getserialNumber(),
              deviceList[index].getBattery(),
              deviceList[index].deviceName,
              deviceList[index].status,
              deviceList[index].destName);

          // 전송 결과
          // print(temp.body);
          // TODO: sendtoserver() 성공적으로 전송이 될 때만 업데이트.
          print('ㅡㅡㅡㅡㅡㅡㅡㅡ : ' + result);
          // 최근 업로드 기록 업데이트
          if (result == 'success') {
            await DBHelper().updateLastUpdate(
                peripheral.identifier, DateTime.now().toLocal());
            print('실행 ? ? ?');
            setState(() {
              deviceList[index].lastUpdateTime = DateTime.now().toLocal();
            });

            print('읽어온 개수 : ' + deviceList[index].logDatas.length.toString());
            int sendCount = 0;
            if (deviceList[index].logDatas.length % 5 == 0) {
              sendCount = deviceList[index].logDatas.length ~/ 5;
            } else {
              sendCount = (deviceList[index].logDatas.length ~/ 5) + 1;
            }

            print(deviceList[index].getserialNumber() +
                ' 총(개) : ' +
                sendCount.toString());

            setState(() {
              deviceList[index].connectionState = 'end';
              resultText = '[' +
                  deviceList[index].getserialNumber() +
                  '] ' +
                  sendCount.toString() +
                  ' 개(분) 전송 완료';
            });
          } else {
            setState(() {
              resultText = '[전송 실패] 네트워크 상태를 확인해주세요 !!';
              deviceList[index].connectionState = 'scan';
            });
          }
        }
      },
      onError: (error) {
        final BleError temperrors = error;
        if (temperrors.errorCode.value == 201) {
          print('그르게');
          int index = -1;
          for (var i = 0; i < deviceList.length; i++) {
            if (deviceList[i].peripheral.identifier == peripheral.identifier) {
              index = i;
              break;
            }
          }
          if (index != -1) {
            setState(() {
              deviceList[index].connectionState = 'scan';
            });
            print(deviceList[index].connectionState);
          }
        }

        print("Error while monitoring characteristic \n$error");
      },
      cancelOnError: true,
    );
  }

  void startRoutine(int index, flag) async {
    // 여기 !
    await monitorCharacteristic(deviceList[index], flag);
    String unixTimestamp =
        (DateTime.now().toUtc().millisecondsSinceEpoch / 1000)
            .toInt()
            .toRadixString(16);
    Uint8List timestamp = Uint8List.fromList([
      int.parse(unixTimestamp.substring(0, 2), radix: 16),
      int.parse(unixTimestamp.substring(2, 4), radix: 16),
      int.parse(unixTimestamp.substring(4, 6), radix: 16),
      int.parse(unixTimestamp.substring(6, 8), radix: 16),
    ]);

    Uint8List macaddress = deviceList[index].getMacAddress();
    print('쓰기 시작 ');
    if (flag == 0) {
      if (deviceList[index].peripheral.name == 'T301') {
        var writeCharacteristics = await deviceList[index]
            .peripheral
            .writeCharacteristic(
                '00001000-0000-1000-8000-00805f9b34fb',
                '00001001-0000-1000-8000-00805f9b34fb',
                Uint8List.fromList([0x55, 0xAA, 0x01, 0x05] +
                    deviceList[index].getMacAddress() +
                    [0x02, 0x04] +
                    timestamp),
                true);
      } else if (deviceList[index].peripheral.name == 'T306') {
        var writeCharacteristics = await deviceList[index]
            .peripheral
            .writeCharacteristic(
                '00001000-0000-1000-8000-00805f9b34fb',
                '00001001-0000-1000-8000-00805f9b34fb',
                Uint8List.fromList([0x55, 0xAA, 0x01, 0x06] +
                    deviceList[index].getMacAddress() +
                    [0x02, 0x04] +
                    timestamp),
                true);
      }
    } else if (flag == 1) {
      // 데이터 삭제 시작
      if (deviceList[index].peripheral.name == 'T301') {
        var writeCharacteristics = await deviceList[index]
            .peripheral
            .writeCharacteristic(
                '00001000-0000-1000-8000-00805f9b34fb',
                '00001001-0000-1000-8000-00805f9b34fb',
                Uint8List.fromList([0x55, 0xAA, 0x01, 0x05] +
                    deviceList[index].getMacAddress() +
                    [0x09, 0x01, 0x01]),
                true);
      } else if (deviceList[index].peripheral.name == 'T306') {
        var writeCharacteristics = await deviceList[index]
            .peripheral
            .writeCharacteristic(
                '00001000-0000-1000-8000-00805f9b34fb',
                '00001001-0000-1000-8000-00805f9b34fb',
                Uint8List.fromList([0x55, 0xAA, 0x01, 0x06] +
                    deviceList[index].getMacAddress() +
                    [0x09, 0x01, 0x01]),
                true);
      }
    }
  }

  // 타이머 시작
  // 00:00:00
  void startTimer() {
    if (isStart == true) return;
    const oneSec = const Duration(minutes: 30);
    const fiveSec = const Duration(seconds: 5);
    _timer = new Timer.periodic(
      oneSec,
      (Timer timer) => setState(
        () {
          if (isStart == false) isStart = true;
          _start = _start + 1;
          // if (_start % 5 == 0) {
          print('현재 몇번 돌았니 ? -> ' + _start.toString());
          _bleManager.stopPeripheralScan();

          Timer temp = new Timer.periodic(
            fiveSec,
            (Timer timer) => setState(
              () {
                // if (_start % 5 == 0) {

                _stopMonitoringTemperature();
                setState(() {
                  _isScanning = false;
                });
                scan();
                timer.cancel();
              },
            ),
          );

          _bleManager.stopPeripheralScan();
          _isScanning = false;
          getDeviceList();
          scan();
        },
      ),
    );
  }

  // BLE 초기화 함수
  void init() async {
    //ble 매니저 생성
    // savedDeviceList = await DBHelper().getAllDevices();
    setState(() {});
    await _bleManager
        .createClient(
            restoreStateIdentifier: "hello",
            restoreStateAction: (peripherals) {
              peripherals?.forEach((peripheral) {
                print("Restored peripheral: ${peripheral.name}");
              });
            })
        .catchError((e) => print("Couldn't create BLE client  $e"))
        .then((_) => _checkPermissions()) //매니저 생성되면 권한 확인
        .catchError((e) => print("Permission check error $e"));
  }

  // 권한 확인 함수 권한 없으면 권한 요청 화면 표시, 안드로이드만 상관 있음
  _checkPermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.location.request().isGranted) {
        print('입장하냐?');
        scan();
        return;
      }
      Map<Permission, PermissionStatus> statuses =
          await [Permission.location].request();
      if (statuses[Permission.location].toString() ==
          "PermissionStatus.granted") {
        //getCurrentLocation();
        scan();
      }
    } else {
      scan();
    }
  }

  //scan 함수
  void scan() async {
    if (!_isScanning) {
      print('스캔시작');
      setState(() {
        deviceList.clear(); //기존 장치 리스트 초기화
      });
      //SCAN 시작
      if (Platform.isAndroid) {
        _bleManager.startPeripheralScan(scanMode: ScanMode.lowLatency).listen(
            (scanResult) {
          //listen 이벤트 형식으로 장치가 발견되면 해당 루틴을 계속 탐.
          //periphernal.name이 없으면 advertisementData.localName확인 이것도 없다면 unknown으로 표시
          //print(scanResult.peripheral.name);
          var name = scanResult.peripheral.name ??
              scanResult.advertisementData.localName ??
              "Unknown";
          // 기존에 존재하는 장치면 업데이트
          // print('lenght: ' + deviceList.length.toString());
          var findDevice = deviceList.any((element) {
            if (element.peripheral.identifier ==
                scanResult.peripheral.identifier) {
              element.peripheral = scanResult.peripheral;
              element.advertisementData = scanResult.advertisementData;
              element.rssi = scanResult.rssi;

              if (element.connectionState == 'scan') {
                int index = -1;
                for (var i = 0; i < deviceList.length; i++) {
                  if (deviceList[i].peripheral.identifier ==
                      scanResult.peripheral.identifier) {
                    index = i;
                    break;
                  }
                }
                if (index != -1 && deviceList[index].status != 1) {
                  print('이골로 연결 ?');
                  connect(index, 0);
                }
              }
              // BleDeviceItem currentItem = new BleDeviceItem(
              //     name,
              //     scanResult.rssi,
              //     scanResult.peripheral,
              //     scanResult.advertisementData,
              //     'scan');

              // Data sendData = new Data(
              //   battery: currentItem.getBattery().toString(),
              //   deviceName:
              //       'OP_' + currentItem.getDeviceId().toString().substring(7),
              //   humi: currentItem.getHumidity().toString(),
              //   temper: currentItem.getTemperature().toString(),
              //   lat: currentLocation.latitude.toString() ?? '',
              //   lng: currentLocation.longitude.toString() ?? '',
              //   time: new DateTime.now().toString(),
              //   lex: '',
              // );
              // sendtoServer(sendData);

              return true;
            }
            return false;
          });
          // 새로 발견된 장치면 추가
          if (!findDevice) {
            if (name != "Unknown") {
              // print(name);
              // if (name.substring(0, 3) == 'IOT') {
              if (name != null) {
                if (name.length > 3) {
                  if (name.substring(0, 4) == 'T301' ||
                      name.substring(0, 4) == 'T306') {
                    BleDeviceItem currentItem = new BleDeviceItem(
                        name,
                        scanResult.rssi,
                        scanResult.peripheral,
                        scanResult.advertisementData,
                        'scan',
                        -1);
                    // print(currentItem.peripheral.identifier);
                    // print('인 !');
                    // 유저 리스트 목록에 있는 경우에만 추가
                    for (int k = 0; k < userList.userDevices.length; k++) {
                      if (userList.userDevices[k].deviceNumber.substring(
                              userList.userDevices[k].deviceNumber.length -
                                  6) ==
                          currentItem.getserialNumber()) {
                        print(userList.userDevices[k].destName);
                        currentItem.destName = userList.userDevices[k].destName;
                        currentItem.deviceName =
                            userList.userDevices[k].deviceName;
                        if (userList.userDevices[k].status == 0) {
                          currentItem.status = 3;
                        } else {
                          currentItem.status = userList.userDevices[k].status;
                        }
                        setState(() {
                          deviceList.add(currentItem);
                          deviceList
                              .sort((a, b) => a.destName.compareTo(b.destName));
                        });

                        int index = -1;
                        for (var i = 0; i < deviceList.length; i++) {
                          if (deviceList[i].peripheral.identifier ==
                              currentItem.peripheral.identifier) {
                            index = i;
                            break;
                          }
                        }
                        if (index != -1 && deviceList[index].status != 1)
                          connect(index, 0);
                        break;
                      }
                    }
                  }
                }
              }
            }
          }
          //55 aa - 01 05 - a4 c1 38 ec 59 06 - 01 - 07 - 08 b6 17 70 61 00 01
          //55 aa - 01 05 - a4 c1 38 ec 59 06 - 02 - 04 - 60 43 24 96
          //페이지 갱신용
          setState(() {});
        }, onError: (error) {
          print('스캔 중지당함');
          _bleManager.stopPeripheralScan();
        });
      }
      setState(() {
        //BLE 상태가 변경되면 화면도 갱신
        _isScanning = true;
        setBLEState('<스캔중>');
      });
    } else {
      // await _bleManager.destroyClient();
      //
      // //스캔중이었으면 스캔 중지
      // // TODO: 일단 주석!
      _bleManager.stopPeripheralScan();
      setState(() {
        //BLE 상태가 변경되면 페이지도 갱신
        _isScanning = false;
        setBLEState('Stop Scan');
      });
    }
  }

  //BLE 연결시 예외 처리를 위한 래핑 함수
  _runWithErrorHandling(runFunction) async {
    try {
      await runFunction();
    } on BleError catch (e) {
      print("BleError caught: ${e.errorCode.value} ${e.reason}");
    } catch (e) {
      if (e is Error) {
        debugPrintStack(stackTrace: e.stackTrace);
      }
      print("${e.runtimeType}: $e");
    }
  }

  // 상태 변경하면서 페이지도 갱신하는 함수
  void setBLEState(txt) {
    setState(() => _statusText = txt);
  }

  //연결 함수
  connect(index, flag) async {
    bool goodConnection = false;
    // if (_connected) {
    //   //이미 연결상태면 연결 해제후 종료
    //   print('mmmmmmm 여기냐 설마 ?? mmmmmmmmm');
    //   await _curPeripheral?.disconnectOrCancelConnection();
    //   setState(() {
    //     deviceList[index].connectionState = 'scan';
    //   });
    //   return false;
    // }

    //선택한 장치의 peripheral 값을 가져온다.
    Peripheral peripheral = deviceList[index].peripheral;

    DeviceInfo temp = await DBHelper().getDevice(peripheral.identifier);
    if (temp.macAddress == '123') {
      print('create');
      await DBHelper().createData(DeviceInfo(
          macAddress: peripheral.identifier,
          // Init Time - 10일 전
          lastUpdate: DateTime.now().toLocal().subtract(Duration(days: 300))));
      setState(() {
        deviceList[index].lastUpdateTime = null;
      });
    } else {
      print('Else 문 ?');
      setState(() {
        deviceList[index].lastUpdateTime = temp.lastUpdate.toLocal();
      });

      print(temp.lastUpdate.toLocal().toString());
      print('이미존재함 : ' + deviceList[index].getserialNumber());
      print('Last Update Time1 : ' + temp.lastUpdate.toString());
      // TODO: 시간 수정(3개) 필수 !
      print('Enable Time1 : ' +
          DateTime.now().toLocal().subtract(Duration(minutes: 10)).toString());
      if (temp.lastUpdate
          .isBefore(DateTime.now().toLocal().subtract(Duration(minutes: 10)))) {
        // deviceList[index].connectionState = 'connecting';
      } else {
        print('아직 시간이 안됨 !');
        // print('Last Update Time : ' + temp.lastUpdate.toString());
        // print('Enable Time : ' +
        //     DateTime.now().toLocal().subtract(Duration(minutes: 10)).toString());
        setState(() {
          deviceList[index].connectionState = 'scan';
        });
        return;
      }
    }
    print(deviceList[index].getserialNumber() + ' : Connection Start\n');
    //해당 장치와의 연결상태를 관촬하는 리스너 실행
    peripheral
        .observeConnectionState(emitCurrentValue: false)
        .listen((connectionState) {
      // 연결상태가 변경되면 해당 루틴을 탐.
      print(currentState);
      switch (connectionState) {
        case PeripheralConnectionState.connected:
          {
            currentState = 'connected';
            //연결됨
            print('연결 완료 !');
            _curPeripheral = peripheral;
            // getCurrentLocation();
            //peripheral.
            int tempIndex = -1;
            for (int i = 0; i < this.deviceList.length; i++) {
              if (this.deviceList[i].peripheral.identifier ==
                  peripheral.identifier) {
                tempIndex = i;
                break;
              }
            }
            if (tempIndex != -1) {
              //FIXME: 여기 setState 문제가 있을 수 있네??
              setState(() {
                deviceList[tempIndex].connectionState = 'connect';
              });
            }

            setBLEState('연결 완료');

            // startRoutine(index);
            Stream<CharacteristicWithValue> characteristicUpdates;

            print('결과 ' + characteristicUpdates.toString());

            // //데이터 받는 리스너 핸들 변수
            // StreamSubscription monitoringStreamSubscription;

            // //이미 리스너가 있다면 취소
            // //  await monitoringStreamSubscription?.cancel();
            // // ?. = 해당객체가 null이면 무시하고 넘어감.

            // monitoringStreamSubscription = characteristicUpdates.listen(
            //   (value) {
            //     print("read data : ${value.value}"); //데이터 출력
            //   },
            //   onError: (error) {
            //     print("Error while monitoring characteristic \n$error"); //실패시
            //   },
            //   cancelOnError: true, //에러 발생시 자동으로 listen 취소
            // );
            // peripheral.writeCharacteristic(BLE_SERVICE_UUID, characteristicUuid, value, withResponse)
          }
          break;
        case PeripheralConnectionState.connecting:
          {
            // deviceList[index].connectionState = 'connecting';

            // showMyDialog_Connecting(context);

            print('연결중입니당!');
            int tempIndex = -1;
            for (int i = 0; i < this.deviceList.length; i++) {
              if (this.deviceList[i].peripheral.identifier ==
                  peripheral.identifier) {
                tempIndex = i;
                break;
              }
            }
            if (tempIndex != -1) {
              //FIXME: 여기 setState 문제가 있을 수 있네??
              setState(() {
                deviceList[tempIndex].connectionState = 'connecting';
              });
            }
            currentState = 'connecting';
            setBLEState('<연결 중>');
          } //연결중
          break;
        case PeripheralConnectionState.disconnected:
          {
            // if (currentState == 'connecting')
            //  showMyDialog_Disconnect(context);
            //해제됨
            _connected = false;
            print("${peripheral.name} has DISCONNECTED");
            //TODO: 일단 주석 !
            // _stopMonitoringTemperature();
            int tempIndex = -1;
            for (int i = 0; i < this.deviceList.length; i++) {
              if (this.deviceList[i].peripheral.identifier ==
                  peripheral.identifier) {
                tempIndex = i;
                break;
              }
            }
            if (tempIndex != -1) {
              //FIXME: 여기 setState 문제가 있을 수 있네??
              setState(() {
                deviceList[tempIndex].connectionState = 'scan';
              });
            }

            setBLEState('<연결 종료>');

            print('여긴 오냐');
            return false;
            //if (failFlag) {}
          }
          break;
        case PeripheralConnectionState.disconnecting:
          {
            setBLEState('<연결 종료중>');
          } //해제중
          break;
        default:
          {
            //알수없음...
            print("unkown connection state is: \n $connectionState");
          }
          break;
      }
    });

    _runWithErrorHandling(() async {
      //해당 장치와 이미 연결되어 있는지 확인
      bool isConnected = await peripheral.isConnected();
      if (isConnected) {
        print('device is already connected');
        //이미 연결되어 있기때문에 무시하고 종료..
        return this._connected;
      }

      //연결 시작!
      await peripheral
          .connect(
        isAutoConnect: false,
      )
          .then((_) {
        this._curPeripheral = peripheral;
        //연결이 되면 장치의 모든 서비스와 캐릭터리스틱을 검색한다.
        peripheral
            .discoverAllServicesAndCharacteristics()
            .then((_) => peripheral.services())
            .then((services) async {
          print("PRINTING SERVICES for ${peripheral.name}");
          //각각의 서비스의 하위 캐릭터리스틱 정보를 디버깅창에 표시한다.
          for (var service in services) {
            print("Found service ${service.uuid}");
            List<Characteristic> characteristics =
                await service.characteristics();
            for (var characteristic in characteristics) {
              print("charUUId: " + "${characteristic.uuid}");
            }
          }
          //모든 과정이 마무리되면 연결되었다고 표시

          startRoutine(index, flag);
          // if (flag == 1) {
          //   showMyDialog_finishStart(
          //       context, deviceList[index].getserialNumber());
          // }
          _connected = true;
          _isScanning = true;
          setState(() {});
        });
      });
      print(_connected.toString());
      return _connected;
    });
  }

  getPhoneNumber() {
    return Container(
        decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [customeBoxShadow()],
            borderRadius: BorderRadius.all(Radius.circular(5))),
        height: MediaQuery.of(context).size.height * 0.5,
        width: MediaQuery.of(context).size.width * 0.8,
        child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                children: [
                  Text('번호 입력\n', style: boldTextStyle3),
                  TextField(
                    controller: _textFieldController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: '전화번호 ex) 010xxxxxxxx',
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      String temp = '';
                      // print(_textFieldController.text);
                      // print(temp.toString());
                      if (_textFieldController.text == '' ||
                          _textFieldController.text.length != 11) {
                        setState(() {
                          errorResult = '전화번호를 확인해주세요. ';
                        });
                      } else {
                        await getDeviceList();
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                          color: Colors.black,
                          boxShadow: [customeBoxShadow()],
                          borderRadius: BorderRadius.all(Radius.circular(5))),
                      width: MediaQuery.of(context).size.width * 0.98,
                      padding: EdgeInsets.all(16),
                      margin: EdgeInsets.only(top: 8, bottom: 8),
                      alignment: Alignment.center,
                      child: Text(
                        '확인',
                        style: TextStyle(
                          fontSize: 24,
                          color: Color.fromRGBO(255, 255, 255, 1),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  Text(errorResult),
                ],
              ),
            ]));
  }

  //장치 화면에 출력하는 위젯 함수
  list() {
    if (deviceList?.isEmpty == true) {
      return Container(
          decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [customeBoxShadow()],
              borderRadius: BorderRadius.all(Radius.circular(5))),
          height: MediaQuery.of(context).size.height * 0.7,
          width: MediaQuery.of(context).size.width * 0.99,
          child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  children: [
                    Text(
                      '디바이스를 스캔중입니다.',
                      style: lastUpdateTextStyle(context),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text('블루투스가 켜져있나 확인해주세요.\n',
                        style: lastUpdateTextStyle(context)),
                  ],
                )
              ]));
    } else {
      return ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: deviceList.length,
        itemBuilder: (BuildContext context, int index) {
          return Container(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        flex: 7,
                        child: Container(
                          decoration: BoxDecoration(
                              color: deviceList[index].status == 1
                                  ? Color.fromRGBO(10, 10, 10, 0.4)
                                  : Colors.yellow,
                              boxShadow: [customeBoxShadow()],
                              borderRadius:
                                  BorderRadius.all(Radius.circular(5))),
                          margin: EdgeInsets.only(
                            right: 8,
                            bottom: 8,
                          ),
                          padding: EdgeInsets.all(8),
                          alignment: Alignment.center,
                          child: Text(
                              deviceList[index].status == 2
                                  ? deviceList[index].destName + ' (회송)'
                                  : deviceList[index].destName,
                              style: boldTextStyle),
                        )),
                    Expanded(
                        flex: 3,
                        child: Container(
                          decoration: BoxDecoration(
                              color: Color.fromRGBO(230, 230, 230, 1),
                              boxShadow: [customeBoxShadow()],
                              borderRadius:
                                  BorderRadius.all(Radius.circular(5))),
                          margin: EdgeInsets.only(bottom: 8),
                          padding: EdgeInsets.all(8),
                          alignment: Alignment.center,
                          child: InkWell(
                            onTap: () async {
                              String result = await showMyDialog_end(
                                  context,
                                  deviceList[index].destName,
                                  // 'SENSOR_' +
                                  deviceList[index].deviceName,
                                  'SENSOR_' +
                                      deviceList[index].getserialNumber());
                              if (result == 'success') {
                                for (int k = 0;
                                    k < userList.userDevices.length;
                                    k++) {
                                  if (userList.userDevices[k].deviceNumber
                                          .substring(11) ==
                                      deviceList[index].getserialNumber()) {
                                    setState(() {
                                      // userList.userDevices.removeAt(k);
                                      userList.userDevices[k].status = 1;
                                      deviceList[index].status = 1;
                                    });
                                    break;
                                  }
                                }
                              } else if (result == 'return') {
                                deviceList[index].status = 2;

                                // if (deviceList[index].destName.substring(
                                //         deviceList[index].destName.length -
                                //             2) !=
                                //     '송)')
                                //   setState(() {
                                //     deviceList[index].destName += ' (회송)';
                                //   });
                              } else if (result == 'retrans') {
                                setState(() {
                                  deviceList[index].status = 3;
                                });
                              }
                            },
                            child: Text('종료', style: boldTextStyle),
                          ),
                        ))
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                      color: deviceList[index].status == 1
                          ? Color.fromRGBO(10, 10, 10, 0.4)
                          : deviceList[index].lastUpdateTime == null ||
                                  deviceList[index].lastUpdateTime.isBefore(
                                      DateTime.now()
                                          .toLocal()
                                          .subtract(Duration(minutes: 10)))
                              ? Color.fromRGBO(0x61, 0xB2, 0xD0, 1)
                              : Colors.white,
                      boxShadow: [customeBoxShadow()],
                      borderRadius: BorderRadius.all(Radius.circular(5))),
                  height: MediaQuery.of(context).size.height * 0.10,
                  width: MediaQuery.of(context).size.width * 0.99,
                  child: Column(children: [
                    Expanded(
                        flex: 4,
                        child: InkWell(
                          onTap: () async {},
                          child: Container(
                              padding: EdgeInsets.only(top: 5, left: 2),
                              width: MediaQuery.of(context).size.width * 0.98,
                              decoration: BoxDecoration(
                                  color: Color.fromRGBO(255, 255, 255, 0),
                                  //boxShadow: [customeBoxShadow()],
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(5))),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      Text(deviceList[index].deviceName,
                                          style: boldTextStyle),

                                      // Text(deviceList[index]
                                      //     .lastUpdateTime
                                      //     .toString()),
                                      // Image(
                                      //   image: AssetImage('images/T301.png'),
                                      //   fit: BoxFit.contain,
                                      //   width:
                                      //       MediaQuery.of(context).size.width * 0.10,
                                      //   height:
                                      //       MediaQuery.of(context).size.width * 0.10,
                                      // ),
                                      deviceList[index].lastUpdateTime ==
                                                  null ||
                                              deviceList[index]
                                                  .lastUpdateTime
                                                  .isBefore(DateTime.now()
                                                      .toLocal()
                                                      .subtract(
                                                          Duration(days: 200)))
                                          ? Text('최근 업로드 시간 : --일 --:--:--',
                                              style:
                                                  lastUpdateTextStyle(context))
                                          : Text(
                                              '최근 업로드 시간 : ' +
                                                  DateFormat('d일 HH:mm:ss')
                                                      .format(deviceList[index]
                                                          .lastUpdateTime),
                                              style:
                                                  lastUpdateTextStyle(context),
                                            ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      Text(
                                          deviceList[index].status == 1
                                              ? '운송완료'
                                              : strMapper(deviceList[index]
                                                  .connectionState),
                                          style: strMapper(deviceList[index]
                                                      .connectionState) ==
                                                  '대기 중'
                                              ? noboldTextStyle
                                              : redBoldTextStyle),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Image(
                                            image: AssetImage(
                                                'images/ic_thermometer.png'),
                                            fit: BoxFit.contain,
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.05,
                                            // height: MediaQuery.of(context).size.width * 0.1,
                                          ),
                                          Text(
                                            deviceList[index]
                                                    .getTemperature()
                                                    .toString() +
                                                '°C ',
                                            style: noboldTextStyle,
                                          ),
                                        ],
                                      ),
                                      // Row(
                                      //   mainAxisAlignment:
                                      //       MainAxisAlignment.center,
                                      //   children: [
                                      //     Image(
                                      //       image: AssetImage(
                                      //           'images/ic_humidity.png'),
                                      //       fit: BoxFit.contain,
                                      //       width: MediaQuery.of(context)
                                      //               .size
                                      //               .width *
                                      //           0.05,
                                      //       // height: MediaQuery.of(context).size.width * 0.1,
                                      //     ),
                                      //     Text(
                                      //       deviceList[index]
                                      //               .getHumidity()
                                      //               .toString() +
                                      //           '% ',
                                      //       style: noboldTextStyle,
                                      //     ),
                                      //   ],
                                      // ),
                                      Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            getbatteryImage(
                                                deviceList[index].getBattery()),
                                            Text(
                                              '  ' +
                                                  deviceList[index]
                                                      .getBattery()
                                                      .toString() +
                                                  '%',
                                              style: noboldTextStyle,
                                            ),
                                          ]),
                                    ],
                                  ),
                                ],
                              )),
                        )),
                  ]),
                )
              ],
            ),
          );
        },
        //12,13 온도
        separatorBuilder: (BuildContext context, int index) {
          return Divider(
            thickness: 3,
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    // print('가로 길이 : ' + MediaQuery.of(context).size.width.toString());
    // print('세로 길이 : ' + MediaQuery.of(context).size.height.toString());
    if (MediaQuery.of(context).size.height >
        MediaQuery.of(context).size.width) {
      return MaterialApp(
          builder: (context, child) {
            return MediaQuery(
              child: child,
              data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
            );
          },
          debugShowCheckedModeBanner: false,
          title: 'OPTILO',
          theme: ThemeData(
            // primarySwatch: Colors.grey,
            primaryColor: Color.fromRGBO(0x4C, 0xA5, 0xC7, 1),
            //canvasColor: Colors.nsparent,
          ),
          home: Scaffold(
            appBar: PreferredSize(
                preferredSize: Size.fromHeight(75.0), // here the desired height
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppBar(
                        // backgroundColor: Color.fromARGB(22, 27, 32, 1),
                        title: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Image(
                            image: AssetImage('images/geo_young.png'),
                            fit: BoxFit.contain,
                            // width: MediaQuery.of(context).size.width * 0.20,
                            height: 60,
                          ),
                        ),
                        Expanded(
                          flex: 8,
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image(
                                  image: AssetImage('images/logos.png'),
                                  fit: BoxFit.contain,
                                  width:
                                      MediaQuery.of(context).size.width * 0.4,
                                  // height: MediaQuery.of(context).size.width * 0.1,
                                ),
                              ]),
                        ),
                        Expanded(
                          flex: 4,
                          child: SizedBox(),
                        ),
                      ],
                    )),
                  ],
                )),
            body: WillPopScope(
                onWillPop: () {
                  return Future(() => false);
                },
                // <- Scaffold body만 감싼다.
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(240, 240, 240, 1),
                    boxShadow: [customeBoxShadow()],
                    //color: Color.fromRGBO(81, 97, 130, 1),
                  ),
                  child: Column(
                    children: <Widget>[
                      Expanded(
                          flex: 2,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(deviceList.length.toString() + '개 스캔 중   ',
                                  style: lastUpdateTextStyle(context)),
                            ],
                          )),
                      Expanded(
                          flex: 40,
                          child: Container(
                              // margin: EdgeInsets.only(
                              //     top: MediaQuery.of(context).size.width * 0.035),
                              width: MediaQuery.of(context).size.width * 0.98,
                              // height:
                              //     MediaQuery.of(context).size.width * 0.45,

                              child: beforeInit == false
                                  ? list()
                                  : getPhoneNumber()) //리스트 출력
                          ),
                      beforeInit == false
                          ? Expanded(
                              flex: 5,
                              child: Container(
                                  color: Color.fromRGBO(200, 200, 200, 1),
                                  // padding: EdgeInsets.only(
                                  //   bottom: MediaQuery.of(context).size.width * 0.015,
                                  // ),
                                  margin: EdgeInsets.only(
                                    top: MediaQuery.of(context).size.width *
                                        0.015,
                                    // bottom: MediaQuery.of(context).size.width * 0.015,
                                  ),
                                  // bottom: MediaQuery.of(context).size.width * 0.035),
                                  width:
                                      MediaQuery.of(context).size.width * 0.97,
                                  // height:
                                  //     MediaQuery.of(context).size.width * 0.45,

                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        resultText,
                                        style: boldTextStyle,
                                      ),
                                      FloatingActionButton(
                                        onPressed: () {
                                          FlutterAndroidPip
                                              .enterPictureInPictureMode;
                                        },
                                        child: Icon(
                                            Icons.branding_watermark_outlined),
                                      ),
                                    ],
                                  )) //리스트 출력
                              )
                          : SizedBox(),
                      Expanded(
                          flex: beforeInit == false ? 4 : 9,
                          child: Container(
                              // margin: EdgeInsets.only(
                              //   top: MediaQuery.of(context).size.width * 0.015,
                              //   bottom: MediaQuery.of(context).size.width * 0.01,
                              // ),
                              child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Image(
                                image: AssetImage('images/background3.png'),
                                fit: BoxFit.contain,
                                width: MediaQuery.of(context).size.width * 0.12,
                                // height: MediaQuery.of(context).size.width * 0.1,
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '(주)옵티로',
                                    style: boldTextStyle2,
                                  ),
                                  Text(
                                    '인천광역시 연수구 송도미래로 30 스마트밸리 D동',
                                    style: thinSmallTextStyle,
                                  ),
                                  Text(
                                    'H : www.optilo.net  T : 070-5143-8585',
                                    style: thinSmallTextStyle,
                                  ),
                                ],
                              )
                            ],
                          )) //리스트 출력
                          ),
                    ],
                  ),
                )),
          ));
    } else {
      return Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        color: Color.fromRGBO(15, 116, 187, 1),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              deviceList.length.toString() + '개 스캔 중',
              style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width / 11,
                  color: Colors.white,
                  decoration: TextDecoration.none),
            )
            // Text(
            //   resultText,
            //   style: TextStyle(
            //       fontSize: MediaQuery.of(context).size.width / 18,
            //       color: Colors.black),
            // ),
          ],
        ),
      );
    }
  }

  Widget getbatteryImage(int battery) {
    if (battery >= 75) {
      return Image(
        image: AssetImage('images/battery_100.png'),
        fit: BoxFit.contain,
        width: MediaQuery.of(context).size.width * 0.08,
        height: MediaQuery.of(context).size.width * 0.08,
      );
    } else if (battery >= 50) {
      return Image(
        image: AssetImage('images/battery_75.png'),
        fit: BoxFit.contain,
        width: MediaQuery.of(context).size.width * 0.08,
        height: MediaQuery.of(context).size.width * 0.08,
      );
    } else if (battery >= 35) {
      return Image(
        image: AssetImage('images/battery_50.png'),
        fit: BoxFit.contain,
        width: MediaQuery.of(context).size.width * 0.08,
        height: MediaQuery.of(context).size.width * 0.08,
      );
    } else if (battery >= 15)
      return Image(
        image: AssetImage('images/battery_25.png'),
        fit: BoxFit.contain,
        width: MediaQuery.of(context).size.width * 0.08,
        height: MediaQuery.of(context).size.width * 0.08,
      );
  }

  TextStyle lastUpdateTextStyle(BuildContext context) {
    return TextStyle(
      fontSize: MediaQuery.of(context).size.width / 26,
      color: Color.fromRGBO(5, 5, 5, 1),
      fontWeight: FontWeight.w700,
    );
  }

  TextStyle updateTextStyle(BuildContext context) {
    return TextStyle(
      fontSize: MediaQuery.of(context).size.width / 24,
      color: Color.fromRGBO(0xe8, 0x52, 0x55, 1),
      fontWeight: FontWeight.w500,
    );
  }

  TextStyle redBoldTextStyle = TextStyle(
    fontSize: 18,
    color: Color.fromRGBO(0xE0, 0x71, 0x51, 1),
    fontWeight: FontWeight.w900,
  );
  TextStyle boldTextStyle2 = TextStyle(
    fontSize: 18,
    color: Color.fromRGBO(21, 21, 21, 1),
    fontWeight: FontWeight.w800,
  );
  TextStyle boldTextStyle3 = TextStyle(
    fontSize: 30,
    color: Color.fromRGBO(21, 21, 21, 1),
    fontWeight: FontWeight.w800,
  );
  TextStyle boldTextStyle = TextStyle(
    fontSize: 22,
    color: Color.fromRGBO(21, 21, 21, 1),
    fontWeight: FontWeight.w800,
  );
  TextStyle noboldTextStyle = TextStyle(
    fontSize: 22,
    color: Color.fromRGBO(21, 21, 21, 1),
    fontWeight: FontWeight.w700,
  );
  TextStyle bigTextStyle(BuildContext context) {
    return TextStyle(
      fontSize: MediaQuery.of(context).size.width / 10,
      color: Color.fromRGBO(50, 50, 50, 1),
      fontWeight: FontWeight.w400,
    );
  }

  TextStyle thinSmallTextStyle = TextStyle(
    fontSize: 14,
    color: Color.fromRGBO(21, 21, 21, 1),
    fontWeight: FontWeight.w500,
  );
  TextStyle thinTextStyle = TextStyle(
    fontSize: 22,
    color: Color.fromRGBO(244, 244, 244, 1),
    fontWeight: FontWeight.w500,
  );

  BoxShadow customeBoxShadow() {
    return BoxShadow(
        color: Colors.black.withOpacity(0.2),
        offset: Offset(0, 1),
        blurRadius: 6);
  }

  TextStyle whiteTextStyle(BuildContext context) {
    return TextStyle(
      fontSize: MediaQuery.of(context).size.width / 18,
      color: Color.fromRGBO(255, 255, 255, 1),
      fontWeight: FontWeight.w500,
    );
  }

  TextStyle btnTextStyle = TextStyle(
    fontSize: 20,
    color: Color.fromRGBO(255, 255, 255, 1),
    fontWeight: FontWeight.w700,
  );

  Uint8List stringToBytes(String source) {
    var list = new List<int>();
    source.runes.forEach((rune) {
      if (rune >= 0x10000) {
        rune -= 0x10000;
        int firstWord = (rune >> 10) + 0xD800;
        list.add(firstWord >> 8);
        list.add(firstWord & 0xFF);
        int secondWord = (rune & 0x3FF) + 0xDC00;
        list.add(secondWord >> 8);
        list.add(secondWord & 0xFF);
      } else {
        list.add(rune >> 8);
        list.add(rune & 0xFF);
      }
    });
    return Uint8List.fromList(list);
  }

  String bytesToString(Uint8List bytes) {
    StringBuffer buffer = new StringBuffer();
    for (int i = 0; i < bytes.length;) {
      int firstWord = (bytes[i] << 8) + bytes[i + 1];
      if (0xD800 <= firstWord && firstWord <= 0xDBFF) {
        int secondWord = (bytes[i + 2] << 8) + bytes[i + 3];
        buffer.writeCharCode(
            ((firstWord - 0xD800) << 10) + (secondWord - 0xDC00) + 0x10000);
        i += 4;
      } else {
        buffer.writeCharCode(firstWord);
        i += 2;
      }
    }
    return buffer.toString();
  }

  _checkPermissionCamera() async {
    if (await Permission.camera.request().isGranted) {
      scan();
      return '';
    }
    Map<Permission, PermissionStatus> statuses =
        await [Permission.camera, Permission.storage].request();
    //print("여기는요?" + statuses[Permission.location].toString());
    if (statuses[Permission.camera].toString() == "PermissionStatus.granted" &&
        statuses[Permission.storage].toString() == 'PermissionStatus.granted') {
      scan();
      return 'Pass';
    }
  }

  getCurrentLocation() async {
    location = new loc.Location();
    bool _serviceEnabled;
    loc.PermissionStatus _permissionGranted;
    loc.LocationData _locationData;
    try {
      _serviceEnabled = await location.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await location.requestService();
        if (!_serviceEnabled) {
          print('error?');
          return;
        }
      }
    } catch (e) {
      _serviceEnabled = await location.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await location.requestService();
        if (!_serviceEnabled) {
          print('error?');
          return;
        }
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == loc.PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != loc.PermissionStatus.granted) {
        return;
      }
    }
    location.enableBackgroundMode(enable: false);
    _locationData = await location.getLocation();
    // print('lng: ' + _locationData.longitude.toString());
    // print('lat: ' + _locationData.latitude.toString());
    setState(() {
      currentLocation = _locationData;
    });

    location.onLocationChanged.listen((loc.LocationData tempcurrentLocation) {
      // print('lng: ' + tempcurrentLocation.longitude.toString());
      // print('lat: ' + tempcurrentLocation.latitude.toString());
      setState(() {
        currentLocation = tempcurrentLocation;
      });
    });
  }
}

showMyDialog_finishStart(BuildContext context, String deviceName) {
  bool manuallyClosed = false;
  Future.delayed(Duration(seconds: 2)).then((_) {
    if (!manuallyClosed) {
      Navigator.of(context).pop();
    }
  });
  return showDialog(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
        backgroundColor: Color.fromRGBO(0x61, 0xB2, 0xD0, 1),
        // elevation: 16.0,
        child: Container(
            width: MediaQuery.of(context).size.width / 3,
            height: MediaQuery.of(context).size.height / 3.5,
            padding: EdgeInsets.all(10.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Icon(
                        Icons.check_box,
                        color: Colors.white,
                        size: MediaQuery.of(context).size.width / 5,
                      ),
                      Text(deviceName,
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 20)),
                      Text("운송이 시작되었습니다. ",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 18),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ],
            )),
      );
    },
  );
}

returnYesOrNoDialog(BuildContext context) {
  return showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('회송'),
          content: Text('회송 처리 하시겠습니까 ?'),
          actions: <Widget>[
            TextButton(
                child: Text('확인'),
                onPressed: () {
                  Navigator.pop(context, 1);
                  // print(savedList);
                }),
            TextButton(
              child: Text('취소'),
              onPressed: () {
                Navigator.pop(context, 0);
              },
            ),
          ],
        );
      });
}

ReTransportYesOrNoDialog(BuildContext context) {
  return showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('재배송'),
          content: Text('재배송 처리 하시겠습니까 ?'),
          actions: <Widget>[
            TextButton(
                child: Text('확인'),
                onPressed: () {
                  Navigator.pop(context, 1);
                  // print(savedList);
                }),
            TextButton(
              child: Text('취소'),
              onPressed: () {
                Navigator.pop(context, 0);
              },
            ),
          ],
        );
      });
}

EndYesOrNoDialog(BuildContext context) {
  return showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('배송완료'),
          content: Text('배송완료 처리 하시겠습니까 ?'),
          actions: <Widget>[
            TextButton(
                child: Text('확인'),
                onPressed: () {
                  Navigator.pop(context, 1);
                  // print(savedList);
                }),
            TextButton(
              child: Text('취소'),
              onPressed: () {
                Navigator.pop(context, 0);
              },
            ),
          ],
        );
      });
}

showMyDialog_Connecting(BuildContext context) {
  bool manuallyClosed = false;
  Future.delayed(Duration(seconds: 2)).then((_) {
    if (!manuallyClosed) {
      Navigator.of(context).pop();
    }
  });
  return showDialog(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
        backgroundColor: Color.fromRGBO(0x61, 0xB2, 0xD0, 1),
        elevation: 16.0,
        child: Container(
            width: MediaQuery.of(context).size.width / 3,
            height: MediaQuery.of(context).size.height / 4,
            padding: EdgeInsets.all(10.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Icon(
                        Icons.bluetooth,
                        color: Colors.white,
                        size: MediaQuery.of(context).size.width / 5,
                      ),
                      Text("데이터 전송을 시작합니다 !",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 18),
                          textAlign: TextAlign.center),
                      Text("로딩이 되지 않으면 다시 눌러주세요.",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ],
            )),
      );
    },
  );
}

showMyDialog_end(
    BuildContext context, String destName, String de_name, String devicename) {
  DateTime now = DateTime.now().toLocal();
  return showDialog(
    // barrierDismissible: false,
    context: context,
    builder: (context) {
      return Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
        backgroundColor: Color.fromRGBO(0x61, 0xB2, 0xD0, 1),
        elevation: 16.0,
        child: Container(
          width: MediaQuery.of(context).size.width / 2,
          height: MediaQuery.of(context).size.height / 4,
          padding: EdgeInsets.all(10.0),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            offset: Offset(0, 1),
                            blurRadius: 6)
                      ],
                      borderRadius: BorderRadius.all(Radius.circular(5))),
                  padding: EdgeInsets.all(8),
                  alignment: Alignment.center,
                  child: Text(destName + ' ' + de_name),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        InkWell(
                          onTap: () async {
                            int result = await returnYesOrNoDialog(context);
                            if (result == 1) {
                              Socket socket =
                                  await Socket.connect('175.126.232.236', 9982);
                              if (socket != null) {
                                String body = '';
                                body += devicename +
                                    '||' +
                                    now.toString() +
                                    '|' +
                                    now.toString() +
                                    '||' +
                                    '||' +
                                    '|' +
                                    '9999|' +
                                    '9999||||' +
                                    '|2'
                                        ';';
                                socket.write(body);
                                print('connected server & Sended to server');
                                socket.close();

                                Navigator.of(context).pop('return');
                              } else {
                                print('Fail Send to Server');
                                Navigator.of(context).pop('fail');
                              }
                            }
                          },
                          //TODO: 1 -> 배송완료 / 2 -> 회송 / 3-> 전송중
                          child: Container(
                            decoration: BoxDecoration(
                                color: Colors.red,
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      offset: Offset(0, 1),
                                      blurRadius: 6)
                                ],
                                borderRadius:
                                    BorderRadius.all(Radius.circular(5))),
                            width: MediaQuery.of(context).size.width / 4,
                            height: MediaQuery.of(context).size.width / 8,
                            padding: EdgeInsets.all(8),
                            alignment: Alignment.center,
                            child: Text(
                              '회송',
                              style: TextStyle(
                                fontSize: 20,
                                color: Color.fromRGBO(244, 244, 244, 1),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () async {
                            int result =
                                await ReTransportYesOrNoDialog(context);
                            if (result == 1) {
                              Navigator.of(context).pop('retrans');
                            } else {
                              // Navigator.of(context).pop('fail');
                            }
                          },
                          //TODO: 1 -> 배송완료 / 2 -> 회송 / 3-> 전송중
                          child: Container(
                            decoration: BoxDecoration(
                                color: Colors.blue,
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      offset: Offset(0, 1),
                                      blurRadius: 6)
                                ],
                                borderRadius:
                                    BorderRadius.all(Radius.circular(5))),
                            width: MediaQuery.of(context).size.width / 4,
                            height: MediaQuery.of(context).size.width / 8,
                            padding: EdgeInsets.all(8),
                            alignment: Alignment.center,
                            child: Text(
                              '재배송',
                              style: TextStyle(
                                fontSize: 20,
                                color: Color.fromRGBO(244, 244, 244, 1),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                        onTap: () async {
                          int result = await EndYesOrNoDialog(context);
                          if (result == 1) {
                            Socket socket =
                                await Socket.connect('175.126.232.236', 9982);
                            if (socket != null) {
                              String body = '';
                              body += devicename +
                                  '||' +
                                  now.toString() +
                                  '|' +
                                  now.toString() +
                                  '||' +
                                  '||' +
                                  '|' +
                                  '9999|' +
                                  '9999||||' +
                                  '|1'
                                      ';';
                              socket.write(body);
                              print('connected server & Sended to server');
                              socket.close();

                              Navigator.of(context).pop('success');
                            } else {
                              print('Fail Send to Server');
                              Navigator.of(context).pop('fail');
                            }
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                              color: Colors.green,
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    offset: Offset(0, 1),
                                    blurRadius: 6)
                              ],
                              borderRadius:
                                  BorderRadius.all(Radius.circular(5))),
                          width: MediaQuery.of(context).size.width / 4,
                          height: MediaQuery.of(context).size.width / 4,
                          padding: EdgeInsets.all(8),
                          margin: EdgeInsets.only(bottom: 4),
                          alignment: Alignment.center,
                          child: Text(
                            // 색상 변환 -> 회 완료
                            '운송완료',
                            style: TextStyle(
                              fontSize: 20,
                              color: Color.fromRGBO(244, 244, 244, 1),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )),
                  ],
                )
              ]),
        ),
      );
    },
  );
}

//Datalog Parsing
LogData transformData(Uint8List notifyResult) {
  return new LogData(
      temperature: getLogTemperature(notifyResult),
      humidity: getLogHumidity(notifyResult),
      timestamp: getLogTime(notifyResult));
}

getLogTime(Uint8List fetchData) {
  int tmp =
      ByteData.sublistView(fetchData.sublist(12, 16)).getInt32(0, Endian.big);
  DateTime time = DateTime.fromMillisecondsSinceEpoch(tmp * 1000, isUtc: true);

  return time;
}

getLogHumidity(Uint8List fetchData) {
  int tmp =
      ByteData.sublistView(fetchData.sublist(18, 20)).getInt16(0, Endian.big);

  return tmp / 100;
}

getLogTemperature(Uint8List fetchData) {
  int tmp =
      ByteData.sublistView(fetchData.sublist(16, 18)).getInt16(0, Endian.big);

  return tmp / 100;
}

threeBytesToint(Uint8List temp) {
  int r = ((temp[0] & 0xF) << 16) | ((temp[1] & 0xFF) << 8) | (temp[2] & 0xFF);
  return r;
}

intToThreeBytes(int myInt) {
  Uint8List result = Uint8List.fromList([
    (myInt << 16) & 0xFF,
    (myInt << 8) & 0xFF,
    myInt & 0xFF,
  ]);
  return result;
}
