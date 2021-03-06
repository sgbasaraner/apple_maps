//
//  MapViewExtension.swift
//  apple_maps
//
//  Created by sarupu on 5.03.2021.
//

import MapKit

enum MapViewConstants: Double {
    case MERCATOR_OFFSET = 268435456.0
    case MERCATOR_RADIUS = 85445659.44705395
}

public extension MKMapView {
    // keeps track of the Map values
    private struct Holder {
        static var _zoomLevel: Double = Double(0)
        static var _pitch: CGFloat = CGFloat(0)
        static var _heading: CLLocationDirection = CLLocationDirection(0)
        static var _maxZoomLevel: Double = Double(21)
        static var _minZoomLevel: Double = Double(2)
    }
    
    var maxZoomLevel: Double {
        set(_maxZoomLevel) {
            Holder._maxZoomLevel = _maxZoomLevel
            if Holder._zoomLevel > _maxZoomLevel {
                self.setCenterCoordinateWithAltitude(centerCoordinate: centerCoordinate, zoomLevel: _maxZoomLevel, animated: false)
                
            }
        }
        get {
            return Holder._maxZoomLevel
        }
    }
    
    var minZoomLevel: Double {
        set(_minZoomLevel) {
            Holder._minZoomLevel = _minZoomLevel
            if Holder._zoomLevel < _minZoomLevel {
                self.setCenterCoordinateWithAltitude(centerCoordinate: centerCoordinate, zoomLevel: _minZoomLevel, animated: false)
            }
        }
        get {
           return Holder._minZoomLevel
        }
    }
    
    var zoomLevel: Double {
        get {
            return Holder._zoomLevel
        }
    }
    
    var calculatedZoomLevel: Double {
        get {
            let centerPixelSpaceX = self.longitudeToPixelSpaceX(longitude: self.centerCoordinate.longitude)

            let lonLeft = self.centerCoordinate.longitude - (self.region.span.longitudeDelta / 2)

            let leftPixelSpaceX = self.longitudeToPixelSpaceX(longitude: lonLeft)
            let pixelSpaceWidth = abs(centerPixelSpaceX - leftPixelSpaceX) * 2

            let zoomScale = pixelSpaceWidth / Double(self.bounds.size.width)

            let zoomExponent = self.logC(val: zoomScale, forBase: 2)

            var zoomLevel = 21 - zoomExponent
            
            zoomLevel = roundToTwoDecimalPlaces(number: zoomLevel)
            
            Holder._zoomLevel = zoomLevel
            
            return zoomLevel
            
        }
        set (newZoomLevel) {
            Holder._zoomLevel = newZoomLevel
        }
    }
    
    func longitudeToPixelSpaceX(longitude: Double) -> Double {
        return round(MapViewConstants.MERCATOR_OFFSET.rawValue + MapViewConstants.MERCATOR_RADIUS.rawValue * longitude * .pi / 180.0)
    }
    
    func latitudeToPixelSpaceY(latitude: Double) -> Double {
        return round(Double(Float(MapViewConstants.MERCATOR_OFFSET.rawValue) - Float(MapViewConstants.MERCATOR_RADIUS.rawValue) * logf((1 + sinf(Float(latitude * .pi / 180.0))) / (1 - sinf(Float(latitude * .pi / 180.0)))) / Float(2.0)))
    }
    
    func pixelSpaceXToLongitude(pixelX: Double) -> Double {
        return ((round(pixelX) - MapViewConstants.MERCATOR_OFFSET.rawValue) / MapViewConstants.MERCATOR_RADIUS.rawValue) * 180.0 / .pi
    }
    
    func pixelSpaceYToLatitude(pixelY: Double) -> Double {
        return (.pi / 2.0 - 2.0 * atan(exp((round(pixelY) - MapViewConstants.MERCATOR_OFFSET.rawValue) / MapViewConstants.MERCATOR_RADIUS.rawValue))) * 180.0 / .pi
    }
    
    func logC(val: Double, forBase base: Double) -> Double {
        return log(val)/log(base)
    }
    
    func deg2rad(_ number: Double) -> Float {
        return Float(number * .pi / 180)
    }
    
