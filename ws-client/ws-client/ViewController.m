//
//  ViewController.m
//  ws-client
//
//  Created by Theresa on 2017/8/8.
//  Copyright © 2017年 Theresa. All rights reserved.
//

#import <ReactiveObjC/ReactiveObjC.h>

#import "ViewController.h"

#import "WebsocketClient.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UITextField *textField;

@end

@implementation ViewController

- (IBAction)start:(id)sender {
    [[WebsocketClient sharedClient] open];
}

- (IBAction)stop:(id)sender {
    [[WebsocketClient sharedClient] close];
}

- (IBAction)send:(id)sender {
    [[WebsocketClient sharedClient] sendMessage:self.textField.text];
}

@end
