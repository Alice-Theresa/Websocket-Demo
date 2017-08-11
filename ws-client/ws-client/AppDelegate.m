//
//  AppDelegate.m
//  ws-client
//
//  Created by Theresa on 2017/8/8.
//  Copyright © 2017年 Theresa. All rights reserved.
//

#import <AFNetworking/AFNetworkActivityIndicatorManager.h>
#import <AFNetworking/AFNetworking.h>

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    [[AFNetworkReachabilityManager sharedManager] startMonitoring];
    [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];
    
    return YES;
}

@end
