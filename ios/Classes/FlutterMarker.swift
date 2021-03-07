//
//  FlutterMarker.swift
//  apple_maps
//
//  Created by sarupu on 5.03.2021.
//

import MapKit
import Flutter

class FlutterAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let icon: UIImage
    let id: String
    
    init(id: String, icon: UIImage, coords: CLLocationCoordinate2D) {
        self.coordinate = coords
        self.icon = icon
        self.id = id
    }
}

struct FlutterMarker {
    let id: String
    let icon: UIImage
    let coordinates: CLLocationCoordinate2D
    
    init?(from bytes: FlutterStandardTypedData, id: String, coords: CLLocationCoordinate2D) {
        let screenScale = UIScreen.main.scale
        guard let image = UIImage(data: bytes.data, scale: screenScale) else {
            return nil
        }
        self.icon = image
        self.id = id
        self.coordinates = coords
    }
    
    func toAnnotation() -> MKAnnotation {
        return FlutterAnnotation(id: id, icon: icon, coords: coordinates)
    }
}

protocol FlutterMarkerDataSource {
    func addMarkers(_ newMarkers: [FlutterMarker])
    func removeMarkers(ids: [String])
    func replaceMarkers(newMarkers: [FlutterMarker])
    func clearMarkers()
}

class MarkerManager: FlutterMarkerDataSource {
    private var markers: [String : MKAnnotation] = [:]
    
    weak var mapView: MKMapView?
    
    init(mapView: MKMapView, initialMarkers: [FlutterMarker]? = nil) {
        if let initialMarkers = initialMarkers {
            addMarkers(initialMarkers)
        }
        self.mapView = mapView
    }
    
    func addMarkers(_ newMarkers: [FlutterMarker]) {
        let newAnnotations = newMarkers.compactMap({ (marker) -> MKAnnotation? in
            guard markers[marker.id] == nil else { return nil }
            let annotation = marker.toAnnotation()
            markers[marker.id] = annotation
            return annotation
        })
        
        mapView?.addAnnotations(newAnnotations)
    }
    
    func removeMarkers(ids: [String]) {
        let annotationsToRemove = ids.compactMap { markers.removeValue(forKey: $0) }
        mapView?.removeAnnotations(annotationsToRemove)
    }
    
    func replaceMarkers(newMarkers: [FlutterMarker]) {
        clearMarkers()
        addMarkers(newMarkers)
    }
    
    func clearMarkers() {
        markers.removeAll()
        mapView?.removeAnnotations(mapView?.annotations ?? [])
    }
}
