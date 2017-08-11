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

@interface ViewController () <UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (nonatomic, strong)  NSMutableArray *array;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.array = [NSMutableArray array];
    self.tableView.dataSource = self;
    self.tableView.rowHeight = 22;
    
    @weakify(self)
    [[[WebsocketClient sharedClient].receiveMessageSignal deliverOnMainThread] subscribeNext:^(id x) {
        @strongify(self)
        [self.array addObject:x];
        if (self.array.count > 12) {
            [self.array removeObjectAtIndex:0];
        }
        [self.tableView reloadData];
    }];
}

- (IBAction)start:(id)sender {
    [[WebsocketClient sharedClient] open];
}

- (IBAction)stop:(id)sender {
    [[WebsocketClient sharedClient] close];
}

- (IBAction)send:(id)sender {
    [[WebsocketClient sharedClient] sendMessage:self.textField.text];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.array.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"test"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"test"];
    }
    cell.textLabel.text = self.array[indexPath.row];
    cell.textLabel.font = [UIFont systemFontOfSize:12];
    return cell;
}

@end