    func roundToTwoDecimalPlaces(number: Double) -> Double {
        let doubleStr = String(format: "%.2f", ceil(number*100)/100)
        return Double(doubleStr)!
    }
    
    func setCenterCoordinate(_ positionData: Dictionary<String, Any>, animated: Bool) {
        let targetList :Array<CLLocationDegrees> = positionData["target"] as? Array<CLLocationDegrees> ?? [self.camera.centerCoordinate.latitude, self.camera.centerCoordinate.longitude]
        let zoom :Double = positionData["zoom"] as? Double ?? Holder._zoomLevel
        Holder._zoomLevel = zoom
        if let pitch :CGFloat = positionData["pitch"] as? CGFloat {
            Holder._pitch = pitch
        }
        if let heading :CLLocationDirection = positionData["heading"] as? CLLocationDirection {
            Holder._heading = heading
        }
        let centerCoordinate :CLLocationCoordinate2D = CLLocationCoordinate2D(latitude:  targetList[0], longitude: targetList[1])
        
            self.setCenterCoordinateRegion(centerCoordinate: centerCoordinate, zoomLevel: zoom, animated: animated)
        
    }
    
    func setCenterCoordinateRegion(centerCoordinate: CLLocationCoordinate2D, zoomLevel: Double, animated: Bool) {
        // clamp large numbers to 28
        let zoomL = min(zoomLevel, 28);
    
        // use the zoom level to compute the region
        let span = self.coordinateSpanWithMapView(centerCoordinate: centerCoordinate, zoomLevel: Int(zoomL))
        let region = MKCoordinateRegion.init(center: centerCoordinate, span: span)
        
        // set the region like normal
        self.setRegion(region, animated: animated)
        
        // Setting the pitch/heading doesn't work while animating yet.
        // The animation will stop if the you change camera properties while it's running.
        if (!animated) {
            self.camera.pitch = Holder._pitch
            self.camera.heading = Holder._heading
        }
    }
    
