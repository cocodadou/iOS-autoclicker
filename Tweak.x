#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "ZSFakeTouch/ZSFakeTouchDome/ZSFakeTouch/ZSFakeTouch.h"

@interface ACPoint : NSObject
@property(nonatomic) BOOL enabled;
@property(nonatomic) CGPoint point;
@property(nonatomic) NSTimeInterval delayAfter;
@property(nonatomic) NSTimeInterval holdDuration;
@property(nonatomic) NSInteger repeats;
@property(nonatomic) CGFloat jitter;
@property(nonatomic,strong) UIView *marker;
@end
@implementation ACPoint @end

@interface ACPassthroughWindow : UIWindow @end
@implementation ACPassthroughWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return hit == self ? nil : hit;
}
- (BOOL)_canAffectStatusBarAppearance { return NO; }
@end

@interface AdvancedAutoClicker : NSObject
@property(nonatomic,strong) ACPassthroughWindow *window;
@property(nonatomic,strong) UIView *bar;
@property(nonatomic,strong) UIView *panel;
@property(nonatomic,strong) UIScrollView *scroll;
@property(nonatomic,strong) UIButton *runButton;
@property(nonatomic,strong) NSMutableArray<ACPoint *> *points;
@property(nonatomic) BOOL running;
@property(nonatomic) BOOL sequentialMode;
@property(nonatomic) NSTimeInterval initialDelay;
@property(nonatomic) NSInteger loopCount;
@property(nonatomic) NSInteger currentLoop;
@property(nonatomic) NSInteger currentPointIndex;
@property(nonatomic,strong) dispatch_block_t pendingBlock;
+ (instancetype)shared;
- (void)install;
@end

@implementation AdvancedAutoClicker

+ (instancetype)shared {
    static AdvancedAutoClicker *obj;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ obj = [AdvancedAutoClicker new]; });
    return obj;
}

- (instancetype)init {
    if ((self = [super init])) {
        _points = [NSMutableArray array];
        for (NSInteger i = 0; i < 20; i++) {
            ACPoint *p = [ACPoint new];
            p.enabled = NO;
            p.point = CGPointMake(UIScreen.mainScreen.bounds.size.width * 0.5,
                                  UIScreen.mainScreen.bounds.size.height * 0.5);
            p.delayAfter = 1.0;
            p.holdDuration = 0.06;
            p.repeats = 1;
            p.jitter = 0.0;
            [_points addObject:p];
        }
        _sequentialMode = YES;
        _initialDelay = 0;
        _loopCount = 0;
        [self loadSettings];
    }
    return self;
}

- (NSString *)settingsKey {
    NSString *bundle = NSBundle.mainBundle.bundleIdentifier ?: @"unknown";
    return [@"AdvancedAutoClicker." stringByAppendingString:bundle];
}

- (void)saveSettings {
    NSMutableArray *items = [NSMutableArray array];
    for (ACPoint *p in self.points) {
        [items addObject:@{
            @"enabled": @(p.enabled), @"x": @(p.point.x), @"y": @(p.point.y),
            @"delay": @(p.delayAfter), @"hold": @(p.holdDuration),
            @"repeats": @(p.repeats), @"jitter": @(p.jitter)
        }];
    }
    NSDictionary *d = @{@"sequential": @(self.sequentialMode),
                        @"initialDelay": @(self.initialDelay),
                        @"loopCount": @(self.loopCount), @"points": items};
    [NSUserDefaults.standardUserDefaults setObject:d forKey:self.settingsKey];
}

- (void)loadSettings {
    NSDictionary *d = [NSUserDefaults.standardUserDefaults dictionaryForKey:self.settingsKey];
    if (!d) return;
    self.sequentialMode = [d[@"sequential"] boolValue];
    self.initialDelay = [d[@"initialDelay"] doubleValue];
    self.loopCount = [d[@"loopCount"] integerValue];
    NSArray *items = d[@"points"];
    for (NSInteger i = 0; i < MIN(items.count, self.points.count); i++) {
        NSDictionary *v = items[i]; ACPoint *p = self.points[i];
        p.enabled = [v[@"enabled"] boolValue];
        p.point = CGPointMake([v[@"x"] doubleValue], [v[@"y"] doubleValue]);
        p.delayAfter = MAX(0.001, [v[@"delay"] doubleValue]);
        p.holdDuration = MAX(0.001, [v[@"hold"] doubleValue]);
        p.repeats = MAX(1, [v[@"repeats"] integerValue]);
        p.jitter = MAX(0, [v[@"jitter"] doubleValue]);
    }
}

