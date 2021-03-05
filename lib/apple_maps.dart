import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class AppleMapsController {
  AppleMapsController._(
    this.channel,
    CameraPosition initialCameraPosition,
    this._appleMapState,
  ) {
    channel.setMethodCallHandler(_handleMethodCall);
  }

  static Future<AppleMapsController> init(
    int id,
    CameraPosition initialCameraPosition,
    _AppleMapState appleMapState,
  ) async {
    final MethodChannel channel = MethodChannel('com.sgbasaraner.github/apple_maps_$id');
    // await channel.invokeMethod<void>('map#waitForMap');
    return AppleMapsController._(
      channel,
      initialCameraPosition,
      appleMapState,
    );
  }

  @visibleForTesting
  final MethodChannel channel;

  final _AppleMapState _appleMapState;

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'camera#onMoveStarted':
        _appleMapState.widget.onCameraMoveStarted?.call();
        break;
      case 'camera#onIdle':
        _appleMapState.widget.onCameraIdle?.call();
        break;
      default:
        throw MissingPluginException();
    }
  }

  /// Updates configuration options of the map user interface.
  ///
  /// Change listeners are notified once the update has been made on the
  /// platform side.
  ///
  /// The returned [Future] completes after listeners have been notified.
  Future<void> _updateMapOptions(Map<String, dynamic> optionsUpdate) async {
    await channel.invokeMethod<void>(
      'map#update',
      <String, dynamic>{
        'options': optionsUpdate,
      },
    );
  }

  /// Starts an animated change of the map camera position.
  ///
  /// The returned [Future] completes after the change has been started on the
  /// platform side.
  Future<void> animateCamera(CameraUpdate cameraUpdate) async {
    await channel.invokeMethod<void>('camera#animate', <String, dynamic>{
      'cameraUpdate': cameraUpdate._toJson(),
    });
  }

  /// Changes the map camera position.
  ///
  /// The returned [Future] completes after the change has been made on the
  /// platform side.
  Future<void> moveCamera(CameraUpdate cameraUpdate) async {
    await channel.invokeMethod<void>('camera#move', <String, dynamic>{
      'cameraUpdate': cameraUpdate._toJson(),
    });
  }
}

/// The position of the map "camera", the view point from which the world is
/// shown in the map view. Aggregates the camera's [target] geographical
/// location, its [zoom] level, [pitch] angle, and [heading].
class CameraPosition {
  const CameraPosition({
    required this.target,
    this.heading = 0.0,
    this.pitch = 0.0,
    this.zoom = 0,
  });

  /// The camera's bearing in degrees, measured clockwise from north.
  ///
  /// A bearing of 0.0, the default, means the camera points north.
  /// A bearing of 90.0 means the camera points east.
  final double heading;

  /// The geographical location that the camera is pointing at.
  final LatLng target;

  // In degrees where 0 is looking straight down. Pitch may be clamped to an appropriate value.
  final double pitch;

  /// The zoom level of the camera.
  ///
  /// A zoom of 0.0, the default, means the screen width of the world is 256.
  /// Adding 1.0 to the zoom level doubles the screen width of the map. So at
  /// zoom level 3.0, the screen width of the world is 2³x256=2048.
  ///
  /// Larger zoom levels thus means the camera is placed closer to the surface
  /// of the Earth, revealing more detail in a narrower geographical region.
  ///
  /// The supported zoom level range depends on the map data and device. Values
  /// beyond the supported range are allowed, but on applying them to a map they
  /// will be silently clamped to the supported range.
  final double zoom;

  dynamic _toMap() => <String, dynamic>{
        'target': target._toJson(),
        'heading': heading,
        'pitch': pitch,
        'zoom': zoom,
      };

  @visibleForTesting
  static CameraPosition? fromMap(dynamic json) {
    if (json == null) {
      return null;
    }
    final target = LatLng._fromJson(json['target']);
    if (target == null) return null;
    return CameraPosition(
      heading: json['heading'],
      target: target,
      pitch: json['pitch'],
      zoom: json['zoom'],
    );
  }

