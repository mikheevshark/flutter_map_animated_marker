import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animated_marker/flutter_map_animated_marker.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final StreamController<LatLng> currentPointStreamController =
      StreamController.broadcast();

  late final AnimatedMapController mapController =
      AnimatedMapController(vsync: this);

  late final routePoints = MapboxRouteService.decode(geometry)
      .map((e) => LatLng(e[0].toDouble(), e[1].toDouble()))
      .toList();
  int index = 0;

  @override
  void initState() {
    super.initState();
    Timer.periodic(Duration(milliseconds: 300), (timer) {
      if (index < routePoints.length - 1) {
        index++;
      } else {
        index = 0;
      }
      currentPointStreamController.add(routePoints[index]);
    });
  }

  @override
  void dispose() {
    currentPointStreamController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
          center: LatLng(51.509364, -0.128928),
          zoom: 9.2,
          plugins: [AnimatedMarkerPlugin()]),
      children: [
        TileLayerWidget(
          options: TileLayerOptions(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
          ),
        ),
        AnimatedMarkerLayerWidget(
          options: AnimatedMarkerLayerOptions(
            marker: Marker(
              point: LatLng(0, 0),
              builder: (context) => FlutterLogo(),
            ),
          ),
        ),
      ],
    );
  }
}

const geometry =
    "cytoS}~}mjEsC_CwOuMsFsEeNuL{FqF}CwCgM}L{PgP}A}AgOqNsGiGiDaD_KmJcOkN{NeNmEcEcQiPgJuIgUiTq_@c]}RmQiEyDeEuDkE}Dia@__@_SoQq`@{_@lAsC^cDGkCi@kC{@eBeBmBcEkBgGYiDp@oE|CeOcQuBcCw@sD_l@ci@s_B{zAy|AiyAgMuLgUiT}CyCyRoQ_[_YkGgGaLwKiBgBoBmBgMqLaQ_PcRwPaLaK}NoLiWqUuB}Ju@}LxRyf@dMw[nKgYff@qeAfXgk@hDsDzHiB`CT|Bc@bAu@r@kAXiCQuAkAoBkB}@gCG_Cv@{i@cbAuKuQuGuK}RqZeq@xx@_aAdlAgTjX";

class MapboxRouteService {
  MapboxRouteService._();

  static int _py2Round(num value) {
    return (value.abs() + 0.5).floor() * (value >= 0 ? 1 : -1);
  }

  static String _encode(num current, num previous, num factor) {
    current = _py2Round(current * factor);
    previous = _py2Round(previous * factor);
    IntX coordinate = Int32(current.toInt()) - Int32(previous.toInt());
    coordinate <<= 1;
    if (current - previous < 0) {
      coordinate = ~coordinate;
    }
    var output = "";
    while (coordinate >= Int32(0x20)) {
      try {
        IntX v = (Int32(0x20) | (coordinate & Int32(0x1f))) + 63;
        output += String.fromCharCodes([v.toInt()]);
      } catch (err) {
        print(err);
      }
      coordinate >>= 5;
    }
    output += ascii.decode([coordinate.toInt() + 63]);
    return output;
  }

  static List<List<num>> decode(String str, {int precision = 6}) {
    final List<List<num>> coordinates = [];

    int index = 0,
        lat = 0,
        lng = 0,
        shift = 0,
        result = 0,
        latitudeChange,
        longitudeChange;
    num factor = math.pow(10, precision);

    int? byte;

    // Coordinates have variable length when encoded, so just keep
    // track of whether we've hit the end of the string. In each
    // loop iteration, a single coordinate is decoded.
    while (index < str.length) {
      // Reset shift, result, and byte
      byte = null;
      shift = 0;
      result = 0;

      do {
        byte = str.codeUnitAt(index++) - 63;
        result |= ((Int32(byte) & Int32(0x1f)) << shift).toInt();
        shift += 5;
      } while (byte >= 0x20);

      latitudeChange =
          ((result & 1) != 0 ? ~(Int32(result) >> 1) : (Int32(result) >> 1))
              .toInt();

      shift = result = 0;

      do {
        byte = str.codeUnitAt(index++) - 63;
        result |= ((Int32(byte) & Int32(0x1f)) << shift).toInt();
        shift += 5;
      } while (byte >= 0x20);

      longitudeChange =
          ((result & 1) != 0 ? ~(Int32(result) >> 1) : (Int32(result) >> 1))
              .toInt();

      lat += latitudeChange;
      lng += longitudeChange;

      coordinates.add([lat / factor, lng / factor]);
    }

    return coordinates;
  }

  static String encode(List<List<num>> coordinates, {int precision = 5}) {
    if (coordinates.isEmpty) {
      return "";
    }

    var factor = math.pow(10, precision),
        output = _encode(coordinates[0][0], 0, factor) +
            _encode(coordinates[0][1], 0, factor);

    for (var i = 1; i < coordinates.length; i++) {
      var a = coordinates[i], b = coordinates[i - 1];
      output += _encode(a[0], b[0], factor);
      output += _encode(a[1], b[1], factor);
    }

    return output;
  }
}
