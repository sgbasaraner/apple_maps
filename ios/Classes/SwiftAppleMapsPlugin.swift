import Flutter
import UIKit

public class SwiftAppleMapsPlugin: NSObject, FlutterPlugin {
    var factory: AppleMapViewFactory
        public init(with registrar: FlutterPluginRegistrar) {
            factory = AppleMapViewFactory(withRegistrar: registrar)
            registrar.register(factory, withId: "com.sgbasaraner.github/apple_maps", gestureRecognizersBlockingPolicy:FlutterPlatformViewGestureRecognizersBlockingPolicyWaitUntilTouchesEnded)
        }
        
        public static func register(with registrar: FlutterPluginRegistrar) {
            registrar.addApplicationDelegate(SwiftAppleMapsPlugin(with: registrar))
        }
}

public class AppleMapViewFactory: NSObject, FlutterPlatformViewFactory {
    
    var registrar: FlutterPluginRegistrar
    
    public init(withRegistrar registrar: FlutterPluginRegistrar){
        self.registrar = registrar
        super.init()
    }
    
    public func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        let argsDictionary =  args as! Dictionary<String, Any>
        
        return AppleMapsController(withFrame: frame, withRegistrar: registrar, withargs: argsDictionary, withId: viewId)
        
    }
    
    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec(readerWriter: FlutterStandardReaderWriter())
    }
}