  @override
  bool operator ==(dynamic other) {
    if (identical(this, other)) return true;
    if (runtimeType != other.runtimeType) return false;
    final CameraPosition typedOther = other;
    return heading == typedOther.heading &&
        target == typedOther.target &&
        pitch == typedOther.pitch &&
        zoom == typedOther.zoom;
  }

  @override
  int get hashCode => hashValues(heading, target, pitch, zoom);

  @override
  String toString() => 'CameraPosition(bearing: $heading, target: $target, tilt: $pitch, zoom: $zoom)';
}

/// Defines a camera move, supporting absolute moves as well as moves relative
/// the current position.
class CameraUpdate {
  CameraUpdate._(this._json);

  /// Returns a camera update that moves the camera to the specified position.
  static CameraUpdate newCameraPosition(CameraPosition cameraPosition) {
    return CameraUpdate._(
      <dynamic>['newCameraPosition', cameraPosition._toMap()],
    );
  }

  /// Returns a camera update that moves the camera target to the specified
  /// geographical location.
  static CameraUpdate newLatLng(LatLng latLng) {
    return CameraUpdate._(<dynamic>['newLatLng', latLng._toJson()]);
  }

  /// Returns a camera update that moves the camera target to the specified
  /// geographical location and zoom level.
  static CameraUpdate newLatLngZoom(LatLng latLng, double zoom) {
    return CameraUpdate._(
      <dynamic>['newLatLngZoom', latLng._toJson(), zoom],
    );
  }

  /// Returns a camera update that modifies the camera zoom level by the
  /// specified amount. The optional [focus] is a screen point whose underlying
  /// geographical location should be invariant, if possible, by the movement.
  static CameraUpdate zoomBy(double amount, [Offset? focus]) {
    if (focus == null) {
      return CameraUpdate._(<dynamic>['zoomBy', amount]);
    } else {
      return CameraUpdate._(<dynamic>[
        'zoomBy',
        amount,
        <double>[focus.dx, focus.dy],
      ]);
    }
  }

  /// Returns a camera update that zooms the camera in, bringing the camera
  /// closer to the surface of the Earth.
  ///
  /// Equivalent to the result of calling `zoomBy(1.0)`.
  static CameraUpdate zoomIn() {
    return CameraUpdate._(<dynamic>['zoomIn']);
  }

  /// Returns a camera update that zooms the camera out, bringing the camera
  /// further away from the surface of the Earth.
  ///
  /// Equivalent to the result of calling `zoomBy(-1.0)`.
  static CameraUpdate zoomOut() {
    return CameraUpdate._(<dynamic>['zoomOut']);
  }

  /// Returns a camera update that sets the camera zoom level.
  static CameraUpdate zoomTo(double zoom) {
    return CameraUpdate._(<dynamic>['zoomTo', zoom]);
  }

  final dynamic _json;

  dynamic _toJson() => _json;
}

/// A pair of latitude and longitude coordinates, stored as degrees.
class LatLng {
  /// Creates a geographical location specified in degrees [latitude] and
  /// [longitude].
  ///
  /// The latitude is clamped to the inclusive interval from -90.0 to +90.0.
  ///
  /// The longitude is normalized to the half-open interval from -180.0
  /// (inclusive) to +180.0 (exclusive)
  const LatLng(double latitude, double longitude)
      : latitude = (latitude < -90.0 ? -90.0 : (90.0 < latitude ? 90.0 : latitude)),
        longitude = (longitude + 180.0) % 360.0 - 180.0;

  /// The latitude in degrees between -90.0 and 90.0, both inclusive.
  final double latitude;

  /// The longitude in degrees between -180.0 (inclusive) and 180.0 (exclusive).
  final double longitude;

  dynamic _toJson() {
    return <double>[latitude, longitude];
  }

  static LatLng? _fromJson(dynamic json) {
    if (json == null) {
      return null;
    }
    return LatLng(json[0], json[1]);
  }

  @override
  String toString() => '$runtimeType($latitude, $longitude)';

  @override
  bool operator ==(Object o) {
    if (identical(this, o)) return true;

    return o is LatLng && o.latitude == latitude && o.longitude == longitude;
  }

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}

