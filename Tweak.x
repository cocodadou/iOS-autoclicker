#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "ZSFakeTouch/ZSFakeTouchDome/ZSFakeTouch/ZSFakeTouch.h"

@interface ACPoint : NSObject
@property(nonatomic) BOOL enabled;
@property(nonatomic) CGPoint point;
@property(nonatomic) NSTimeInterval delayAfter;
@property(nonatomic) NSTimeInterval holdDuration;
@property(nonatomic) NSInteger repeats;
@property(nonatomic,strong) UIView *marker;
@end

@implementation ACPoint
@end

@interface ACPassthroughWindow : UIWindow
@end

@implementation ACPassthroughWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return hit == self ? nil : hit;
}
- (BOOL)_canAffectStatusBarAppearance {
    return NO;
}
@end

@interface AdvancedAutoClicker : NSObject <UITextFieldDelegate>
@property(nonatomic,strong) ACPassthroughWindow *window;
@property(nonatomic,strong) UIView *bar;
@property(nonatomic,strong) UIButton *runButton;

@property(nonatomic,strong) UIView *globalPanel;
@property(nonatomic,strong) UITextField *initialDelayField;
@property(nonatomic,strong) UITextField *loopField;

@property(nonatomic,strong) UIView *pointPanel;
@property(nonatomic,strong) UILabel *pointTitle;
@property(nonatomic,strong) UITextField *pointDelayField;
@property(nonatomic,strong) UITextField *pointHoldField;
@property(nonatomic,strong) UITextField *pointRepeatField;

@property(nonatomic,strong) UIView *presetPanel;
@property(nonatomic,strong) UILabel *presetStatusLabel;

@property(nonatomic,strong) NSMutableArray<ACPoint *> *points;
@property(nonatomic,strong) ACPoint *selectedPoint;

@property(nonatomic) BOOL running;
@property(nonatomic) NSTimeInterval initialDelay;
@property(nonatomic) NSInteger loopCount;
@property(nonatomic) NSInteger currentLoop;
@property(nonatomic) NSInteger currentPointIndex;

@property(nonatomic) CGRect pointPanelFrameBeforeKeyboard;
@property(nonatomic) BOOL keyboardVisible;

+ (instancetype)shared;
- (void)install;
@end

@implementation AdvancedAutoClicker

+ (instancetype)shared {
    static AdvancedAutoClicker *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [AdvancedAutoClicker new];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _points = [NSMutableArray array];
        _initialDelay = 0.0;
        _loopCount = 0;
        _keyboardVisible = NO;
        [self loadSettings];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillShow:)
                                                     name:UIKeyboardWillShowNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillHide:)
                                                     name:UIKeyboardWillHideNotification
                                                   object:nil];
    }
    return self;
}

#pragma mark - Persistence

- (NSString *)settingsKey {
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier ?: @"unknown";
    return [@"AdvancedAutoClicker.v3.current." stringByAppendingString:bundleID];
}

- (NSString *)presetKeyForSlot:(NSInteger)slot {
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier ?: @"unknown";
    return [NSString stringWithFormat:@"AdvancedAutoClicker.v3.preset.%@.%ld", bundleID, (long)slot];
}

- (NSDictionary *)serializedConfiguration {
    NSMutableArray *savedPoints = [NSMutableArray array];

    for (ACPoint *point in self.points) {
        [savedPoints addObject:@{
            @"enabled": @(point.enabled),
            @"x": @(point.point.x),
            @"y": @(point.point.y),
            @"delayAfter": @(point.delayAfter),
            @"holdDuration": @(point.holdDuration),
            @"repeats": @(point.repeats)
        }];
    }

    return @{
        @"initialDelay": @(self.initialDelay),
        @"loopCount": @(self.loopCount),
        @"points": savedPoints
    };
}