- (UITextField *)field:(CGRect)frame value:(NSString *)value tag:(NSInteger)tag {
    UITextField *f = [[UITextField alloc] initWithFrame:frame];
    f.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
    f.textColor = UIColor.whiteColor;
    f.layer.cornerRadius = 7;
    f.textAlignment = NSTextAlignmentCenter;
    f.keyboardType = UIKeyboardTypeDecimalPad;
    f.text = value;
    f.tag = tag;
    [f addTarget:self action:@selector(fieldChanged:) forControlEvents:UIControlEventEditingDidEnd];
    return f;
}

- (UILabel *)label:(NSString *)text frame:(CGRect)frame size:(CGFloat)size {
    UILabel *l = [[UILabel alloc] initWithFrame:frame];
    l.text = text; l.textColor = UIColor.whiteColor; l.font = [UIFont systemFontOfSize:size];
    return l;
}

- (void)install {
    if (self.window) return;
    CGRect screen = UIScreen.mainScreen.bounds;
    self.window = [[ACPassthroughWindow alloc] initWithFrame:screen];
    self.window.windowLevel = UIWindowLevelAlert + 50;
    self.window.backgroundColor = UIColor.clearColor;
    self.window.hidden = NO;

    for (NSInteger i = 0; i < self.points.count; i++) {
        ACPoint *p = self.points[i];
        UIView *m = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 28, 28)];
        m.center = p.point; m.layer.cornerRadius = 14;
        m.backgroundColor = [[UIColor systemRedColor] colorWithAlphaComponent:0.72];
        m.hidden = !p.enabled; m.userInteractionEnabled = NO;
        UILabel *n = [self label:[NSString stringWithFormat:@"%ld", (long)i+1] frame:m.bounds size:12];
        n.textAlignment = NSTextAlignmentCenter; n.font = [UIFont boldSystemFontOfSize:12];
        [m addSubview:n]; [self.window addSubview:m]; p.marker = m;
    }

    self.bar = [[UIView alloc] initWithFrame:CGRectMake(18, screen.size.height * .35, 52, 104)];
    self.bar.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.72];
    self.bar.layer.cornerRadius = 18;
    [self.window addSubview:self.bar];
    [self.bar addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragBar:)]];

    UIButton *settings = [UIButton buttonWithType:UIButtonTypeSystem];
    settings.frame = CGRectMake(0, 5, 52, 44); [settings setTitle:@"SET" forState:UIControlStateNormal];
    [settings addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    [self.bar addSubview:settings];

    self.runButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.runButton.frame = CGRectMake(0, 54, 52, 44); [self.runButton setTitle:@"GO" forState:UIControlStateNormal];
    [self.runButton addTarget:self action:@selector(toggleRun) forControlEvents:UIControlEventTouchUpInside];
    [self.bar addSubview:self.runButton];

    CGFloat w = MIN(screen.size.width - 24, 390);
    CGFloat h = MIN(screen.size.height - 90, 700);
    self.panel = [[UIView alloc] initWithFrame:CGRectMake((screen.size.width-w)/2, (screen.size.height-h)/2, w, h)];
    self.panel.backgroundColor = [UIColor colorWithWhite:0.04 alpha:0.91];
    self.panel.layer.cornerRadius = 18; self.panel.hidden = YES;
    [self.window addSubview:self.panel];

    self.scroll = [[UIScrollView alloc] initWithFrame:self.panel.bounds];
    self.scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    [self.panel addSubview:self.scroll];

    CGFloat y = 18;
    UILabel *title = [self label:@"Advanced AutoClicker" frame:CGRectMake(18,y,w-36,30) size:20];
    title.font = [UIFont boldSystemFontOfSize:20]; [self.scroll addSubview:title]; y += 42;
    [self.scroll addSubview:[self label:@"Initial delay (s)" frame:CGRectMake(18,y,140,32) size:14]];
    [self.scroll addSubview:[self field:CGRectMake(165,y,90,32) value:[NSString stringWithFormat:@"%.2f",self.initialDelay] tag:10]];
    y += 42;
    [self.scroll addSubview:[self label:@"Loops (0 = infinite)" frame:CGRectMake(18,y,140,32) size:14]];
    [self.scroll addSubview:[self field:CGRectMake(165,y,90,32) value:[NSString stringWithFormat:@"%ld",(long)self.loopCount] tag:11]];
    y += 46;

    for (NSInteger i = 0; i < self.points.count; i++) {
        ACPoint *p = self.points[i];
        UILabel *head = [self label:[NSString stringWithFormat:@"Point %ld",(long)i+1] frame:CGRectMake(18,y,90,30) size:16];
        head.font = [UIFont boldSystemFontOfSize:16]; [self.scroll addSubview:head];
        UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(w-75,y,50,30)]; sw.on = p.enabled; sw.tag = 1000+i;
        [sw addTarget:self action:@selector(pointSwitch:) forControlEvents:UIControlEventValueChanged]; [self.scroll addSubview:sw];
        y += 34;
        [self.scroll addSubview:[self label:@"X" frame:CGRectMake(18,y,20,30) size:13]];
        [self.scroll addSubview:[self field:CGRectMake(38,y,72,30) value:[NSString stringWithFormat:@"%.0f",p.point.x] tag:2000+i]];
        [self.scroll addSubview:[self label:@"Y" frame:CGRectMake(118,y,20,30) size:13]];
        [self.scroll addSubview:[self field:CGRectMake(138,y,72,30) value:[NSString stringWithFormat:@"%.0f",p.point.y] tag:3000+i]];
        UIButton *here = [UIButton buttonWithType:UIButtonTypeSystem]; here.frame = CGRectMake(220,y,w-238,30); [here setTitle:@"Center" forState:UIControlStateNormal]; here.tag=4000+i;
        [here addTarget:self action:@selector(centerPoint:) forControlEvents:UIControlEventTouchUpInside]; [self.scroll addSubview:here];
        y += 38;
        [self.scroll addSubview:[self label:@"Delay" frame:CGRectMake(18,y,42,30) size:12]];
        [self.scroll addSubview:[self field:CGRectMake(60,y,62,30) value:[NSString stringWithFormat:@"%.3f",p.delayAfter] tag:5000+i]];
        [self.scroll addSubview:[self label:@"Hold" frame:CGRectMake(128,y,38,30) size:12]];
        [self.scroll addSubview:[self field:CGRectMake(166,y,62,30) value:[NSString stringWithFormat:@"%.3f",p.holdDuration] tag:6000+i]];
        [self.scroll addSubview:[self label:@"Repeat" frame:CGRectMake(234,y,48,30) size:12]];
        [self.scroll addSubview:[self field:CGRectMake(282,y,54,30) value:[NSString stringWithFormat:@"%ld",(long)p.repeats] tag:7000+i]];
        y += 40;
        [self.scroll addSubview:[self label:@"Jitter px" frame:CGRectMake(18,y,58,30) size:12]];
        [self.scroll addSubview:[self field:CGRectMake(80,y,62,30) value:[NSString stringWithFormat:@"%.1f",p.jitter] tag:8000+i]];
        UIView *line=[[UIView alloc]initWithFrame:CGRectMake(14,y+38,w-28,1)]; line.backgroundColor=[UIColor colorWithWhite:1 alpha:.12]; [self.scroll addSubview:line];
        y += 52;
    }
    self.scroll.contentSize = CGSizeMake(w, y+20);
}

