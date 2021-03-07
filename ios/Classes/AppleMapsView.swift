//
//  AppleMapsView.swift
//  apple_maps
//
//  Created by sarupu on 5.03.2021.
//

import Flutter
import MapKit
import CoreLocation

enum BUTTON_IDS: Int {
    case LOCATION = 100
}

class FlutterAnnotationView: MKAnnotationView {
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        didSetAnnotation(annotation: annotation)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var annotation: MKAnnotation? {
        didSet {
            didSetAnnotation(annotation: annotation)
        }
    }
    
    func didSetAnnotation(annotation: MKAnnotation?) {
        if let flutterAnnotation = annotation as? FlutterAnnotation {
            return configure(annotation: flutterAnnotation)
        }
        
        if let annotation = annotation as? MKClusterAnnotation {
            if let firstFlutterChild = annotation.memberAnnotations.lazy.compactMap({ $0 as? FlutterAnnotation }).first {
                return configure(annotation: firstFlutterChild)
            } else {
                return print("No FlutterAnnotation child found for cluster.")
            }
        }
    }
    
    var lastId: String?
    
    func configure(annotation: FlutterAnnotation) {
        guard lastId != annotation.id else { return }
        lastId = annotation.id
        image = annotation.icon
        centerOffset = CGPoint(x: 0, y: -annotation.icon.size.height / 2)
        clusteringIdentifier = "com.sgbasaraner/cluster"
    }
}


class AppleMapsView: MKMapView, UIGestureRecognizerDelegate {
    var oldBounds: CGRect?
    var mapContainerView: UIView?
    var channel: FlutterMethodChannel?
    var options: Dictionary<String, Any>?
    var isMyLocationButtonShowing: Bool? = false
    fileprivate let locationManager:CLLocationManager = CLLocationManager()
    
    let mapTypes: Array<MKMapType> = [
        MKMapType.standard,
        MKMapType.satellite,
        MKMapType.hybrid,
    ]
    
    let userTrackingModes: Array<MKUserTrackingMode> = [
        MKUserTrackingMode.none,
        MKUserTrackingMode.follow,
        MKUserTrackingMode.followWithHeading,
    ]
    
    convenience init(channel: FlutterMethodChannel, options: Dictionary<String, Any>) {
        self.init(frame: CGRect.zero)
        self.channel = channel
        self.options = options
    }
    
    var actualHeading: CLLocationDirection {
        get {
            if mapContainerView != nil {
                var heading: CLLocationDirection = fabs(180 * asin(Double(mapContainerView!.transform.b)) / .pi)
                if mapContainerView!.transform.b <= 0 {
                    if mapContainerView!.transform.a >= 0 {
                        // do nothing
                    } else {
                        heading = 180 - heading
                    }
                } else {
                    if mapContainerView!.transform.a <= 0 {
                        heading = heading + 180
                    } else {
                        heading = 360 - heading
                    }
                }
                return heading
            }
            return CLLocationDirection.zero
        }
    }
    
    // To calculate the displayed region we have to get the layout bounds.
    // Because the self is layed out using an auto layout we have to call
    // setCenterCoordinate after the self was layed out.
    override func layoutSubviews() {
        // Only update the map in layoutSubviews if the bounds changed
        if self.bounds != oldBounds {
            if self.options != nil {
                self.interpretOptions(options: self.options!)
            }
                setCenterCoordinateWithAltitude(centerCoordinate: centerCoordinate, zoomLevel: zoomLevel, animated: false)
                mapContainerView = self.findViewOfType("MKScrollContainerView", inView: self)
            
        }
        oldBounds = self.bounds
    }
    
    
    override func didMoveToSuperview() {
        if oldBounds != CGRect.zero {
            oldBounds = CGRect.zero
        }
    }
    
    private func findViewOfType(_ viewType: String, inView view: UIView) -> UIView? {
      // function scans subviews recursively and returns
      // reference to the found one of a type
      if view.subviews.count > 0 {
        for v in view.subviews {
          let valueDescription = v.description
          let keywords = viewType
          if valueDescription.range(of: keywords) != nil {
            return v
          }
          if let inSubviews = self.findViewOfType(viewType, inView: v) {
            return inSubviews
          }
        }
        return nil
      } else {
        return nil
      }
    }
    