- (void)applyConfiguration:(NSDictionary *)saved rebuildMarkers:(BOOL)rebuildMarkers {
    if (![saved isKindOfClass:NSDictionary.class]) {
        return;
    }

    self.initialDelay = MAX(0.0, [saved[@"initialDelay"] doubleValue]);
    self.loopCount = MAX(0, [saved[@"loopCount"] integerValue]);

    if (rebuildMarkers) {
        for (ACPoint *point in self.points) {
            [point.marker removeFromSuperview];
        }
    }

    [self.points removeAllObjects];

    NSArray *savedPoints = saved[@"points"];
    if ([savedPoints isKindOfClass:NSArray.class]) {
        for (NSDictionary *item in savedPoints) {
            if (![item isKindOfClass:NSDictionary.class]) {
                continue;
            }

            ACPoint *point = [ACPoint new];
            point.enabled = item[@"enabled"] ? [item[@"enabled"] boolValue] : YES;
            point.point = CGPointMake([item[@"x"] doubleValue], [item[@"y"] doubleValue]);
            point.delayAfter = MAX(0.0, [item[@"delayAfter"] doubleValue]);
            point.holdDuration = MAX(0.001, [item[@"holdDuration"] doubleValue]);
            point.repeats = MAX(1, [item[@"repeats"] integerValue]);

            [self.points addObject:point];
        }
    }

    if (rebuildMarkers && self.window) {
        for (ACPoint *point in self.points) {
            [self createMarkerForPoint:point];
        }
        [self refreshMarkerNumbers];
    }

    if (self.globalPanel) {
        self.initialDelayField.text = [NSString stringWithFormat:@"%.2f", self.initialDelay];
        self.loopField.text = [NSString stringWithFormat:@"%ld", (long)self.loopCount];
    }
}

- (void)loadSettings {
    NSDictionary *saved = [NSUserDefaults.standardUserDefaults dictionaryForKey:[self settingsKey]];
    if (saved) {
        [self applyConfiguration:saved rebuildMarkers:NO];
    }
}

- (void)saveSettings {
    [NSUserDefaults.standardUserDefaults setObject:[self serializedConfiguration]
                                           forKey:[self settingsKey]];
}

- (void)savePresetSlot:(NSInteger)slot {
    [self commitFields];

    NSDictionary *configuration = [self serializedConfiguration];
    [NSUserDefaults.standardUserDefaults setObject:configuration
                                           forKey:[self presetKeyForSlot:slot]];

    self.presetStatusLabel.text = [NSString stringWithFormat:@"Preset %ld saved", (long)slot];
}

- (void)loadPresetSlot:(NSInteger)slot {
    NSDictionary *saved = [NSUserDefaults.standardUserDefaults dictionaryForKey:[self presetKeyForSlot:slot]];

    if (!saved) {
        self.presetStatusLabel.text = [NSString stringWithFormat:@"Preset %ld is empty", (long)slot];
        return;
    }

    [self stop];
    [self.window endEditing:YES];
    self.pointPanel.hidden = YES;
    self.selectedPoint = nil;

    [self applyConfiguration:saved rebuildMarkers:YES];
    [self saveSettings];

    self.presetStatusLabel.text = [NSString stringWithFormat:@"Preset %ld loaded", (long)slot];
}

#pragma mark - Keyboard

- (UIToolbar *)keyboardToolbar {
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 0, 44)];

    UIBarButtonItem *flex = [[UIBarButtonItem alloc]
                            initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                            target:nil
                            action:nil];

    UIBarButtonItem *done = [[UIBarButtonItem alloc]
                            initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                            target:self
                            action:@selector(dismissKeyboard)];

    toolbar.items = @[flex, done];
    return toolbar;
}

