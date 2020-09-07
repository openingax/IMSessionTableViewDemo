//
//  IMSessionViewController.m
//  IMSessionTableViewDemo
//
//  Created by 谢立颖 on 2020/9/7.
//  Copyright © 2020 xiely. All rights reserved.
//

#import "IMSessionViewController.h"
#import <MJRefresh/MJRefreshNormalHeader.h>

@interface IMSessionViewController () <UITableViewDataSource, UITableViewDelegate>

@property(nonatomic, strong) NSMutableArray *msgList;
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, assign) CGFloat contentYOffset;
@property(nonatomic, assign) NSUInteger virtualMsgCount;

@end

@implementation IMSessionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.msgList = [NSMutableArray new];
    self.virtualMsgCount = 0;
    
    [self setupSubviews];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self fetchMsgList];
}

- (void)setupSubviews {
    BOOL isiPX = NO;    // 全面屏处理底部 34 高度的边距
    static CGFloat kChatInputToolBarHeight = 50;    // 输入框高度
    
    CGFloat tbWidth = CGRectGetWidth([UIScreen mainScreen].bounds);
    CGFloat tbHeight = CGRectGetHeight([UIScreen mainScreen].bounds);
    CGFloat inputBarHeight = isiPX ? (kChatInputToolBarHeight+34) : kChatInputToolBarHeight;
    CGFloat inputBarY = tbHeight - inputBarHeight;
    
    _tableView = [[UITableView alloc] init];
    _tableView.frame = CGRectMake(0, 0, tbWidth, tbHeight - inputBarHeight);
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"tableViewCell"];
    [self.view addSubview:_tableView];
    
    MJRefreshNormalHeader *refreshHeader = [MJRefreshNormalHeader headerWithRefreshingTarget:self refreshingAction:@selector(fetchMsgList)];
    refreshHeader.loadingView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
    refreshHeader.lastUpdatedTimeLabel.hidden = YES;
    refreshHeader.stateLabel.hidden = YES;
    refreshHeader.arrowView.image = nil;
    self.tableView.mj_header = refreshHeader;
    
    UIView *inputView = [[UIView alloc] initWithFrame:CGRectMake(0, inputBarY, tbWidth, inputBarHeight)];
    inputView.backgroundColor = [UIColor lightGrayColor];
    [self.view addSubview:inputView];
}

#pragma mark - UITableViewDelegate & UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _msgList.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *msg = [self.msgList objectAtIndex:indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"tableViewCell" forIndexPath:indexPath];
    if (!cell) {
        return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"tableViewCell"];
    }
    cell.textLabel.text = msg;
    return cell;
}

- (void)fetchMsgList {
    __weak __typeof(self)weakSelf = self;
    [self virtualFetchMsgListWithComplete:^(BOOL isSucc, BOOL hasMoreMsg, NSArray *list) {
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        [strongSelf.tableView.mj_header endRefreshing];
        
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            strongSelf.contentYOffset = strongSelf.tableView.contentOffset.y;
        });
        
        NSMutableArray *indexPaths = [[NSMutableArray alloc] initWithCapacity:list.count];
        [list enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [indexPaths addObject:[NSIndexPath indexPathForRow:idx inSection:0]];
        }];
        
        CGSize beginContentSize = strongSelf.tableView.contentSize;
        CGPoint beginContentOffset = strongSelf.tableView.contentOffset;
        
        CGFloat refreshViewHeight = 0;
        if (!hasMoreMsg) {
            // 没有更多消息了
            refreshViewHeight = strongSelf.tableView.mj_header.frame.size.height;
            strongSelf.tableView.contentInset = UIEdgeInsetsZero;
            [strongSelf.tableView.mj_header removeFromSuperview];
            strongSelf.tableView.mj_header = nil;
        }
        
        [UIView setAnimationsEnabled:NO];
        [strongSelf.tableView beginUpdates];
        [strongSelf.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
        [strongSelf.tableView endUpdates];
        [UIView setAnimationsEnabled:YES];
        
        CGSize endContentSize = strongSelf.tableView.contentSize;
        CGFloat xOffset = beginContentOffset.x;
        CGFloat yOffset = beginContentOffset.y+(endContentSize.height-beginContentSize.height);
        if (beginContentSize.height == 0) {
            yOffset = endContentSize.height - (CGRectGetHeight(strongSelf.tableView.bounds));
            yOffset = MAX(strongSelf.contentYOffset, yOffset); // yOffset 最小为 contentYOffset，当消息不能填满屏幕时触发
        }
        CGPoint endContentOffset = CGPointMake(xOffset, yOffset);
        [strongSelf.tableView setContentOffset:endContentOffset animated:NO];
    }];
}

- (void)virtualFetchMsgListWithComplete:(void(^)(BOOL isSucc, BOOL hasMoreMsg, NSArray *list))complete {
    int msgCount = 5;   // 第一次加载只有5条数据，不充满屏幕，如果想模拟第一次加载充满屏幕，请改大这个数值
    NSMutableArray *array = [[NSMutableArray alloc] init];
    for (int i=0; i < msgCount; i++) {
        NSString *msgObj = [NSString stringWithFormat:@"数据源 - %ld", self.virtualMsgCount++];
        [array insertObject:msgObj atIndex:0];
        [self.msgList insertObject:msgObj atIndex:0];
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (complete) {
            complete(YES, YES, array.copy);
        }
    });
}

@end
