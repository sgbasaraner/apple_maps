//
//  FlutterMarker.swift
//  apple_maps
//
//  Created by sarupu on 5.03.2021.
//

import MapKit
import Flutter

struct FlutterMarker {
    let id: String
    let icon: UIImage
    
    init?(from bytes: FlutterStandardTypedData, id: String) {
        let screenScale = UIScreen.main.scale
        guard let image = UIImage(data: bytes.data, scale: screenScale) else {
            return nil
        }
        self.icon = image
        self.id = id
    }
    
    func toAnnotation() -> MKAnnotation {
        fatalError("unimplemented")
    }
}

protocol MarkerDataSource {
    associatedtype ID
    associatedtype Marker
    func addMarkers(_ newMarkers: [Marker])
    func removeMarkers(ids: [ID])
    func replaceMarkers(newMarkers: [Marker])
    func clearMarkers()
}

class MarkerManager: MarkerDataSource {
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