- (void)dismissKeyboard {
    [self.window endEditing:YES];
    [self commitFields];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    if (!self.pointPanel || self.pointPanel.hidden || self.keyboardVisible) {
        return;
    }

    CGRect keyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    keyboardFrame = [self.window convertRect:keyboardFrame fromWindow:nil];

    self.pointPanelFrameBeforeKeyboard = self.pointPanel.frame;
    self.keyboardVisible = YES;

    CGFloat availableBottom = CGRectGetMinY(keyboardFrame) - 8.0;
    CGFloat currentBottom = CGRectGetMaxY(self.pointPanel.frame);

    if (currentBottom <= availableBottom) {
        return;
    }

    CGRect target = self.pointPanel.frame;
    target.origin.y -= (currentBottom - availableBottom);

    CGFloat safeTop = self.window.safeAreaInsets.top + 8.0;
    target.origin.y = MAX(safeTop, target.origin.y);

    [UIView animateWithDuration:0.25 animations:^{
        self.pointPanel.frame = target;
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    if (!self.keyboardVisible) {
        return;
    }

    self.keyboardVisible = NO;

    if (!self.pointPanel.hidden && !CGRectIsEmpty(self.pointPanelFrameBeforeKeyboard)) {
        CGRect restore = self.pointPanelFrameBeforeKeyboard;

        [UIView animateWithDuration:0.25 animations:^{
            self.pointPanel.frame = restore;
        }];
    }

    self.pointPanelFrameBeforeKeyboard = CGRectZero;
}

#pragma mark - UI helpers

- (UILabel *)labelWithText:(NSString *)text frame:(CGRect)frame fontSize:(CGFloat)fontSize {
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.text = text;
    label.textColor = UIColor.whiteColor;
    label.font = [UIFont systemFontOfSize:fontSize];
    return label;
}

- (UIButton *)buttonWithTitle:(NSString *)title frame:(CGRect)frame action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = frame;
    button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
    button.layer.cornerRadius = 10.0;
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UITextField *)numberFieldWithFrame:(CGRect)frame {
    UITextField *field = [[UITextField alloc] initWithFrame:frame];
    field.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    field.textColor = UIColor.whiteColor;
    field.tintColor = UIColor.whiteColor;
    field.textAlignment = NSTextAlignmentCenter;
    field.layer.cornerRadius = 8.0;
    field.keyboardType = UIKeyboardTypeDecimalPad;
    field.delegate = self;
    field.inputAccessoryView = [self keyboardToolbar];
    return field;
}

- (void)commitFields {
    if (self.globalPanel && !self.globalPanel.hidden) {
        self.initialDelay = MAX(0.0, self.initialDelayField.text.doubleValue);
        self.loopCount = MAX(0, self.loopField.text.integerValue);
    }

    if (self.selectedPoint && self.pointPanel && !self.pointPanel.hidden) {
        self.selectedPoint.delayAfter = MAX(0.0, self.pointDelayField.text.doubleValue);
        self.selectedPoint.holdDuration = MAX(0.001, self.pointHoldField.text.doubleValue);
        self.selectedPoint.repeats = MAX(1, self.pointRepeatField.text.integerValue);
    }

    [self saveSettings];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self commitFields];
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    [self commitFields];
}

#pragma mark - Marker management

- (NSInteger)indexForPoint:(ACPoint *)point {
    NSUInteger index = [self.points indexOfObjectIdenticalTo:point];
    return index == NSNotFound ? -1 : (NSInteger)index;
}

- (void)refreshMarkerNumbers {
    [self.points enumerateObjectsUsingBlock:^(ACPoint *point, NSUInteger idx, BOOL *stop) {
        UILabel *label = [point.marker viewWithTag:101];
        label.text = [NSString stringWithFormat:@"%lu", (unsigned long)(idx + 1)];
    }];
}