- (void)dragBar:(UIPanGestureRecognizer *)g {
    CGPoint t=[g translationInView:self.window]; self.bar.center=CGPointMake(self.bar.center.x+t.x,self.bar.center.y+t.y); [g setTranslation:CGPointZero inView:self.window];
}
- (void)togglePanel { self.panel.hidden=!self.panel.hidden; }
- (void)pointSwitch:(UISwitch *)s { ACPoint *p=self.points[s.tag-1000]; p.enabled=s.on; p.marker.hidden=!s.on; [self saveSettings]; }
- (void)centerPoint:(UIButton *)b { NSInteger i=b.tag-4000; ACPoint *p=self.points[i]; p.point=CGPointMake(CGRectGetMidX(UIScreen.mainScreen.bounds),CGRectGetMidY(UIScreen.mainScreen.bounds)); p.marker.center=p.point; [self saveSettings]; }

- (void)fieldChanged:(UITextField *)f {
    double v=f.text.doubleValue;
    if (f.tag==10) self.initialDelay=MAX(0,v);
    else if (f.tag==11) self.loopCount=MAX(0,(NSInteger)v);
    else {
        NSInteger i=-1;
        if (f.tag>=8000){i=f.tag-8000; self.points[i].jitter=MAX(0,v);} 
        else if(f.tag>=7000){i=f.tag-7000; self.points[i].repeats=MAX(1,(NSInteger)v);} 
        else if(f.tag>=6000){i=f.tag-6000; self.points[i].holdDuration=MAX(.001,v);} 
        else if(f.tag>=5000){i=f.tag-5000; self.points[i].delayAfter=MAX(.001,v);} 
        else if(f.tag>=3000){i=f.tag-3000; ACPoint*p=self.points[i]; p.point=CGPointMake(p.point.x,v); p.marker.center=p.point;} 
        else if(f.tag>=2000){i=f.tag-2000; ACPoint*p=self.points[i]; p.point=CGPointMake(v,p.point.y); p.marker.center=p.point;}
    }
    [self saveSettings];
}

