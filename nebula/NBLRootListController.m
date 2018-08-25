#include "NBLRootListController.h"
#include "NBLWhitelistController.h"
#import <AppList/AppList.h>
#import <objc/runtime.h>

#define kWidth [[UIApplication sharedApplication] keyWindow].frame.size.width

@protocol PreferencesTableCustomView
- (id)initWithSpecifier:(id)arg1;

@optional
- (CGFloat)preferredHeightForWidth:(CGFloat)arg1;
- (CGFloat)preferredHeightForWidth:(CGFloat)arg1 inTableView:(id)arg2;
@end

@interface SQDPrefBannerView : UITableViewCell <PreferencesTableCustomView> {
    UILabel *label;
}

@end
//banner
@implementation SQDPrefBannerView

- (id)initWithSpecifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
    if (self) {

        CGRect labelFrame = CGRectMake(0, -15, kWidth, 70);

        label = [[UILabel alloc] initWithFrame:labelFrame];

        [label.layer setMasksToBounds:YES];
        [label setNumberOfLines:1];
        label.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:40];

        label.textColor = [UIColor blackColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.text = @"Nebula";
        //label.alpha = 0.0;
        [self addSubview:label];

        //fade in
        //[UIView animateWithDuration:1.3 animations:^() {
          //  label.alpha = 1.0;
        //}];

    }
    return self;
}
- (CGFloat)preferredHeightForWidth:(CGFloat)arg1 {
    return 70.0f;
}
@end

@interface PSTableCell : UITableViewCell
@end

@implementation PSTableCell (Nebula)

+ (void)load {
	//if we were to swizzle twice, after the second swizzle, our changes would be reversed
	//we can override +load because very few classes implement this method (and PSTableCell is no exception)
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		Class class = [self class];

		//get the original selector and the new selector we add (remember this is a category)
		//in categories you can add selectors
		SEL originalSelector = @selector(layoutSubviews);
		SEL swizzledSelector = @selector(nebulaLayoutSubviews);

		//we are swizzling layoutSubviews, which is an instance method, so we need the instance methods
		//of course, our new method is also an instance method
		Method originalMethod = class_getInstanceMethod(class, originalSelector);
		Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);

		//add the method. At this stage, there is no exchange of implementations.
		BOOL didAddMethod =
		class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));

		//if it managed to add the method, we can simply replace layoutSubviews with our custom one
		//this means that any calls to layoutSubviews will be redirected to nebulaLayoutSubviews
		if (didAddMethod) {
			class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
		} else {
			//if, for whatever reason, the method wasn't added, we can just swap the implementations round
			//this basically means that the code from nebulaLayoutSubviews will be put inside layoutSubviews.
			//this has the same effect as swapping around the methods, but is a different approach
			//rather than redirecting, we simply run different code
			method_exchangeImplementations(originalMethod, swizzledMethod);
		}
	});
}

- (void)nebulaLayoutSubviews {
	/*
	This looks like it would cause an infinite loop. It doesn't! The code in this method will be run in layoutSubviews,
	and the code from layoutSubviews will be run in this method (the code has been swapped one way or another, see above).
	We are effectively inside layoutSubviews right now. Because nebulaLayoutSubviews contains the original code now,
	calling it is like calling %orig. If we were to not call it, it would have the same possible consequences as forgetting
	%orig (e.g. crashes).
	*/
	[self nebulaLayoutSubviews];
	NSString *keyPath = [[self valueForKeyPath:@"superview.delegate"] respondsToSelector:NSSelectorFromString(@"delegate")] ? @"superview.delegate.delegate.class" : @"superview.delegate.class";
	if([NSStringFromClass((Class)[self valueForKeyPath:keyPath]) isEqualToString:@"NBLRootListController"]) {
		if(self.accessoryView) {
			self.accessoryView.layer.borderWidth = 0;
		}
	}
}

@end


@implementation NBLRootListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
	}

	return _specifiers;
}

-(void)viewWillAppear:(BOOL)a {
	[super viewWillAppear:a];
	id showCredits = ^{
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Credits"
														   message:@"Code by @squ1dd13 and @Muirey03. Graphic design by @TPinpal."
												   	 preferredStyle:UIAlertControllerStyleAlert];

		UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"Thanks!"
													 style:UIAlertActionStyleDefault
												    handler:^(UIAlertAction * action) {}];


		[alert addAction:defaultAction];
		[[[[UIApplication sharedApplication] keyWindow] rootViewController] presentViewController:alert animated:YES completion:nil];
	};
	UIBarButtonItem *creditsButton = [[UIBarButtonItem alloc] initWithTitle:@"Credits" style:UIBarButtonItemStylePlain target:showCredits action:@selector(invoke)];
	creditsButton.tintColor = [UIColor colorWithRed:50/255.0 green:55/255.0 blue:64/255.0 alpha:1.0];
	[self.navigationItem setRightBarButtonItem:creditsButton];

	[UISwitch appearanceWhenContainedIn:self.class, nil].onTintColor = [UIColor colorWithRed:50/255.0 green:55/255.0 blue:64/255.0 alpha:1.0];
}

@end