- (UIView *)createMarkerForPoint:(ACPoint *)point {
    UIView *marker = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 42, 42)];
    marker.center = point.point;
    marker.layer.cornerRadius = 21.0;
    marker.backgroundColor = [[UIColor systemRedColor] colorWithAlphaComponent:0.82];
    marker.layer.borderWidth = 2.0;
    marker.layer.borderColor = UIColor.whiteColor.CGColor;
    marker.userInteractionEnabled = YES;

    UILabel *number = [[UILabel alloc] initWithFrame:marker.bounds];
    number.tag = 101;
    number.textAlignment = NSTextAlignmentCenter;
    number.textColor = UIColor.whiteColor;
    number.font = [UIFont boldSystemFontOfSize:15.0];
    [marker addSubview:number];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
                                  initWithTarget:self
                                  action:@selector(dragMarker:)];
    [marker addGestureRecognizer:pan];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                  initWithTarget:self
                                  action:@selector(selectMarker:)];
    [marker addGestureRecognizer:tap];

    point.marker = marker;
    [self.window addSubview:marker];
    return marker;
}

- (void)addPoint {
    CGRect bounds = UIScreen.mainScreen.bounds;

    ACPoint *point = [ACPoint new];
    point.enabled = YES;
    point.point = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
    point.delayAfter = 1.0;
    point.holdDuration = 0.06;
    point.repeats = 1;

    [self.points addObject:point];
    [self createMarkerForPoint:point];
    [self refreshMarkerNumbers];
    [self saveSettings];
    [self showPointPanelForPoint:point];
}

- (void)deleteSelectedPoint {
    if (!self.selectedPoint) {
        return;
    }

    [self.window endEditing:YES];

    ACPoint *point = self.selectedPoint;
    [point.marker removeFromSuperview];
    [self.points removeObjectIdenticalTo:point];
    self.selectedPoint = nil;
    self.pointPanel.hidden = YES;

    [self refreshMarkerNumbers];
    [self saveSettings];
}

- (void)dragMarker:(UIPanGestureRecognizer *)gesture {
    UIView *marker = gesture.view;
    CGPoint translation = [gesture translationInView:self.window];

    CGPoint newCenter = CGPointMake(marker.center.x + translation.x,
                                    marker.center.y + translation.y);

    CGFloat halfW = marker.bounds.size.width * 0.5;
    CGFloat halfH = marker.bounds.size.height * 0.5;
    CGRect bounds = self.window.bounds;

    newCenter.x = MAX(halfW, MIN(bounds.size.width - halfW, newCenter.x));
    newCenter.y = MAX(halfH, MIN(bounds.size.height - halfH, newCenter.y));

    marker.center = newCenter;
    [gesture setTranslation:CGPointZero inView:self.window];

    for (ACPoint *point in self.points) {
        if (point.marker == marker) {
            point.point = newCenter;

            if (gesture.state == UIGestureRecognizerStateEnded ||
                gesture.state == UIGestureRecognizerStateCancelled) {
                [self saveSettings];
            }
            break;
        }
    }
}

- (void)selectMarker:(UITapGestureRecognizer *)gesture {
    UIView *marker = gesture.view;

    for (ACPoint *point in self.points) {
        if (point.marker == marker) {
            [self showPointPanelForPoint:point];
            break;
        }
    }
}

#pragma mark - Global panel