    func coordinateSpanWithMapView(centerCoordinate: CLLocationCoordinate2D, zoomLevel: Int) -> MKCoordinateSpan  {
        // convert center coordiate to pixel space
        let centerPixelX = self.longitudeToPixelSpaceX(longitude: centerCoordinate.longitude)
        let centerPixelY = self.latitudeToPixelSpaceY(latitude: centerCoordinate.latitude)
    
        // determine the scale value from the zoom level
        let zoomExponent = Double(21 - zoomLevel)
        let zoomScale = pow(2.0, zoomExponent)

        // scale the map???s size in pixel space
        let mapSizeInPixels = self.bounds.size
        let scaledMapWidth = Double(mapSizeInPixels.width) * zoomScale
        let scaledMapHeight = Double(mapSizeInPixels.height) * zoomScale;
    
        // figure out the position of the top-left pixel
        let topLeftPixelX = centerPixelX - (scaledMapWidth / 2);
        let topLeftPixelY = centerPixelY - (scaledMapHeight / 2);
    
        // find delta between left and right longitudes
        let minLng = self.pixelSpaceXToLongitude(pixelX: topLeftPixelX)
        let maxLng = self.pixelSpaceXToLongitude(pixelX: topLeftPixelX + scaledMapWidth)
        let longitudeDelta = maxLng - minLng;
    
        // find delta between top and bottom latitudes
        let minLat = self.pixelSpaceYToLatitude(pixelY: topLeftPixelY)
        let maxLat = self.pixelSpaceYToLatitude(pixelY: topLeftPixelY + scaledMapHeight)
        let latitudeDelta = -1 * (maxLat - minLat)
    
        // create and return the lat/lng span
        return MKCoordinateSpan.init(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
    }
    
    func setCenterCoordinateWithAltitude(centerCoordinate: CLLocationCoordinate2D, zoomLevel: Double, animated: Bool) {
        // clamp large numbers to 28
        let zoomL = min(zoomLevel, 28);
        let altitude = getCameraAltitude(centerCoordinate: centerCoordinate, zoomLevel: zoomL)
        self.setCamera(MKMapCamera(lookingAtCenter: centerCoordinate, fromDistance: CLLocationDistance(altitude), pitch: Holder._pitch, heading: Holder._heading), animated: animated)
    }
    
    private func getCameraAltitude(centerCoordinate: CLLocationCoordinate2D, zoomLevel: Double) -> Double {
        // convert center coordiate to pixel space
        let centerPixelY = latitudeToPixelSpaceY(latitude: centerCoordinate.latitude)
        // determine the scale value from the zoom level
        let zoomExponent:Double = 21.0 - zoomLevel
        let zoomScale:Double = pow(2.0, zoomExponent)
        // scale the map???s size in pixel space
        let mapSizeInPixels = self.bounds.size
        let scaledMapHeight = Double(mapSizeInPixels.height) * zoomScale
        // figure out the position of the top-left pixel
        let topLeftPixelY = centerPixelY - (scaledMapHeight / 2.0)
        // find delta between left and right longitudes
        let maxLat = pixelSpaceYToLatitude(pixelY: topLeftPixelY + scaledMapHeight)
        let topBottom = CLLocationCoordinate2D.init(latitude: maxLat, longitude: centerCoordinate.longitude)
        
        let distance = MKMapPoint.init(centerCoordinate).distance(to: MKMapPoint.init(topBottom))
        let altitude = distance / tan(.pi*(15/180.0))
        
        return altitude
    }
    
    private static func calculateBounds(rect: MKMapRect) -> Dictionary<String, [Double]> {
        let northEastCoordinate = MKMapPoint(x: rect.maxX, y: rect.minY).coordinate
        let southWestCoordinate = MKMapPoint(x: rect.minX, y: rect.maxY).coordinate
            
        return [
            "northeast": [northEastCoordinate.latitude, northEastCoordinate.longitude],
            "southwest": [southWestCoordinate.latitude, southWestCoordinate.longitude]
        ]
    }
    
    func getVisibleRegion() -> Dictionary<String, [Double]> {
        MKMapView.calculateBounds(rect: visibleMapRect)
    }
    
    func zoomIn(animated: Bool) {
        if Holder._zoomLevel - 1 <= Holder._maxZoomLevel {
            if Holder._zoomLevel < 2 {
                Holder._zoomLevel = 2
            }
            Holder._zoomLevel += 1
                self.setCenterCoordinateWithAltitude(centerCoordinate: centerCoordinate, zoomLevel: Holder._zoomLevel, animated: animated)
          
        }
    }
    
    func zoomOut(animated: Bool) {
        if Holder._zoomLevel - 1 >= Holder._minZoomLevel {
            Holder._zoomLevel -= 1
            if round(Holder._zoomLevel) <= 2 {
               Holder._zoomLevel = 0
            }

               self.setCenterCoordinateWithAltitude(centerCoordinate: centerCoordinate, zoomLevel: Holder._zoomLevel, animated: animated)
          
        }
    }
    
    func zoomTo(newZoomLevel: Double, animated: Bool) {
        if newZoomLevel < Holder._minZoomLevel {
            Holder._zoomLevel = Holder._minZoomLevel
        } else if newZoomLevel > Holder._maxZoomLevel {
            Holder._zoomLevel = Holder._maxZoomLevel
        } else {
            Holder._zoomLevel = newZoomLevel
        }

            self.setCenterCoordinateWithAltitude(centerCoordinate: centerCoordinate, zoomLevel: Holder._zoomLevel, animated: animated)
        
    }
    
    func zoomBy(zoomBy: Double, animated: Bool) {
        if Holder._zoomLevel + zoomBy < Holder._minZoomLevel {
            Holder._zoomLevel = Holder._minZoomLevel
        } else if Holder._zoomLevel + zoomBy > Holder._maxZoomLevel {
            Holder._zoomLevel = Holder._maxZoomLevel
        } else {
            Holder._zoomLevel = Holder._zoomLevel + zoomBy
        }
        
            self.setCenterCoordinateWithAltitude(centerCoordinate: centerCoordinate, zoomLevel: Holder._zoomLevel, animated: animated)
   
    }
    
    func updateStoredCameraValues(newZoomLevel: Double, newPitch: CGFloat, newHeading: CLLocationDirection) {
        Holder._zoomLevel = newZoomLevel
        Holder._pitch = newPitch
        Holder._heading = newHeading
    }
}
