// duo-lint test fixture (Objective-C). Checked only with --objc or when passed by name.
// Each line marked "expect:" must produce exactly the rules listed after it.
#import <UIKit/UIKit.h>

@interface LegacyObjCViewController : UIViewController
@end

@implementation LegacyObjCViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    CGFloat width = [UIScreen mainScreen].bounds.size.width; // expect: DUO001
    CGFloat scale = UIScreen.mainScreen.scale; // expect: DUO001
    if (UIDeviceOrientationIsLandscape([[UIDevice currentDevice] orientation])) { // expect: DUO002
        NSLog(@"%f %f", width, scale);
    }
    if ([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationPortrait) { // expect: DUO003
        NSLog(@"portrait");
    }
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) { // expect: DUO004
        NSLog(@"pad");
    }
    if (self.view.bounds.size.height == 844) { // expect: DUO006
        NSLog(@"iPhone 14");
    }
    [self.view.widthAnchor constraintEqualToConstant:390].active = YES; // expect: DUO007
    NSLog(@"[UIScreen mainScreen] inside a string is fine");
    /* [[UIDevice currentDevice] orientation] inside a comment is fine */
}

@end
