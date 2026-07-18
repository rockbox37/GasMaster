import 'dart:io';

import 'package:flutter/material.dart';
import '../models/vehicle.dart';
import '../services/vehicle_photo_service.dart';
import '../utils/vehicle_color.dart';

class VehicleAvatar extends StatelessWidget {
  final Vehicle vehicle;
  final double radius;

  const VehicleAvatar({super.key, required this.vehicle, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final path = vehicle.photoPath;
    if (path == null || path.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: parseVehicleColor(vehicle.color),
        child: Icon(Icons.directions_car, color: Colors.white, size: radius),
      );
    }

    return FutureBuilder<String>(
      future: VehiclePhotoService.absolutePath(path),
      builder: (context, snap) {
        final abs = snap.data;
        if (abs == null || !File(abs).existsSync()) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: parseVehicleColor(vehicle.color),
            child: Icon(Icons.directions_car, color: Colors.white, size: radius),
          );
        }
        return CircleAvatar(
          radius: radius,
          backgroundColor: parseVehicleColor(vehicle.color),
          backgroundImage: FileImage(File(abs)),
        );
      },
    );
  }
}
