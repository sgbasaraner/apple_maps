//
//  FlutterMarker.swift
//  apple_maps
//
//  Created by sarupu on 5.03.2021.
//

import Foundation
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
}

protocol MarkerDataSource {
    func addMarkers(_ newMarkers: [FlutterMarker])
    func removeMarkers(ids: [String])
    func replaceMarkers(newMarkers: [FlutterMarker])
    func clearMarkers()
}

class MarkerManager: MarkerDataSource {
    private var markers: [String : FlutterMarker] = [:]
    
    init(initialMarkers: [FlutterMarker]? = nil) {
        if let initialMarkers = initialMarkers {
            addMarkers(initialMarkers)
        }
    }
    
    func addMarkers(_ newMarkers: [FlutterMarker]) {
        for marker in newMarkers {
            markers[marker.id] = marker
        }
    }
    
    func removeMarkers(ids: [String]) {
        for id in ids {
            markers.removeValue(forKey: id)
        }
    }
    
    func replaceMarkers(newMarkers: [FlutterMarker]) {
        clearMarkers()
        addMarkers(newMarkers)
    }
    
    func clearMarkers() {
        markers.removeAll()
    }
}
