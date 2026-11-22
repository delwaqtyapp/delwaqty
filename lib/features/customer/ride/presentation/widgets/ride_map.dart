import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RideMap extends StatefulWidget {
  const RideMap({
    required this.pickup,
    this.dropoff,
    this.driver,
    this.height = 200,
    this.webFallbackText,
    super.key,
  });

  final LatLng pickup;
  final LatLng? dropoff;
  final LatLng? driver;
  final double height;

  /// Web-only override for the no-map fallback message (driver pages show
  /// ride-specific copy instead of the address-picker text).
  final String? webFallbackText;

  @override
  State<RideMap> createState() => _RideMapState();
}

class _RideMapState extends State<RideMap> {
  final Completer<GoogleMapController> _controller = Completer();

  @override
  void didUpdateWidget(covariant RideMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pickup != widget.pickup ||
        oldWidget.dropoff != widget.dropoff ||
        oldWidget.driver != widget.driver) {
      _fitBounds();
    }
  }

  Future<void> _fitBounds() async {
    if (!_controller.isCompleted) return;
    final controller = await _controller.future;
    final points = <LatLng>[
      widget.pickup,
      if (widget.dropoff != null) widget.dropoff!,
      if (widget.driver != null) widget.driver!,
    ];
    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 15),
      );
      return;
    }
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  @override
  Widget build(BuildContext context) {
    // google_maps_flutter_web crashes hard ("Null check operator used on a
    // null value") when no Maps JS API key is loaded; web/index.html ships
    // none, so show the same graceful fallback the map picker uses.
    if (kIsWeb) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.d20),
        child: Container(
          height: widget.height,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                widget.webFallbackText ??
                    AppLocalizations.of(context).mapUnavailableOnWeb,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ),
      );
    }
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('pickup'),
        position: widget.pickup,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      if (widget.dropoff != null)
        Marker(
          markerId: const MarkerId('dropoff'),
          position: widget.dropoff!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      if (widget.driver != null)
        Marker(
          markerId: const MarkerId('driver'),
          position: widget.driver!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
    };

    final polylines = <Polyline>{};
    if (widget.dropoff != null) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: [widget.pickup, widget.dropoff!],
          color: Theme.of(context).colorScheme.primary,
          width: 4,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: widget.height,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: widget.pickup,
            zoom: 14,
          ),
          markers: markers,
          polylines: polylines,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: false,
          mapToolbarEnabled: false,
          onMapCreated: (c) {
            if (!_controller.isCompleted) _controller.complete(c);
            _fitBounds();
          },
        ),
      ),
    );
  }
}