    func interpretOptions(options: Dictionary<String, Any>) {
        if let isCompassEnabled: Bool = options["compassEnabled"] as? Bool {
                self.showsCompass = isCompassEnabled
                self.mapTrackingButton(isVisible: self.isMyLocationButtonShowing ?? false)
            
        }

        if let padding: Array<Any> = options["padding"] as? Array<Any> {
            var margins = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
            
            if padding.count >= 1, let top: Double = padding[0] as? Double {
                margins.top = CGFloat(top)
            }
            
            if padding.count >= 2, let left: Double = padding[1] as? Double {
                margins.left = CGFloat(left)
            }
            
            if padding.count >= 3, let bottom: Double = padding[2] as? Double {
                margins.bottom = CGFloat(bottom)
            }
            
            if padding.count >= 4, let right: Double = padding[3] as? Double {
                margins.right = CGFloat(right)
            }
            
            self.layoutMargins = margins
        }
        
        if let mapType: Int = options["mapType"] as? Int {
            self.mapType = self.mapTypes[mapType]
        }
        
        if let trafficEnabled: Bool = options["trafficEnabled"] as? Bool {
                self.showsTraffic = trafficEnabled
         
        }
        
        if let rotateGesturesEnabled: Bool = options["rotateGesturesEnabled"] as? Bool {
            self.isRotateEnabled = rotateGesturesEnabled
        }
        
        if let scrollGesturesEnabled: Bool = options["scrollGesturesEnabled"] as? Bool {
            self.isScrollEnabled = scrollGesturesEnabled
        }
        
        if let pitchGesturesEnabled: Bool = options["pitchGesturesEnabled"] as? Bool {
            self.isPitchEnabled = pitchGesturesEnabled
        }
        
        if let zoomGesturesEnabled: Bool = options["zoomGesturesEnabled"] as? Bool{
            self.isZoomEnabled = zoomGesturesEnabled
        }
        
        if let myLocationEnabled: Bool = options["myLocationEnabled"] as? Bool {
            if (myLocationEnabled) {
                self.setUserLocation()
            } else {
                self.removeUserLocation()
            }
            
        }
        
        if let myLocationButtonEnabled: Bool = options["myLocationButtonEnabled"] as? Bool {
            self.mapTrackingButton(isVisible: myLocationButtonEnabled)
        }
        
        if let userTackingMode: Int = options["trackingMode"] as? Int {
            self.setUserTrackingMode(self.userTrackingModes[userTackingMode], animated: false)
        }
        
        if let minMaxZoom: Array<Any> = options["minMaxZoomPreference"] as? Array<Any>{
            if let _minZoom: Double = minMaxZoom[0] as? Double {
                self.minZoomLevel = _minZoom
            }
            if let _maxZoom: Double = minMaxZoom[1] as? Double {
                self.maxZoomLevel = _maxZoom
            }
        }
    }
    
    public func setUserLocation() {
        if CLLocationManager.authorizationStatus() == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if CLLocationManager.authorizationStatus() ==  .authorizedWhenInUse {
            locationManager.requestWhenInUseAuthorization()
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.distanceFilter = kCLDistanceFilterNone
            locationManager.startUpdatingLocation()
            self.showsUserLocation = true
        }
    }
    
    public func removeUserLocation() {
        locationManager.stopUpdatingLocation()
        self.showsUserLocation = false
    }
    
    // Functions used for the mapTrackingButton
    func mapTrackingButton(isVisible visible: Bool) {
        self.isMyLocationButtonShowing = visible
        if let _locationButton = self.viewWithTag(BUTTON_IDS.LOCATION.rawValue) {
           _locationButton.removeFromSuperview()
        }
        if visible {
            let buttonContainer = UIView()
                buttonContainer.translatesAutoresizingMaskIntoConstraints = false
                buttonContainer.widthAnchor.constraint(equalToConstant: 35).isActive = true
                buttonContainer.heightAnchor.constraint(equalToConstant: 35).isActive = true
                buttonContainer.layer.cornerRadius = 8
                buttonContainer.tag = BUTTON_IDS.LOCATION.rawValue
                buttonContainer.backgroundColor = .white
                    let userTrackingButton = MKUserTrackingButton(mapView: self)
                    userTrackingButton.translatesAutoresizingMaskIntoConstraints = false
                    buttonContainer.addSubview(userTrackingButton)
                    userTrackingButton.centerXAnchor.constraint(equalTo: buttonContainer.centerXAnchor).isActive = true
                    userTrackingButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor).isActive = true
                
                self.addSubview(buttonContainer)
                buttonContainer.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -5 - self.layoutMargins.right).isActive = true
                buttonContainer.topAnchor.constraint(equalTo: self.topAnchor, constant: self.showsCompass ? 50 : 5 + self.layoutMargins.top).isActive = true
        }
    }
    
    @objc func centerMapOnUserButtonClicked() {
       self.setUserTrackingMode(MKUserTrackingMode.follow, animated: true)
    }
       
    
    public func updateCameraValues() {
        if oldBounds != nil && oldBounds != CGRect.zero {
            self.updateStoredCameraValues(newZoomLevel: calculatedZoomLevel, newPitch: camera.pitch, newHeading: actualHeading)
        }
    }
   
    
    
    
    func distanceOfCGPoints(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let xDist = a.x - b.x
        let yDist = a.y - b.y
        return CGFloat(sqrt(xDist * xDist + yDist * yDist))
    }
}
