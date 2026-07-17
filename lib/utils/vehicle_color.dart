import 'package:flutter/material.dart';

Color parseVehicleColor(String name) {
  const colors = {
    'red': Colors.red,
    'blue': Colors.blue,
    'green': Colors.green,
    'black': Colors.black87,
    'white': Colors.grey,
    'silver': Colors.blueGrey,
    'gray': Colors.grey,
    'grey': Colors.grey,
    'yellow': Colors.amber,
    'orange': Colors.orange,
  };
  return colors[name.toLowerCase()] ?? Colors.indigo;
}
