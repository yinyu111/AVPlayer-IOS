////
////  ViewController.m
////  AVPlayer
////
////  Created by 尹玉 on 2024/8/29.
////
//
//#import "ViewController.h"
//
//// 定义一个静态常量字符串，作为表格视图单元的重用标识符。
//static NSString * const MainTableCellIdentifier = @"MainTableCellIdentifier";
//
//// 类扩展，声明私有属性和方法。
//
//@interface ViewController () <UITableViewDataSource, UITableViewDelegate>
//@property (strong, nonatomic) UITableView *myTableView;
//@property (copy, nonatomic) NSArray *demoList;
//@property (copy, nonatomic) NSArray *demoPageNameList;
//@end
//
//@implementation ViewController
//
//// 使用 #pragma mark 来组织代码，下面是属性的相关方法。
//#pragma mark - Property
//- (UITableView *)myTableView {
//    // 使用懒加载初始化 myTableView。
//    if (!_myTableView) {
//        //初始化_myTableView。[[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped]是创建一个UITableView对象的常用方式。这里使用了alloc来分配内存，initWithFrame:方法设置UITableView的框架（即大小和位置），self.view.bounds表示UITableView的大小和位置与当前控制器的视图相同。style:UITableViewStyleGrouped表示UITableView的风格为分组样式。
//        _myTableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
//        //这一行代码将当前控制器设置为UITableView的代理。delegate属性用于处理UITableView的事件响应，如行选中、行高度等。self表示当前控制器对象，意味着当前控制器需要遵守UITableViewDelegate协议，并实现相应的方法。
//        _myTableView.delegate = self;
//        //这一行代码将当前控制器设置为UITableView的数据源。dataSource属性用于提供UITableView显示的数据，如行数、单元格内容等。self表示当前控制器对象，意味着当前控制器需要遵守UITableViewDataSource协议，并实现相应的方法。
//        _myTableView.dataSource = self;
//    }
//    return _myTableView;
//}
//
//// 生命周期方法
//#pragma mark - Lifecycle
////UIViewController类的方法，当控制器的视图被加载到内存时会被调用。这个方法是设置视图和子视图的常用地方。
//- (void)viewDidLoad {
//    [super viewDidLoad];
//    // Do any additional setup after loading the view.
//    // 初始化示例列表和页面名称列表。
//    self.demoList = @[@"Audio Capture"];
//    self.demoPageNameList = @[@"AudioCaptureViewController"];
//    // 调用 setupUI 方法来设置用户界面。
//    [self setupUI];
//}
//
//// 设置用户界面的方法
//#pragma mark - Setup
//- (void)setupUI {
//    // 设置视图控制器的布局属性，以使用全屏布局。这意味着视图将延伸到所有边缘，包括状态栏和导航栏下面，实现全屏布局。
//    self.edgesForExtendedLayout = UIRectEdgeAll;
//    self.extendedLayoutIncludesOpaqueBars = YES;
//    // 设置标题。
//    self.title = @"Demos";
//    // 设置背景颜色。
//    self.view.backgroundColor = [UIColor whiteColor];
//    // 添加 myTableView 到视图层次结构中，并设置自动布局约束。
//    [self.view addSubview:self.myTableView];
//    self.myTableView.translatesAutoresizingMaskIntoConstraints = NO;
//    [self.view addConstraints:@[
//                                [NSLayoutConstraint constraintWithItem:self.myTableView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0],
//                                [NSLayoutConstraint constraintWithItem:self.myTableView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeRight multiplier:1.0 constant:0],
//                                [NSLayoutConstraint constraintWithItem:self.myTableView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view.safeAreaLayoutGuide attribute:NSLayoutAttributeTop multiplier:1.0 constant:0],
//                                [NSLayoutConstraint constraintWithItem:self.myTableView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.view.safeAreaLayoutGuide attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0],
//                                ]];
//}
//
//// 导航相关方法
//#pragma mark - Navigation
//- (void)goToDemoPageWithViewControllerName:(NSString *)name {
//    // 使用字符串来动态创建和推送视图控制器。
//    UIViewController *vc = [(UIViewController *) [NSClassFromString(name) alloc] init];
//    [self.navigationController pushViewController:vc animated:YES];
//}
//
//// UITableViewDelegate 方法
//#pragma mark - UITableViewDelegate
//- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
//    // 取消选中单元格的突出显示。
//    [tableView deselectRowAtIndexPath:indexPath animated:YES];
//    // 根据选中的索引路径，导航到对应的示例页面。
//    [self goToDemoPageWithViewControllerName:self.demoPageNameList[indexPath.row]];
//}
//
//- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
//    // 返回单元格的高度。
//    return 50;
//}
//
//// UITableViewDataSource 方法
//#pragma mark - UITableViewDataSource
//- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
//    // 返回表格视图中的节数。
//    return 1;
//}
//
//- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
//    // 返回节的头部标题。
//    return @"Demos";
//}
//
//- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
//    // 返回每个节中的行数。
//    return self.demoList.count;
//}
//
//- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
//    // 重新使用或创建单元格，并设置其文本。
//    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MainTableCellIdentifier];
//    if (!cell) {
//        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:MainTableCellIdentifier];
//    }
//    NSString *demoTitle = self.demoList[indexPath.row];
//    cell.textLabel.text = demoTitle;
//    return cell;
//}
//
//
//@end

#import "ViewController.h"

static NSString * const MainTableCellIdentifier = @"MainTableCellIdentifier";

@interface ViewController () <UITableViewDataSource, UITableViewDelegate>
@property (strong, nonatomic) UITableView *myTableView;
@property (copy, nonatomic) NSArray *demoList;
@property (copy, nonatomic) NSArray *demoPageNameList;
@end

@implementation ViewController

#pragma mark - Property
- (UITableView *)myTableView {
    if (!_myTableView) {
        _myTableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
        _myTableView.delegate = self;
        _myTableView.dataSource = self;
    }
    
    return _myTableView;
}

#pragma mark - Lifecycle
- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.demoList = @[@"Audio Capture", @"Audio Demuxer"];
    self.demoPageNameList = @[@"AudioCaptureViewController", @"AudioDemuxerViewController"];
    
    [self setupUI];
}

#pragma mark - Setup
- (void)setupUI {
    // Use full screen layout.
    self.edgesForExtendedLayout = UIRectEdgeAll;
    self.extendedLayoutIncludesOpaqueBars = YES;
    
    self.title = @"Demos";
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    // myTableView.
    [self.view addSubview:self.myTableView];
    self.myTableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addConstraints:@[
                                [NSLayoutConstraint constraintWithItem:self.myTableView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0],
                                [NSLayoutConstraint constraintWithItem:self.myTableView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeRight multiplier:1.0 constant:0],
                                [NSLayoutConstraint constraintWithItem:self.myTableView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view.safeAreaLayoutGuide attribute:NSLayoutAttributeTop multiplier:1.0 constant:0],
                                [NSLayoutConstraint constraintWithItem:self.myTableView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.view.safeAreaLayoutGuide attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0],
                                ]];
}

#pragma mark - Navigation
- (void)goToDemoPageWithViewControllerName:(NSString *)name {
    UIViewController *vc = [(UIViewController *) [NSClassFromString(name) alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    [self goToDemoPageWithViewControllerName:self.demoPageNameList[indexPath.row]];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50;
}

#pragma mark - UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @"Demos";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.demoList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MainTableCellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:MainTableCellIdentifier];
    }
    
    NSString *demoTitle = self.demoList[indexPath.row];
    cell.textLabel.text = demoTitle;
    
    return cell;
}


@end