- (void)buildGlobalPanel {
    self.globalPanel = [[UIView alloc] initWithFrame:CGRectMake(18, 120, 280, 270)];
    self.globalPanel.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.94];
    self.globalPanel.layer.cornerRadius = 18.0;
    self.globalPanel.hidden = YES;
    [self.window addSubview:self.globalPanel];

    UILabel *title = [self labelWithText:@"AutoClicker"
                                   frame:CGRectMake(16, 12, 180, 28)
                                fontSize:19];
    title.font = [UIFont boldSystemFontOfSize:19];
    [self.globalPanel addSubview:title];

    UIButton *close = [self buttonWithTitle:@"×"
                                      frame:CGRectMake(230, 10, 36, 32)
                                     action:@selector(toggleGlobalPanel)];
    [self.globalPanel addSubview:close];

    [self.globalPanel addSubview:
        [self labelWithText:@"Initial wait"
                      frame:CGRectMake(16, 55, 105, 32)
                   fontSize:14]];

    self.initialDelayField = [self numberFieldWithFrame:CGRectMake(140, 55, 90, 32)];
    self.initialDelayField.text = [NSString stringWithFormat:@"%.2f", self.initialDelay];
    [self.globalPanel addSubview:self.initialDelayField];

    [self.globalPanel addSubview:
        [self labelWithText:@"Loops (0 = ∞)"
                      frame:CGRectMake(16, 95, 110, 32)
                   fontSize:14]];

    self.loopField = [self numberFieldWithFrame:CGRectMake(140, 95, 90, 32)];
    self.loopField.text = [NSString stringWithFormat:@"%ld", (long)self.loopCount];
    self.loopField.keyboardType = UIKeyboardTypeNumberPad;
    [self.globalPanel addSubview:self.loopField];

    UIButton *add = [self buttonWithTitle:@"+ Add point"
                                    frame:CGRectMake(16, 145, 118, 42)
                                   action:@selector(addPoint)];
    [self.globalPanel addSubview:add];

    UIButton *presets = [self buttonWithTitle:@"Presets"
                                        frame:CGRectMake(146, 145, 118, 42)
                                       action:@selector(togglePresetPanel)];
    [self.globalPanel addSubview:presets];

    UIButton *hide = [self buttonWithTitle:@"Hide panel"
                                     frame:CGRectMake(16, 200, 248, 42)
                                    action:@selector(toggleGlobalPanel)];
    [self.globalPanel addSubview:hide];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
                                  initWithTarget:self
                                  action:@selector(dragGlobalPanel:)];
    [self.globalPanel addGestureRecognizer:pan];
}

#pragma mark - Point panel

- (void)buildPointPanel {
    self.pointPanel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 250, 248)];
    self.pointPanel.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.96];
    self.pointPanel.layer.cornerRadius = 18.0;
    self.pointPanel.hidden = YES;
    [self.window addSubview:self.pointPanel];

    self.pointTitle = [self labelWithText:@"Point"
                                    frame:CGRectMake(16, 12, 140, 28)
                                 fontSize:18];
    self.pointTitle.font = [UIFont boldSystemFontOfSize:18];
    [self.pointPanel addSubview:self.pointTitle];

    UIButton *close = [self buttonWithTitle:@"×"
                                      frame:CGRectMake(198, 10, 36, 32)
                                     action:@selector(hidePointPanel)];
    [self.pointPanel addSubview:close];

    [self.pointPanel addSubview:
        [self labelWithText:@"Wait after tap"
                      frame:CGRectMake(16, 55, 112, 32)
                   fontSize:14]];

    self.pointDelayField = [self numberFieldWithFrame:CGRectMake(142, 55, 80, 32)];
    [self.pointPanel addSubview:self.pointDelayField];

    [self.pointPanel addSubview:
        [self labelWithText:@"Hold duration"
                      frame:CGRectMake(16, 95, 112, 32)
                   fontSize:14]];

    self.pointHoldField = [self numberFieldWithFrame:CGRectMake(142, 95, 80, 32)];
    [self.pointPanel addSubview:self.pointHoldField];

    [self.pointPanel addSubview:
        [self labelWithText:@"Repeat count"
                      frame:CGRectMake(16, 135, 112, 32)
                   fontSize:14]];

    self.pointRepeatField = [self numberFieldWithFrame:CGRectMake(142, 135, 80, 32)];
    self.pointRepeatField.keyboardType = UIKeyboardTypeNumberPad;
    [self.pointPanel addSubview:self.pointRepeatField];

    UIButton *delete = [self buttonWithTitle:@"Delete point"
                                       frame:CGRectMake(16, 190, 106, 42)
                                      action:@selector(deleteSelectedPoint)];
    delete.backgroundColor = [[UIColor systemRedColor] colorWithAlphaComponent:0.30];
    [self.pointPanel addSubview:delete];

    UIButton *done = [self buttonWithTitle:@"Done"
                                     frame:CGRectMake(132, 190, 102, 42)
                                    action:@selector(hidePointPanel)];
    [self.pointPanel addSubview:done];
}

