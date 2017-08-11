//
//  WebsocketClient.m
//  ws-client
//
//  Created by Theresa on 2017/8/8.
//  Copyright © 2017年 Theresa. All rights reserved.
//

#import <AFNetworking/AFNetworking.h>
#import <ReactiveObjC/ReactiveObjC.h>
#import <SocketRocket/SocketRocket.h>

#import "WebsocketClient.h"

@interface WebsocketClient () <SRWebSocketDelegate>

@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) SRWebSocket      *websocket;
@property (nonatomic, assign) WebSocketState   state;
@property (nonatomic, assign) NSInteger        pongSequence;
@property (nonatomic, assign) NSInteger        currentSequence;

@property (nonatomic, strong) RACScheduler  *scheduler;
@property (nonatomic, strong) RACDisposable *timeoutDisposable;
@property (nonatomic, strong) RACDisposable *heartbeatDisposable;

@end

static NSString * const ServerIP = @"ws://192.168.9.154:8089";

@implementation WebsocketClient

#pragma mark - Init

+ (instancetype)sharedClient {
    static WebsocketClient *wsc;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        wsc = [[self alloc] init];
    });
    return wsc;
}

- (instancetype)init {
    if (self = [super init]) {
        _queue = dispatch_queue_create("com.Hime.Websocket", DISPATCH_QUEUE_SERIAL);
        _scheduler = [[RACTargetQueueScheduler alloc] initWithName:@"com.Websocket.Scheduler" targetQueue:_queue];
        [self setup];
    }
    return self;
}

- (void)setup {
    @weakify(self)
    [[[[[RACObserve([AFNetworkReachabilityManager sharedManager], reachable)
         distinctUntilChanged]
        skip:2]
       filter:^BOOL(id  _Nullable value) {
          return [value boolValue];
      }]
        deliverOn:self.scheduler]
     subscribeNext:^(id  _Nullable x) {
         @strongify(self)
         [self openInternal];
     }];
}

#pragma mark - Public

- (void)open {
    if (self.state == WebSocketStateClosed) {
        [self openInternal];
    } else {
        NSLog(@"[ws-iOS] websocket already opened or connecting");
    }
}

- (void)close {
    if (self.state == WebSocketStateClosed) {
        NSLog(@"[ws-iOS] websocket already closed");
    } else {
        [self closeInternal];
    }
}

- (void)sendMessage:(NSString *)message {
    if (self.state == WebSocketStateOpen) {
        [self.websocket send:message];
        NSLog(@"[ws-iOS] send success");
    } else {
        NSLog(@"[ws-iOS] send fail");
    }
}

#pragma mark - private

- (void)openInternal {
    if (![AFNetworkReachabilityManager sharedManager].reachable) {
        NSLog(@"[ws-iOS] network unavailable");
        return;
    }
    if (self.state != WebSocketStateClosed) {
        NSLog(@"[ws-iOS] websocket is connecting or opened");
        return;
    }
    self.state = WebSocketStateConnecting;
    [self connect];
    NSLog(@"[ws-iOS] open websocket");
}

- (void)closeInternal {
    self.websocket = nil;
    self.state = WebSocketStateClosed;
    [self clearHeartbeat];
    NSLog(@"[ws-iOS] close websocket");
}

- (void)reopen {
    [self closeInternal];
    [self openInternal];
}

- (void)connect {
    NSURLRequest *request   = [NSURLRequest requestWithURL:[NSURL URLWithString:ServerIP]];
    self.websocket          = [[SRWebSocket alloc] initWithURLRequest:request];
    self.websocket.delegate = self;
    [self.websocket setDelegateDispatchQueue:self.queue];
    [self.websocket open];
}

- (void)startPing {
    @weakify(self)
    self.heartbeatDisposable = [[RACSignal interval:5 onScheduler:self.scheduler] subscribeNext:^(id x) {
        @strongify(self)
        if (self.state == WebSocketStateOpen && self.websocket.readyState == SR_OPEN) {
            NSInteger i = ++self.currentSequence;
            [self.websocket sendPing:[NSData dataWithBytes:&i length:sizeof(i)]];
            NSLog(@"[ws-iOS] ping %zd", i);
            [self scheduleTimeout];
        }
    }];
}

- (void)scheduleTimeout {
    @weakify(self)
    self.timeoutDisposable = [self.scheduler afterDelay:3 schedule:^{
        @strongify(self)
        if (self.state == WebSocketStateOpen) {
            BOOL timeout = NO;
            if (self.currentSequence != self.pongSequence) {
                timeout = YES;
            }
            if (timeout) {
                NSLog(@"[ws-iOS] ping timeout and reopen");
                [self reopen];
            }
        }
    }];
}

- (void)clearHeartbeat {
    if (self.timeoutDisposable) {
        [self.timeoutDisposable dispose];
        self.timeoutDisposable = nil;
    }
    if (self.heartbeatDisposable) {
        [self.heartbeatDisposable dispose];
        self.heartbeatDisposable = nil;
    }
}

#pragma mark - Delegate

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    self.state = WebSocketStateOpen;
    [self startPing];
    NSLog(@"[ws-iOS] websocket open success");
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    NSLog(@"[ws-iOS] receive %@", message);
}

- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload {
    NSInteger i;
    [pongPayload getBytes:&i length:sizeof(i)];
    self.pongSequence = i;
    NSLog(@"[ws-iOS] pong %zd", i);
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    NSLog(@"[ws-iOS] error: %@", error.localizedDescription);
    [self closeInternal];
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {

}

@end