/// A latitude/longitude aligned rectangle.
///
/// The rectangle conceptually includes all points (lat, lng) where
/// * lat ∈ [`southwest.latitude`, `northeast.latitude`]
/// * lng ∈ [`southwest.longitude`, `northeast.longitude`],
///   if `southwest.longitude` ≤ `northeast.longitude`,
/// * lng ∈ [-180, `northeast.longitude`] ∪ [`southwest.longitude`, 180[,
///   if `northeast.longitude` < `southwest.longitude`
class LatLngBounds {
  /// Creates geographical bounding box with the specified corners.
  ///
  /// The latitude of the southwest corner cannot be larger than the
  /// latitude of the northeast corner.
  LatLngBounds({required this.southwest, required this.northeast}) : assert(southwest.latitude <= northeast.latitude);

  /// The southwest corner of the rectangle.
  final LatLng southwest;

  /// The northeast corner of the rectangle.
  final LatLng northeast;

  /// Returns whether this rectangle contains the given [LatLng].
  bool contains(LatLng point) {
    return _containsLatitude(point.latitude) && _containsLongitude(point.longitude);
  }

  bool _containsLatitude(double lat) {
    return (southwest.latitude <= lat) && (lat <= northeast.latitude);
  }

  bool _containsLongitude(double lng) {
    if (southwest.longitude <= northeast.longitude) {
      return southwest.longitude <= lng && lng <= northeast.longitude;
    } else {
      return southwest.longitude <= lng || lng <= northeast.longitude;
    }
  }

  @visibleForTesting
  static LatLngBounds? fromList(dynamic json) {
    if (json == null) {
      return null;
    }
    final sw = LatLng._fromJson(json[0]);
    final ne = LatLng._fromJson(json[1]);
    if (sw == null || ne == null) return null;

    return LatLngBounds(
      southwest: sw,
      northeast: ne,
    );
  }

  @override
  String toString() {
    return '$runtimeType($southwest, $northeast)';
  }

  @override
  bool operator ==(Object o) {
    if (identical(this, o)) return true;

    return o is LatLngBounds && o.southwest == southwest && o.northeast == northeast;
  }

  @override
  int get hashCode => southwest.hashCode ^ northeast.hashCode;
}

typedef void MapCreatedCallback(AppleMapsController controller);

/// Callback that receives updates to the camera position.
///
/// This callback is triggered when the platform Apple Map
/// registers a camera movement.
///
/// This is used in [AppleMap.onCameraMove].
typedef void CameraPositionCallback(CameraPosition position);

class AppleMap extends StatefulWidget {
  const AppleMap({
    Key? key,
    required this.initialCameraPosition,
    required this.onMapCreated,
    this.compassEnabled = true,
    this.trafficEnabled = false,
    this.mapType = MapType.standard,
    this.minMaxZoomPreference = MinMaxZoomPreference.unbounded,
    this.trackingMode = TrackingMode.none,
    this.rotateGesturesEnabled = true,
    this.scrollGesturesEnabled = true,
    this.zoomGesturesEnabled = true,
    this.pitchGesturesEnabled = true,
    this.myLocationEnabled = false,
    this.myLocationButtonEnabled = false,
    this.padding = EdgeInsets.zero,
    this.onCameraMoveStarted,
    this.onCameraIdle,
  }) : super(key: key);

  final MapCreatedCallback onMapCreated;

  /// The initial position of the map's camera.
  final CameraPosition initialCameraPosition;

  /// True if the map should show a compass when rotated.
  final bool compassEnabled;

  /// True if the map should display the current traffic.
  final bool trafficEnabled;

  /// Type of map tiles to be rendered.
  final MapType mapType;

  /// The mode used to track the user location.
  final TrackingMode trackingMode;

  /// Preferred bounds for the camera zoom level.
  ///
  /// Actual bounds depend on map data and device.
  final MinMaxZoomPreference minMaxZoomPreference;

  /// True if the map view should respond to rotate gestures.
  final bool rotateGesturesEnabled;

  /// True if the map view should respond to scroll gestures.
  final bool scrollGesturesEnabled;

  /// True if the map view should respond to zoom gestures.
  final bool zoomGesturesEnabled;

  /// True if the map view should respond to tilt gestures.
  final bool pitchGesturesEnabled;