- (void)showPointPanelForPoint:(ACPoint *)point {
    [self.window endEditing:YES];
    [self commitFields];

    self.selectedPoint = point;
    NSInteger index = [self indexForPoint:point];

    self.pointTitle.text = [NSString stringWithFormat:@"Point %ld", (long)(index + 1)];
    self.pointDelayField.text = [NSString stringWithFormat:@"%.3f", point.delayAfter];
    self.pointHoldField.text = [NSString stringWithFormat:@"%.3f", point.holdDuration];
    self.pointRepeatField.text = [NSString stringWithFormat:@"%ld", (long)point.repeats];

    CGSize screen = self.window.bounds.size;
    CGPoint markerCenter = point.marker.center;

    CGFloat x = markerCenter.x + 20.0;
    CGFloat y = markerCenter.y + 20.0;

    if (x + self.pointPanel.bounds.size.width > screen.width - 8.0) {
        x = markerCenter.x - self.pointPanel.bounds.size.width - 20.0;
    }

    if (y + self.pointPanel.bounds.size.height > screen.height - 8.0) {
        y = markerCenter.y - self.pointPanel.bounds.size.height - 20.0;
    }

    x = MAX(8.0, MIN(screen.width - self.pointPanel.bounds.size.width - 8.0, x));
    y = MAX(self.window.safeAreaInsets.top + 8.0,
            MIN(screen.height - self.pointPanel.bounds.size.height - 8.0, y));

    self.pointPanel.frame = CGRectMake(x,
                                       y,
                                       self.pointPanel.bounds.size.width,
                                       self.pointPanel.bounds.size.height);

    self.pointPanel.hidden = NO;
}

- (void)hidePointPanel {
    [self.window endEditing:YES];
    [self commitFields];
    self.pointPanel.hidden = YES;
    self.selectedPoint = nil;
}

#pragma mark - Presets panel

- (void)buildPresetPanel {
    self.presetPanel = [[UIView alloc] initWithFrame:CGRectMake(24, 110, 300, 390)];
    self.presetPanel.backgroundColor = [UIColor colorWithWhite:0.04 alpha:0.97];
    self.presetPanel.layer.cornerRadius = 18.0;
    self.presetPanel.hidden = YES;
    [self.window addSubview:self.presetPanel];

    UILabel *title = [self labelWithText:@"Presets"
                                   frame:CGRectMake(16, 12, 180, 28)
                                fontSize:19];
    title.font = [UIFont boldSystemFontOfSize:19];
    [self.presetPanel addSubview:title];

    UIButton *close = [self buttonWithTitle:@"×"
                                      frame:CGRectMake(248, 10, 36, 32)
                                     action:@selector(togglePresetPanel)];
    [self.presetPanel addSubview:close];

    self.presetStatusLabel = [self labelWithText:@"Save or load a complete layout"
                                          frame:CGRectMake(16, 47, 268, 24)
                                       fontSize:12];
    self.presetStatusLabel.textColor = [UIColor colorWithWhite:0.82 alpha:1.0];
    [self.presetPanel addSubview:self.presetStatusLabel];

    CGFloat y = 82.0;

    for (NSInteger slot = 1; slot <= 5; slot++) {
        UILabel *slotLabel = [self labelWithText:[NSString stringWithFormat:@"Preset %ld", (long)slot]
                                          frame:CGRectMake(16, y, 75, 38)
                                       fontSize:14];
        [self.presetPanel addSubview:slotLabel];

        UIButton *load = [self buttonWithTitle:@"Load"
                                         frame:CGRectMake(95, y, 84, 38)
                                        action:@selector(loadPresetButton:)];
        load.tag = slot;
        [self.presetPanel addSubview:load];

        UIButton *save = [self buttonWithTitle:@"Save"
                                         frame:CGRectMake(188, y, 84, 38)
                                        action:@selector(savePresetButton:)];
        save.tag = slot;
        [self.presetPanel addSubview:save];

        y += 52.0;
    }

    UIButton *done = [self buttonWithTitle:@"Done"
                                     frame:CGRectMake(16, 342, 256, 38)
                                    action:@selector(togglePresetPanel)];
    [self.presetPanel addSubview:done];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
                                  initWithTarget:self
                                  action:@selector(dragPresetPanel:)];
    [self.presetPanel addGestureRecognizer:pan];
}

