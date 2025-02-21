#import <Foundation/Foundation.h>

typedef NSString * WKWebExtensionDataType NS_TYPED_ENUM NS_SWIFT_NAME(WKWebExtension.DataType);

WK_EXTERN WKWebExtensionDataType const WKWebExtensionDataTypeLocal NS_SWIFT_NONISOLATED;
WK_EXTERN WKWebExtensionDataType const WKWebExtensionDataTypeSession NS_SWIFT_NONISOLATED;
WK_EXTERN WKWebExtensionDataType const WKWebExtensionDataTypeSynchronized NS_SWIFT_NONISOLATED;
