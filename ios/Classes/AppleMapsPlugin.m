#import "AppleMapsPlugin.h"
#if __has_include(<apple_maps/apple_maps-Swift.h>)
#import <apple_maps/apple_maps-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "apple_maps-Swift.h"
#endif

@implementation AppleMapsPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftAppleMapsPlugin registerWithRegistrar:registrar];
}
@end