  /// Called when the camera starts moving.
  ///
  /// This can be initiated by the following:
  /// 1. Non-gesture animation initiated in response to user actions.
  ///    For example: zoom buttons, my location button, or annotation clicks.
  /// 2. Programmatically initiated animation.
  /// 3. Camera motion initiated in response to user gestures on the map.
  ///    For example: pan, tilt, pinch to zoom, or rotate.
  final VoidCallback? onCameraMoveStarted;

  /// Called when camera movement has ended, there are no pending
  /// animations and the user has stopped interacting with the map.
  final VoidCallback? onCameraIdle;

  /// True if a "My Location" layer should be shown on the map.
  ///
  /// This layer includes a location indicator at the current device location,
  /// as well as a My Location button.
  /// * The indicator is a small blue dot if the device is stationary, or a
  /// chevron if the device is moving.
  /// * The My Location button animates to focus on the user's current location
  /// if the user's location is currently known.
  ///
  /// Enabling this feature requires adding location permissions to both native
  /// platforms of your app.
  /// * On iOS add a `NSLocationWhenInUseUsageDescription` key to your
  /// `Info.plist` file. This will automatically prompt the user for permissions
  /// when the map tries to turn on the My Location layer.
  final bool myLocationEnabled;

  /// Enables or disables the my-location button.
  ///
  /// The my-location button causes the camera to move such that the user's
  /// location is in the center of the map. If the button is enabled, it is
  /// only shown when the my-location layer is enabled.
  ///
  /// By default, the my-location button is enabled (and hence shown when the
  /// my-location layer is enabled).
  ///
  /// See also:
  ///   * [myLocationEnabled] parameter.
  final bool myLocationButtonEnabled;

  /// The padding used on the map
  ///
  /// The amount of additional space (measured in screen points) used for padding for the
  /// native controls.
  final EdgeInsets padding;

  @override
  State createState() => _AppleMapState();
}

class _AppleMapState extends State<AppleMap> {
  final Completer<AppleMapsController> _controller = Completer<AppleMapsController>();

  late _AppleMapOptions _appleMapOptions;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> creationParams = <String, dynamic>{
      'initialCameraPosition': widget.initialCameraPosition._toMap(),
      'options': _appleMapOptions.toMap(),
    };
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: 'com.sgbasaraner.github/apple_maps',
        onPlatformViewCreated: onPlatformViewCreated,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    return Text('$defaultTargetPlatform is not yet supported by the apple maps plugin');
  }

  @override
  void initState() {
    super.initState();
    _appleMapOptions = _AppleMapOptions.fromWidget(widget);
  }

  @override
  void didUpdateWidget(AppleMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateOptions();
  }

  void _updateOptions() async {
    final _AppleMapOptions newOptions = _AppleMapOptions.fromWidget(widget);
    final Map<String, dynamic> updates = _appleMapOptions.updatesMap(newOptions);
    if (updates.isEmpty) {
      return;
    }
    final AppleMapsController controller = await _controller.future;
    controller._updateMapOptions(updates);
    _appleMapOptions = newOptions;
  }

  Future<void> onPlatformViewCreated(int id) async {
    final AppleMapsController controller = await AppleMapsController.init(
      id,
      widget.initialCameraPosition,
      this,
    );
    _controller.complete(controller);

    widget.onMapCreated(controller);
  }
}

/// Type of map tiles to display.
enum MapType {
  /// Normal tiles (traffic and labels, subtle terrain information).
  standard,

  /// Satellite imaging tiles (aerial photos)
  satellite,

  /// Hybrid tiles (satellite images with some labels/overlays)
  hybrid,
}

enum TrackingMode {
  // the user's location is not followed
  none,

  // the map follows the user's location
  follow,

  // the map follows the user's location and heading
  followWithHeading,
}

class MinMaxZoomPreference {
  const MinMaxZoomPreference(this.minZoom, this.maxZoom)
      : assert(minZoom == null || maxZoom == null || minZoom <= maxZoom);

  /// The preferred minimum zoom level or null, if unbounded from below.
  final double? minZoom;

  /// The preferred maximum zoom level or null, if unbounded from above.
  final double? maxZoom;

