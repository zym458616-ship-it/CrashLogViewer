#import <Foundation/Foundation.h>

@interface LSApplicationProxy : NSObject
@property (nonatomic, readonly) NSString *applicationIdentifier;      // bundle id
@property (nonatomic, readonly) NSString *bundleExecutable;
@property (nonatomic, readonly) NSString *localizedName;
@property (nonatomic, readonly) NSString *shortVersionString;
@property (nonatomic, readonly) NSString *bundleVersion;
@property (nonatomic, readonly) NSURL    *bundleURL;
@property (nonatomic, readonly) NSURL    *containerURL;
@property (nonatomic, readonly) NSURL    *dataContainerURL;
@property (nonatomic, readonly) NSString *applicationType;            // User / System
@property (nonatomic, readonly) NSString *teamID;
@property (nonatomic, readonly) NSString *vendorName;
@property (nonatomic, readonly) NSDate   *registeredDate;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (NSArray<LSApplicationProxy *> *)allApplications;
- (NSArray<LSApplicationProxy *> *)allInstalledApplications;
- (LSApplicationProxy *)applicationProxyForIdentifier:(NSString *)identifier;
@end
