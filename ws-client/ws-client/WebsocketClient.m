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

@property (nonatomic, strong) RACSubject    *subject;
@property (nonatomic, strong) RACScheduler  *scheduler;
@property (nonatomic, strong) RACDisposable *timeoutDisposable;
@property (nonatomic, strong) RACDisposable *heartbeatDisposable;

@end

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
        _subject = [RACSubject subject];
        _receiveMessageSignal = _subject;
        _queue = dispatch_queue_create("com.Hime.Websocket", DISPATCH_QUEUE_SERIAL);
        _scheduler = [[RACTargetQueueScheduler alloc] initWithName:@"com.Websocket.Scheduler" targetQueue:_queue];
    }
    return self;
}

- (void)setup {
    @weakify(self)
    [[[[[RACObserve([AFNetworkReachabilityManager sharedManager], reachable)
         skip:1]
        distinctUntilChanged]
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
        [self.subject sendNext:@"websocket already opened or connecting"];
    }
}

- (void)close {
    if (self.state == WebSocketStateClosed) {
        [self.subject sendNext:@"websocket already closed"];
    } else {
        [self closeInternal];
    }
}

- (void)sendMessage:(NSString *)message {
    if (self.state == WebSocketStateOpen) {
        [self.websocket send:message];
        [self.subject sendNext:@"send success"];
    } else {
        [self.subject sendNext:@"send fail"];
    }
}

#pragma mark - private

- (void)openInternal {
    self.state = WebSocketStateConnecting;
    [self connect];
    [self.subject sendNext:@"open websocket"];
}

- (void)closeInternal {
    self.websocket = nil;
    self.state = WebSocketStateClosed;
    [self clearHeartbeat];
    [self.subject sendNext:@"close websocket"];
}

- (void)reopen {
    [self closeInternal];
    [self openInternal];
}

- (void)connect {
    NSURLRequest *request   = [NSURLRequest requestWithURL:[NSURL URLWithString:@"ws://127.0.0.1:8089"]];
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
            [self.subject sendNext:[NSString stringWithFormat:@"ping %zd", i]];
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
    [self.subject sendNext:[NSString stringWithFormat:@"websocket open success"]];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    [self.subject sendNext:[NSString stringWithFormat:@"receive %@", message]];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload {
    NSInteger i;
    [pongPayload getBytes:&i length:sizeof(i)];
    self.pongSequence = i;
    [self.subject sendNext:[NSString stringWithFormat:@"pong %zd", i]];
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    [self.subject sendNext:[NSString stringWithFormat:@"error: %@", error.localizedDescription]];
    [self closeInternal];
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {

}

@end
