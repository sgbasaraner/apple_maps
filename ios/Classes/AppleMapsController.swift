//
//  AppleMapsController.swift
//  apple_maps
//
//  Created by sarupu on 5.03.2021.
//

import Flutter
import MapKit

public class AppleMapsController : NSObject, FlutterPlatformView, MKMapViewDelegate {
    public func view() -> UIView {
        mapView
    }
    
    let mapView: AppleMapsView!
    let registrar: FlutterPluginRegistrar
    let channel: FlutterMethodChannel
    let initialCameraPosition: [String: Any]
    let options: [String: Any]
    let markerDataSource: FlutterMarkerDataSource
    
    
    public init(withFrame frame: CGRect, withRegistrar registrar: FlutterPluginRegistrar, withargs args: Dictionary<String, Any> ,withId id: Int64) {
        self.options = args["options"] as! [String: Any]
        self.channel = FlutterMethodChannel(name: "com.sgbasaraner.github/apple_maps_\(id)", binaryMessenger: registrar.messenger())
        
        self.mapView = AppleMapsView(channel: channel, options: options)
        self.registrar = registrar
        
        self.initialCameraPosition = args["initialCameraPosition"]! as! Dictionary<String, Any>
        self.markerDataSource = MarkerManager(mapView: mapView)
        super.init()
        
        self.mapView.delegate = self
        self.mapView.setCenterCoordinate(initialCameraPosition, animated: false)
        self.setMethodCallHandlers()
    }
    
    // onIdle
    public func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        self.channel.invokeMethod("camera#onIdle", arguments: "")
    }
    
    // onMoveStarted
    public func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        self.channel.invokeMethod("camera#onMoveStarted", arguments: "")
    }
    
    private func setMethodCallHandlers() {
            channel.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: FlutterResult) -> Void in
                if let args :Dictionary<String, Any> = call.arguments as? Dictionary<String,Any> {
                    switch(call.method) {
                    case "map#update":
                        self?.mapView.interpretOptions(options: args["options"] as! Dictionary<String, Any>)
                    case "camera#animate":
                        guard let positionData :Dictionary<String, Any> = self?.toPositionData(data: args["cameraUpdate"] as! Array<Any>, animated: true) else {
                            result(nil)
                            return
                        }
                        if !positionData.isEmpty {
                            self?.mapView.setCenterCoordinate(positionData, animated: true)
                        }
                        result(nil)
                    case "camera#move":
                        guard let positionData :Dictionary<String, Any> = self?.toPositionData(data: args["cameraUpdate"] as! Array<Any>, animated: false) else {
                            result(nil)
                            return
                        }
                        if !positionData.isEmpty {
                            self?.mapView.setCenterCoordinate(positionData, animated: false)
                        }
                        result(nil)
                    case "markers#add":
                        guard let list = args["markerList"] as? [Any], let markers = self?.parseMarkers(list: list) else {
                            result(nil)
                            return
                        }
                        self?.markerDataSource.addMarkers(markers)
                        result(nil)
                    case "markers#remove":
                        guard let list = args["idList"] as? [String] else {
                            result(nil)
                            return
                        }
                        self?.markerDataSource.removeMarkers(ids: list)
                        result(nil)
                    case "markers#replace":
                        guard let list = args["markerList"] as? [Any], let markers = self?.parseMarkers(list: list) else {
                            result(nil)
                            return
                        }
                        self?.markerDataSource.replaceMarkers(newMarkers: markers)
                        result(nil)
                    default:
                        result(FlutterMethodNotImplemented)
                        return
                    }
                } else {
                    switch call.method {
                    case "markers#clear":
                        self?.markerDataSource.clearMarkers()
                        result(nil)
                    case "map#getVisibleRegion":
                        result(self?.mapView.getVisibleRegion())
                    case "map#isCompassEnabled":
                        if #available(iOS 9.0, *) {
                            result(self?.mapView.showsCompass)
                        } else {
                            result(false)
                        }
                    case "map#isPitchGesturesEnabled":
                        result(self?.mapView.isPitchEnabled)
                    case "map#isScrollGesturesEnabled":
                        result(self?.mapView.isScrollEnabled)
                    case "map#isZoomGesturesEnabled":
                        result(self?.mapView.isZoomEnabled)
                    case "map#isRotateGesturesEnabled":
                        result(self?.mapView.isRotateEnabled)
                    case "map#isMyLocationButtonEnabled":
                        result(self?.mapView.isMyLocationButtonShowing ?? false)
                    case "map#getMinMaxZoomLevels":
                        guard let strSelf = self else {
                            result(nil)
                            return
                        }
                        result([strSelf.mapView.minZoomLevel, strSelf.mapView.maxZoomLevel])
                    case "camera#getZoomLevel":
                        result(self?.mapView.calculatedZoomLevel)
                    default:
                        result(FlutterMethodNotImplemented)
                        return
                    }
                }
            })
        }
        
        private func toPositionData(data: Array<Any>, animated: Bool) -> Dictionary<String, Any> {
            var positionData: Dictionary<String, Any> = [:]
            if let update: String = data[0] as? String {
                switch(update) {
                case "newCameraPosition":
                    if let _positionData : Dictionary<String, Any> = data[1] as? Dictionary<String, Any> {
                        positionData = _positionData
                    }
                case "newLatLng":
                    if let _positionData : Array<Any> = data[1] as? Array<Any> {
                        positionData = ["target": _positionData]
                    }
                case "newLatLngZoom":
                    if let _positionData: Array<Any> = data[1] as? Array<Any> {
                        let zoom: Double = data[2] as? Double ?? 0
                        positionData = ["target": _positionData, "zoom": zoom]
                    }
                case "zoomBy":
                    if let zoomBy: Double = data[1] as? Double {
                        mapView.zoomBy(zoomBy: zoomBy, animated: animated)
                    }
                case "zoomTo":
                    if let zoomTo: Double = data[1] as? Double {
                        mapView.zoomTo(newZoomLevel: zoomTo, animated: animated)
                    }
                case "zoomIn":
                    mapView.zoomIn(animated: animated)
                case "zoomOut":
                    mapView.zoomOut(animated: animated)
                default:
                    positionData = [:]
                }
                return positionData
            }
            return [:]
        }
    
    private func parseMarkers(list: [Any]) -> [FlutterMarker]? {
        return list.lazy
            .compactMap { $0 as? [Any] }
            .filter { $0.count == 3 }
            .compactMap {
                guard let id = $0[0] as? String,
                      let bytes = $0[1] as? FlutterStandardTypedData,
                      let coords = parseLatLng(list: $0[2]) else { return nil }
                return FlutterMarker(from: bytes, id: id, coords: coords)
            }
    }
    
    private func parseLatLng(list: Any) -> CLLocationCoordinate2D? {
        guard let doubleList = list as? [Double], doubleList.count == 2 else { return nil }
        return CLLocationCoordinate2D(latitude: doubleList[0], longitude: doubleList[1])
    }
}