- (void)savePresetButton:(UIButton *)sender {
    [self savePresetSlot:sender.tag];
}

- (void)loadPresetButton:(UIButton *)sender {
    [self loadPresetSlot:sender.tag];
}

- (void)togglePresetPanel {
    [self.window endEditing:YES];
    [self commitFields];

    BOOL willShow = self.presetPanel.hidden;

    self.globalPanel.hidden = YES;
    self.pointPanel.hidden = YES;
    self.selectedPoint = nil;

    self.presetPanel.hidden = !willShow;

    if (willShow) {
        self.presetStatusLabel.text = @"Save or load a complete layout";
    }
}

- (void)dragPresetPanel:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.window];

    self.presetPanel.center = CGPointMake(self.presetPanel.center.x + translation.x,
                                          self.presetPanel.center.y + translation.y);

    [gesture setTranslation:CGPointZero inView:self.window];
}

#pragma mark - General panel actions

- (void)toggleGlobalPanel {
    [self.window endEditing:YES];
    [self commitFields];

    BOOL willShow = self.globalPanel.hidden;

    self.pointPanel.hidden = YES;
    self.presetPanel.hidden = YES;
    self.selectedPoint = nil;
    self.globalPanel.hidden = !willShow;

    if (willShow) {
        self.initialDelayField.text = [NSString stringWithFormat:@"%.2f", self.initialDelay];
        self.loopField.text = [NSString stringWithFormat:@"%ld", (long)self.loopCount];
    }
}

- (void)dragGlobalPanel:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.window];

    self.globalPanel.center = CGPointMake(self.globalPanel.center.x + translation.x,
                                          self.globalPanel.center.y + translation.y);

    [gesture setTranslation:CGPointZero inView:self.window];
}

#pragma mark - Floating toolbar

- (void)dragBar:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.window];

    self.bar.center = CGPointMake(self.bar.center.x + translation.x,
                                  self.bar.center.y + translation.y);

    [gesture setTranslation:CGPointZero inView:self.window];
}

- (void)install {
    if (self.window) {
        return;
    }

    CGRect screen = UIScreen.mainScreen.bounds;

    self.window = [[ACPassthroughWindow alloc] initWithFrame:screen];
    self.window.windowLevel = UIWindowLevelAlert + 50;
    self.window.backgroundColor = UIColor.clearColor;
    self.window.hidden = NO;

    self.bar = [[UIView alloc] initWithFrame:CGRectMake(14, screen.size.height * 0.35, 54, 114)];
    self.bar.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.84];
    self.bar.layer.cornerRadius = 18.0;
    [self.window addSubview:self.bar];

    UIPanGestureRecognizer *barPan = [[UIPanGestureRecognizer alloc]
                                     initWithTarget:self
                                     action:@selector(dragBar:)];
    [self.bar addGestureRecognizer:barPan];

    UIButton *settings = [self buttonWithTitle:@"⚙︎"
                                         frame:CGRectMake(5, 7, 44, 44)
                                        action:@selector(toggleGlobalPanel)];
    settings.titleLabel.font = [UIFont systemFontOfSize:22];
    [self.bar addSubview:settings];

    self.runButton = [self buttonWithTitle:@"▶︎"
                                     frame:CGRectMake(5, 62, 44, 44)
                                    action:@selector(toggleRun)];
    self.runButton.titleLabel.font = [UIFont systemFontOfSize:22];
    [self.bar addSubview:self.runButton];

    [self buildGlobalPanel];
    [self buildPointPanel];
    [self buildPresetPanel];

    for (ACPoint *point in self.points) {
        [self createMarkerForPoint:point];
    }

    [self refreshMarkerNumbers];

    if (self.points.count == 0) {
        [self addPoint];
        self.pointPanel.hidden = YES;
        self.selectedPoint = nil;
    }
}

