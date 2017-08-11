//
//  WebsocketClient.h
//  ws-client
//
//  Created by Theresa on 2017/8/8.
//  Copyright © 2017年 Theresa. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, WebSocketState) {
    WebSocketStateClosed,
    WebSocketStateConnecting,
    WebSocketStateOpen,
};

@class RACSignal;

@interface WebsocketClient : NSObject

+ (instancetype)sharedClient;
- (void)open;
- (void)close;
- (void)sendMessage:(NSString *)message;

@end
