import 'package:flutter/material.dart';

class TurnInstruction {
  final IconData icon;
  final String action; // ngắn: "Rẽ phải vào"
  final String streetName;
  final int distanceMeters;
  final String? nextHint;

  const TurnInstruction({
    required this.icon,
    required this.action,
    required this.streetName,
    required this.distanceMeters,
    this.nextHint,
  });
}

/// Cyclic mock instructions shown on the Navigation screen every 4-5s.
/// Order is meaningful: assumes the driver heads toward downtown Đà Nẵng.
const List<TurnInstruction> kTurnInstructions = [
  TurnInstruction(
    icon: Icons.turn_right,
    action: 'Rẽ phải vào',
    streetName: 'Nguyễn Văn Linh',
    distanceMeters: 250,
    nextHint: 'Đi thẳng 1.4 km',
  ),
  TurnInstruction(
    icon: Icons.arrow_upward,
    action: 'Đi thẳng',
    streetName: 'Nguyễn Văn Linh',
    distanceMeters: 1400,
    nextHint: 'Rẽ trái vào Trường Sa',
  ),
  TurnInstruction(
    icon: Icons.turn_left,
    action: 'Rẽ trái vào',
    streetName: 'Trường Sa',
    distanceMeters: 80,
    nextHint: 'Tiếp tục 600 m',
  ),
  TurnInstruction(
    icon: Icons.directions_car,
    action: 'Tiếp tục thẳng',
    streetName: 'Trường Sa',
    distanceMeters: 600,
    nextHint: 'Sắp đến nơi',
  ),
];