- (CGPoint)jitteredPoint:(ACPoint *)p {
    if (p.jitter<=0) return p.point;
    CGFloat dx=((arc4random_uniform(10001)/10000.0)*2.0-1.0)*p.jitter;
    CGFloat dy=((arc4random_uniform(10001)/10000.0)*2.0-1.0)*p.jitter;
    return CGPointMake(p.point.x+dx,p.point.y+dy);
}

- (void)tapPoint:(ACPoint *)p completion:(dispatch_block_t)completion {
    __block NSInteger remaining = MAX(1,p.repeats);
    __weak typeof(self) weakSelf=self;
    __block void (^oneTap)(void);
    oneTap = ^{
        if (!weakSelf.running || remaining<=0) { if(completion) completion(); return; }
        CGPoint q=[weakSelf jitteredPoint:p];
        [ZSFakeTouch beginTouchWithPoint:q];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(p.holdDuration*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            [ZSFakeTouch endTouchWithPoint:q]; remaining--;
            if (remaining>0) dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.03*NSEC_PER_SEC)),dispatch_get_main_queue(),oneTap);
            else if(completion) completion();
        });
    };
    oneTap();
}

- (NSInteger)nextEnabledIndexFrom:(NSInteger)start {
    for (NSInteger i=start;i<self.points.count;i++) if(self.points[i].enabled) return i;
    return NSNotFound;
}

- (void)runNext {
    if(!self.running) return;
    NSInteger idx=[self nextEnabledIndexFrom:self.currentPointIndex];
    if(idx==NSNotFound){
        self.currentLoop++;
        if(self.loopCount>0 && self.currentLoop>=self.loopCount){[self stop];return;}
        self.currentPointIndex=0; idx=[self nextEnabledIndexFrom:0];
        if(idx==NSNotFound){[self stop];return;}
    }
    self.currentPointIndex=idx+1; ACPoint*p=self.points[idx];
    __weak typeof(self) weakSelf=self;
    [self tapPoint:p completion:^{
        if(!weakSelf.running)return;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(p.delayAfter*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[weakSelf runNext];});
    }];
}

- (void)start {
    if(self.running)return; self.running=YES; self.currentLoop=0; self.currentPointIndex=0;
    [self.runButton setTitle:@"STOP" forState:UIControlStateNormal];
    __weak typeof(self) weakSelf=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(self.initialDelay*NSEC_PER_SEC)),dispatch_get_main_queue(),^{[weakSelf runNext];});
}
- (void)stop { self.running=NO; [self.runButton setTitle:@"GO" forState:UIControlStateNormal]; }
- (void)toggleRun { self.running ? [self stop] : [self start]; }
@end

%ctor {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[AdvancedAutoClicker shared] install];
    });
}