  /// Unbounded zooming.
  static const MinMaxZoomPreference unbounded = MinMaxZoomPreference(null, null);

  dynamic _toJson() => <dynamic>[minZoom, maxZoom];

  @override
  bool operator ==(dynamic other) {
    if (identical(this, other)) return true;
    if (runtimeType != other.runtimeType) return false;
    final MinMaxZoomPreference typedOther = other;
    return minZoom == typedOther.minZoom && maxZoom == typedOther.maxZoom;
  }

  @override
  int get hashCode => hashValues(minZoom, maxZoom);

  @override
  String toString() {
    return 'MinMaxZoomPreference(minZoom: $minZoom, maxZoom: $maxZoom)';
  }
}

/// Configuration options for the AppleMaps user interface.
///
/// When used to change configuration, null values will be interpreted as
/// "do not change this configuration option".
class _AppleMapOptions {
  _AppleMapOptions({
    this.compassEnabled,
    this.trafficEnabled,
    this.mapType,
    this.minMaxZoomPreference,
    this.rotateGesturesEnabled,
    this.scrollGesturesEnabled,
    this.pitchGesturesEnabled,
    this.trackingMode,
    this.zoomGesturesEnabled,
    this.myLocationEnabled,
    this.myLocationButtonEnabled,
    this.padding,
  });

  static _AppleMapOptions fromWidget(AppleMap map) {
    return _AppleMapOptions(
      compassEnabled: map.compassEnabled,
      trafficEnabled: map.trafficEnabled,
      mapType: map.mapType,
      minMaxZoomPreference: map.minMaxZoomPreference,
      rotateGesturesEnabled: map.rotateGesturesEnabled,
      scrollGesturesEnabled: map.scrollGesturesEnabled,
      pitchGesturesEnabled: map.pitchGesturesEnabled,
      trackingMode: map.trackingMode,
      zoomGesturesEnabled: map.zoomGesturesEnabled,
      myLocationEnabled: map.myLocationEnabled,
      myLocationButtonEnabled: map.myLocationButtonEnabled,
      padding: map.padding,
    );
  }

  final bool? compassEnabled;

  final bool? trafficEnabled;

  final MapType? mapType;

  final MinMaxZoomPreference? minMaxZoomPreference;

  final bool? rotateGesturesEnabled;

  final bool? scrollGesturesEnabled;

  final bool? pitchGesturesEnabled;

  final TrackingMode? trackingMode;

  final bool? zoomGesturesEnabled;

  final bool? myLocationEnabled;

  final bool? myLocationButtonEnabled;

  final EdgeInsets? padding;

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> optionsMap = <String, dynamic>{};

    void addIfNonNull(String fieldName, dynamic value) {
      if (value != null) {
        optionsMap[fieldName] = value;
      }
    }

    addIfNonNull('compassEnabled', compassEnabled);
    addIfNonNull('trafficEnabled', trafficEnabled);
    addIfNonNull('mapType', mapType?.index);
    addIfNonNull('minMaxZoomPreference', minMaxZoomPreference?._toJson());
    addIfNonNull('rotateGesturesEnabled', rotateGesturesEnabled);
    addIfNonNull('scrollGesturesEnabled', scrollGesturesEnabled);
    addIfNonNull('pitchGesturesEnabled', pitchGesturesEnabled);
    addIfNonNull('zoomGesturesEnabled', zoomGesturesEnabled);
    addIfNonNull('trackingMode', trackingMode?.index);
    addIfNonNull('myLocationEnabled', myLocationEnabled);
    addIfNonNull('myLocationButtonEnabled', myLocationButtonEnabled);
    addIfNonNull('padding', _serializePadding(padding));
    return optionsMap;
  }

  Map<String, dynamic> updatesMap(_AppleMapOptions newOptions) {
    final Map<String, dynamic> prevOptionsMap = toMap();

    return newOptions.toMap()..removeWhere((String key, dynamic value) => prevOptionsMap[key] == value);
  }

  List<double>? _serializePadding(EdgeInsets? insets) {
    if (insets == null) return null;
    return [insets.top, insets.left, insets.bottom, insets.right];
  }
}
