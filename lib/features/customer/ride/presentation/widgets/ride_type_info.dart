import 'package:flutter/material.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/customer/ride/domain/entities/ride.dart';

class RideTypeInfo {
  const RideTypeInfo({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
  });

  final RideType type;
  final String name;
  final String description;
  final IconData icon;

  static RideTypeInfo of(RideType type, AppLocalizations l10n) {
    switch (type) {
      case RideType.economy:
        return RideTypeInfo(
          type: type,
          name: l10n.rideEconomy,
          description: l10n.rideEconomyDesc,
          icon: Icons.directions_car_rounded,
        );
      case RideType.comfort:
        return RideTypeInfo(
          type: type,
          name: l10n.rideComfort,
          description: l10n.rideComfortDesc,
          icon: Icons.airline_seat_recline_extra_rounded,
        );
      case RideType.premium:
        return RideTypeInfo(
          type: type,
          name: l10n.ridePremium,
          description: l10n.ridePremiumDesc,
          icon: Icons.stars_rounded,
        );
      case RideType.xl:
        return RideTypeInfo(
          type: type,
          name: l10n.rideXL,
          description: l10n.rideXLDesc,
          icon: Icons.airport_shuttle_rounded,
        );
      case RideType.motorbike:
        return RideTypeInfo(
          type: type,
          name: l10n.rideMotorbike,
          description: l10n.rideMotorbikeDesc,
          icon: Icons.two_wheeler_rounded,
        );
      case RideType.taxi:
        return RideTypeInfo(
          type: type,
          name: l10n.rideTaxi,
          description: l10n.rideTaxiDesc,
          icon: Icons.local_taxi_rounded,
        );
    }
  }
}