#pragma mark - Tapping engine

- (void)performTapForPoint:(ACPoint *)point
                 remaining:(NSInteger)remaining
                completion:(dispatch_block_t)completion {
    if (!self.running || remaining <= 0) {
        if (completion) {
            completion();
        }
        return;
    }

    CGPoint location = point.point;
    [ZSFakeTouch beginTouchWithPoint:location];

    NSTimeInterval hold = MAX(0.001, point.holdDuration);
    __weak typeof(self) weakSelf = self;

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(hold * NSEC_PER_SEC)),
        dispatch_get_main_queue(),
        ^{
            [ZSFakeTouch endTouchWithPoint:location];

            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || !strongSelf.running) {
                if (completion) {
                    completion();
                }
                return;
            }

            NSInteger nextRemaining = remaining - 1;

            if (nextRemaining > 0) {
                dispatch_after(
                    dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.03 * NSEC_PER_SEC)),
                    dispatch_get_main_queue(),
                    ^{
                        __strong typeof(weakSelf) innerSelf = weakSelf;

                        if (!innerSelf || !innerSelf.running) {
                            if (completion) {
                                completion();
                            }
                            return;
                        }

                        [innerSelf performTapForPoint:point
                                          remaining:nextRemaining
                                         completion:completion];
                    }
                );
            } else if (completion) {
                completion();
            }
        }
    );
}

- (NSInteger)nextEnabledIndexFrom:(NSInteger)start {
    for (NSInteger i = start; i < self.points.count; i++) {
        if (self.points[i].enabled) {
            return i;
        }
    }

    return NSNotFound;
}

- (void)runNext {
    if (!self.running) {
        return;
    }

    NSInteger index = [self nextEnabledIndexFrom:self.currentPointIndex];

    if (index == NSNotFound) {
        self.currentLoop++;

        if (self.loopCount > 0 && self.currentLoop >= self.loopCount) {
            [self stop];
            return;
        }

        self.currentPointIndex = 0;
        index = [self nextEnabledIndexFrom:0];

        if (index == NSNotFound) {
            [self stop];
            return;
        }
    }

    self.currentPointIndex = index + 1;
    ACPoint *point = self.points[index];

    __weak typeof(self) weakSelf = self;

    [self performTapForPoint:point
                  remaining:MAX(1, point.repeats)
                 completion:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;

        if (!strongSelf || !strongSelf.running) {
            return;
        }

        NSTimeInterval wait = MAX(0.0, point.delayAfter);

        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW, (int64_t)(wait * NSEC_PER_SEC)),
            dispatch_get_main_queue(),
            ^{
                [strongSelf runNext];
            }
        );
    }];
}

- (void)start {
    if (self.running) {
        return;
    }

    [self.window endEditing:YES];
    [self commitFields];

    if ([self nextEnabledIndexFrom:0] == NSNotFound) {
        return;
    }

    self.running = YES;
    self.currentLoop = 0;
    self.currentPointIndex = 0;

    [self.runButton setTitle:@"■" forState:UIControlStateNormal];

    self.globalPanel.hidden = YES;
    self.pointPanel.hidden = YES;
    self.presetPanel.hidden = YES;
    self.selectedPoint = nil;

    NSTimeInterval wait = MAX(0.0, self.initialDelay);
    __weak typeof(self) weakSelf = self;

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(wait * NSEC_PER_SEC)),
        dispatch_get_main_queue(),
        ^{
            [weakSelf runNext];
        }
    );
}

- (void)stop {
    self.running = NO;
    [self.runButton setTitle:@"▶︎" forState:UIControlStateNormal];
}

- (void)toggleRun {
    self.running ? [self stop] : [self start];
}

@end

%ctor {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[AdvancedAutoClicker shared] install];
    });
}
