//
//  RSBackGroundModeManager.h
//  Rudder
//
//  Created by Desu Sai Venkat on 09/08/22.
//  Copyright © 2022 Rudder Labs India Pvt Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Rudder/Rudder.h>

NS_ASSUME_NONNULL_BEGIN

@interface RSBackGroundModeManager : NSObject {
    RSConfig* config;
    BOOL isSemaphoreReleased;
#if !TARGET_OS_WATCH
    UIBackgroundTaskIdentifier backgroundTask;
#else
    dispatch_semaphore_t semaphore;
#endif
}

- (instancetype)initWithConfig:(RSConfig *) config;
- (void) registerForBackGroundMode;

@end

NS_ASSUME_NONNULL_END
