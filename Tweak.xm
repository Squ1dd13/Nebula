#define SETTINGS_PLIST_PATH @"/var/mobile/Library/Preferences/com.octodev.nebulacolors.plist"
#define STYLESHEET_PATH @"/Library/Application Support/7361666172696461726b/7374796c65.st"
#define BACKUP_STYLESHEET_PATH @"/Library/Application Support/7361666172696461726b/7374796c66.st"
#define stylesPath @"/Library/Application Support/7361666172696461726b/Themes"

@import WebKit;
@import AudioToolbox;
@import UIKit;

@interface UIImage (Change)
+ (UIImage*)changeImage:(UIImage *)image toColor:(UIColor *)color;
@end

%hook UIImage

%new
+ (UIImage*)changeImage:(UIImage *)image toColor:(UIColor *)color {
	UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
	CGRect imageRect = CGRectMake(0.0f, 0.0f, image.size.width, image.size.height);

	CGContextRef ctx = UIGraphicsGetCurrentContext();

	// Draw a white background (for white mask)
	CGFloat r, g, b, a;
	[color getRed:&r green:&g blue:&b alpha:&a];
	CGContextSetRGBFillColor(ctx, r, g, b, a);
	CGContextFillRect(ctx, imageRect);

	// Apply the source image's alpha
	[image drawInRect:imageRect blendMode:kCGBlendModeDestinationIn alpha:1.0f];

	UIImage* outImage = UIGraphicsGetImageFromCurrentImageContext();

	UIGraphicsEndImageContext();

	return outImage;
}
%end

NSInteger colorProfile;

struct pixel {
	unsigned char r, g, b, a;
};

CGFloat alpha = 1.0;
static UIColor *dominantColorFromImage(UIImage *image) {
    CGImageRef iconCGImage = image.CGImage;
    NSUInteger red = 0, green = 0, blue = 0;
    size_t width = CGImageGetWidth(iconCGImage);
    size_t height = CGImageGetHeight(iconCGImage);
    size_t bitmapBytesPerRow = width * 4;
    size_t bitmapByteCount = bitmapBytesPerRow * height;
    struct pixel *pixels = (struct pixel *)malloc(bitmapByteCount);
    if (pixels) {
        CGContextRef context = CGBitmapContextCreate((void *)pixels, width, height, 8, bitmapBytesPerRow, CGImageGetColorSpace(iconCGImage), kCGImageAlphaPremultipliedLast);
        if (context) {
            CGContextDrawImage(context, CGRectMake(0.0, 0.0, width, height), iconCGImage);
            NSUInteger numberOfPixels = width * height;
            for (size_t i = 0; i < numberOfPixels; i++) {
                red += pixels[i].r;
                green += pixels[i].g;
                blue += pixels[i].b;
            }
            red /= numberOfPixels;
            green /= numberOfPixels;
            blue /= numberOfPixels;
            CGContextRelease(context);
        }
        free(pixels);
    }
    return [UIColor colorWithRed:red/255.0 green:green/255.0 blue:blue/255.0 alpha:alpha];
}

UIColor *avgColor(UIImage *image) {
    UIColor *color = dominantColorFromImage(image);
    return color;
}

NSString *stringBetween(NSString *main, NSString *first, NSString *last) {
	NSString *string = main;
	NSString *result = nil;

	// Determine "<div>" location
	NSRange divRange = [string rangeOfString:first options:NSCaseInsensitiveSearch];
	if (divRange.location != NSNotFound)
	{
		// Determine "</div>" location according to "<div>" location
		NSRange endDivRange;

		endDivRange.location = divRange.length + divRange.location;
		endDivRange.length   = [string length] - endDivRange.location;
		endDivRange = [string rangeOfString:last options:NSCaseInsensitiveSearch range:endDivRange];

		if (endDivRange.location != NSNotFound)
		{
			// Tags found: retrieve string between them
			divRange.location += divRange.length;
			divRange.length = endDivRange.location - divRange.location;

			result = [string substringWithRange:divRange];
			return result;
		}
	}
	return @"";
}

UIImage *resizeImage(UIImage *image, CGSize size) {
	CGFloat scale = MAX(size.width/image.size.width, size.height/image.size.height);
	CGFloat width = image.size.width * scale;
	CGFloat height = image.size.height * scale;
	CGRect imageRect = CGRectMake((size.width - width)/2.0f,
	(size.height - height)/2.0f, width, height);

	UIGraphicsBeginImageContextWithOptions(size, NO, 0);
	[image drawInRect:imageRect];
	UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return newImage;
}

@interface BrowserToolbar : UIToolbar
@property (nonatomic, assign) UIButton *darkButton;
@end

static UIBarButtonItem *nightModeButton = nil;
static NSString *stylesheetFromHex;
static NSString *backupStylesheet;
static BOOL darkMode = NO;
static NSMutableDictionary *customStyles;
static NSArray *backupStylesheetSites = @[];
static NSArray *whitelist;
static NSString* bgColorHex;

//changes a double hex string to a plain string
NSString* fromDoubleHex(NSString* str, NSString* message)
{
	//changes a hex string to a plain string
	NSString *(^fromHex)(NSString *) = ^(NSString *str){
		NSMutableString *newString = [[NSMutableString alloc] init];
		int i = 0;
		while (i < [str length]) {
			NSString *hexChar = [str substringWithRange: NSMakeRange(i, 2)];
			int value = 0;
			sscanf([hexChar cStringUsingEncoding:NSASCIIStringEncoding], "%x", &value);
			[newString appendFormat:@"%c", (char)value];
			i+=2;
		}
		return ((NSString *)[newString copy]);
	};

	NSString *string = str;
	string = fromHex(string);
	NSString *removedMessage = [string stringByReplacingOccurrencesOfString:message withString:@""];
	removedMessage = fromHex(removedMessage);
	return ((NSString *)removedMessage);
}

void loadStylesheetsFromFiles() {
	NSError *err;
	stylesheetFromHex = [NSString stringWithContentsOfFile:STYLESHEET_PATH encoding:NSUTF8StringEncoding error:&err];
	stylesheetFromHex = fromDoubleHex(stylesheetFromHex, @"You can go away now.\n");

	if(err) NSLog(@"ERROR: %@", err.localizedFailureReason);

	backupStylesheet = [NSString stringWithContentsOfFile:BACKUP_STYLESHEET_PATH encoding:NSUTF8StringEncoding error:&err];
	backupStylesheet = fromDoubleHex(backupStylesheet, @"You can go away now.\n");

	if(err) NSLog(@"ERROR: %@", err.localizedFailureReason);

	//load custom stylesheets:
	customStyles = [NSMutableDictionary dictionary];

	NSArray *possibleStyles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:stylesPath error:&err];
	NSArray *validStyles;
	if(err) {
		NSLog(@"Failed to fetch styles folder contents");
	} else {
		//we only want css files. .min.css will also load
		 validStyles = [possibleStyles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF ENDSWITH %@", @"css"]];
		//files should have a /* <host of site> */ comment at the top
		for(NSString *file in validStyles) {
			NSString *fileContents = [NSString stringWithContentsOfFile:[[stylesPath stringByAppendingString:@"/"] stringByAppendingString:file] encoding:NSUTF8StringEncoding error:nil];

			NSString *hostLine = [fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]][0];

			if(!([hostLine hasPrefix:@"/*"] && [hostLine hasSuffix:@"*/"])) {
				continue;
			}
			NSString *host = stringBetween(hostLine, @"/*", @"*/");
			NSLog(@"%@", host);
			if([host containsString:@","]) {
				NSArray *hosts = [host componentsSeparatedByString:@","];
				for(NSString *h in hosts) {
					[customStyles setValue:file forKey:[h stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
				}
			}
			host = [host stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			[customStyles setValue:file forKey:host]; //so we can load this stylesheet based on the host later
			NSLog(@"%@", file);
			NSLog(@"styles %@", customStyles);
		}
	}
}

void changeColorsInStylesheets()
{
	//change colours in main stylesheet
	stylesheetFromHex = [stylesheetFromHex stringByReplacingOccurrencesOfString:@"NEBULA_DARK" withString:bgColorHex];

	//change colours in backup stylesheet
	backupStylesheet = [backupStylesheet stringByReplacingOccurrencesOfString:@"NEBULA_DARK" withString:bgColorHex];
}

static void ColorChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	NSDictionary* colors;
	CFStringRef appID = CFSTR("com.octodev.nebulacolors");
    CFArrayRef keyList = CFPreferencesCopyKeyList(appID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    if (!keyList) {
        NSLog(@"There's been an error getting the key list!");
        return;
    }
    colors = (__bridge NSDictionary *)CFPreferencesCopyMultiple(keyList, appID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    if (!colors) {
        NSLog(@"There's been an error getting the preferences dictionary!");
    }
    CFRelease(keyList);
	bgColorHex = colors[@"backgroundColor"] ? [colors[@"backgroundColor"] substringWithRange:NSMakeRange(0, 7)] : @"#232323";
	changeColorsInStylesheets();
}

%ctor {
	//Load the stylesheets from files as soon as the tweak is injected and store them in static variables.
	loadStylesheetsFromFiles();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)ColorChangedCallback, CFSTR("com.octodev.nebula-colorchanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);

	NSDictionary* colors = [[NSDictionary alloc] initWithContentsOfFile:SETTINGS_PLIST_PATH];
	bgColorHex = colors[@"backgroundColor"] ? [colors[@"backgroundColor"] substringWithRange:NSMakeRange(0, 7)] : @"#232323";
	changeColorsInStylesheets();
}

//add button to toolbar
%hook BrowserToolbar
%property (nonatomic, assign) UIButton *darkButton;

-(void)setItems:(NSArray *)items animated:(BOOL)anim {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"Reset" object:nil]; //clear up before we add it again
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resetButton) name:@"Reset" object:nil];

	self.darkButton = [UIButton buttonWithType:UIButtonTypeCustom];
	[self.darkButton setFrame:CGRectMake(0, 0, 20, 20)];
	[self.darkButton addTarget:self action:@selector(nightMode:) forControlEvents:UIControlEventTouchUpInside];
	[self.darkButton setSelected:darkMode];

	//cheers pinpal
	[self.darkButton setImage:[UIImage changeImage:resizeImage([UIImage imageWithContentsOfFile:@"/Applications/MobileSafari.app/Dark.png"], CGSizeMake(20, 20)) toColor:self.tintColor] forState:UIControlStateNormal];
	[self.darkButton setImage:[UIImage changeImage:resizeImage([UIImage imageWithContentsOfFile:@"/Applications/MobileSafari.app/Light.png"], CGSizeMake(20, 20)) toColor:self.tintColor] forState:UIControlStateSelected];

	nightModeButton = [[UIBarButtonItem alloc] initWithCustomView:self.darkButton];

	NSMutableArray *buttons = [items mutableCopy];
	UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
	space.width = 30;
	[buttons addObject:space];
	[buttons addObject:nightModeButton];
	%orig([buttons copy], anim);
}

//called when the button is pressed
%new
-(void)nightMode:(UIButton *)button {
	AudioServicesPlaySystemSound(1519);
	button.selected = !button.selected;
	[[NSNotificationCenter defaultCenter] postNotificationName:@"DarkWebToggle" object:@(button.selected) userInfo:nil];
}

//resets the button to its default value
%new
-(void)resetButton {
	[self.darkButton setSelected:NO];
}

%end

@interface TabDocument : NSObject
@property (nonatomic, assign) BOOL shouldInject;
@property (nonatomic, copy) NSString *originalHead;
@property (nonatomic, copy) NSString *originalBody;
@property (nonatomic, copy) NSString *lastHost;
@property (nonatomic, copy) NSString *lastFullURL;
-(void)inject;
-(void)goDark;
-(void)reload;
-(void)runJavaScript:(NSString *)js completion:(id)comp;
-(NSString *)getJavaScriptOutput:(NSString *)js;
-(void)revertInjection;
@end

%hook TabDocument
%property (nonatomic, assign) BOOL shouldInject;
%property (nonatomic, copy) NSString *originalHead;
%property (nonatomic, copy) NSString *originalBody;
%property (nonatomic, copy) NSString *lastHost;
%property (nonatomic, copy) NSString *lastFullURL;

-(void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
	%orig;
	NSLog(@"Navigation ended.");

	//back up the original values
	self.originalHead = [self getJavaScriptOutput:@"document.getElementsByTagName(\"head\")[0].innerHTML"];
	self.originalBody = [self getJavaScriptOutput:@"document.getElementsByTagName(\"body\")[0].innerHTML"];

	BOOL whitelisted = NO;
	if(whitelist && [whitelist containsObject:[[((WKWebView *)[self valueForKey:@"webView"]) URL] host]] && !darkMode) {
		NSLog(@"Site is whitelisted.");
		self.shouldInject = YES;
		[self goDark];
		whitelisted = YES;
		self.shouldInject = NO;
	}

	if(darkMode) {
		[self goDark];
	} else if(!whitelisted) {
		self.shouldInject = NO;
		[self revertInjection];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"Reset" object:nil userInfo:nil];
	}


	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"DarkWebToggle" object:nil]; //clear up before we add it again
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(toggleInjection:) name:@"DarkWebToggle" object:nil];

	[self inject];
}

%new
-(void)toggleInjection:(NSNotification *)notification {
	[[NSNotificationCenter defaultCenter] postNotificationName:(self.shouldInject) ? @"DarkWebDark" : @"DarkWebLight" object:nil userInfo:nil];
	self.shouldInject = !self.shouldInject; //invert it, because we have now switched

	self.shouldInject = [[notification object] boolValue];
	darkMode = [[notification object] boolValue];

	[[notification object] boolValue] ? [self inject] : [self revertInjection];
}

-(void)reload {
	%orig;
	self.shouldInject = YES;
	[self inject];
}

%new
-(void)inject {
	[self goDark];
}

%new
-(void)goDark {
	if(self.shouldInject) {
		NSString *stylesheet = [NSString stringWithFormat:@"%@", stylesheetFromHex];

		NSString *host = [[((WKWebView *)[self valueForKey:@"webView"]) URL] host];
		if(![host containsString:@"www."]) {
			host = [@"www." stringByAppendingString:host];
		}
		NSLog(@"%@ css: %@", host, [customStyles valueForKey:host]);
		if([customStyles valueForKey:host]) {
			NSString *custom = [NSString stringWithContentsOfFile:[[stylesPath stringByAppendingString:@"/"] stringByAppendingString:[customStyles valueForKey:host]] encoding:NSUTF8StringEncoding error:nil];
			custom = [custom stringByReplacingOccurrencesOfString:@"NEBULA_DARK" withString:bgColorHex];
			stylesheet = custom;
		}
		else if ([backupStylesheetSites containsObject:host]) //see if host should use backup stylesheet
		{
			stylesheet = backupStylesheet;
		}

		NSString *head = [self getJavaScriptOutput:@"document.getElementsByTagName(\"head\")[0].innerHTML"];
		NSString *modifiedHead = [head stringByAppendingString:[NSString stringWithFormat:@"\n<style>%@</style>", stylesheet]];
		[self runJavaScript:[NSString stringWithFormat:@"document.getElementsByTagName(\"head\")[0].innerHTML = `%@`;", modifiedHead] completion:nil];
	}
}

%new
-(void)revertInjection {
	NSLog(@"Reverting changes");
	[self runJavaScript:[NSString stringWithFormat:@"document.getElementsByTagName(\"head\")[0].innerHTML = `%@`;", self.originalHead] completion:nil];
}

%new
-(void)runJavaScript:(NSString *)js completion:(void (^)())comp {
	__block BOOL finished = NO;

	[((WKWebView *)[self valueForKey:@"webView"]) evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
		if(error) NSLog(@"JSErr: %@", error.localizedDescription);
		finished = YES;
		[comp invoke];
	}];
	while (!finished) {
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
	}
}

%new
-(NSString *)getJavaScriptOutput:(NSString *)js {
	__block NSString *resultString = nil;
	__block BOOL finished = NO;

	[((WKWebView *)[self valueForKey:@"webView"]) evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
		if (error == nil) {
			if (result != nil) {
				resultString = [NSString stringWithFormat:@"%@", result];
			}
		} else {
			NSLog(@"JSErr: %@", error.localizedDescription);
		}
		finished = YES;
	}];
	while (!finished) {
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
	}
	return resultString;
}

%end

@interface BrowserController : NSObject
@property (nonatomic, copy) NSArray *whitelist;
@end

%hook BrowserController
%property (nonatomic, copy) NSArray *whitelist;

-(void)setWebView:(id)web {
	%orig;
	if(![[self valueForKeyPath:@"wkPreferences.javaScriptEnabled"] boolValue]) {
		static dispatch_once_t onceToken;
		dispatch_once(&onceToken, ^{
			NSLog(@"Javascript is disabled.");
			//warn the user
			void (^change)(void) = ^{
				NSString *plistPath = [[[NSUserDefaults standardUserDefaults] stringForKey:@"WebDatabaseDirectory"] stringByReplacingOccurrencesOfString:@"/WebKit/WebsiteData/WebSQL" withString:@"/Preferences/com.apple.mobilesafari.plist"];
				NSMutableDictionary *prefs = [[NSDictionary dictionaryWithContentsOfURL:[NSURL URLWithString:plistPath]] mutableCopy];
				[prefs setValue:@YES forKey:@"JavaScriptEnabled"];
				[[prefs copy] writeToURL:[NSURL URLWithString:plistPath] atomically:YES];
				[self setValue:@YES forKeyPath:@"wkPreferences.javaScriptEnabled"];
				//changing the NSUserDefaults value will change the plist anyway but idc
				[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"JavaScriptEnabled"];
			};
			UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"JavaScript Disabled"
															   message:@"Dark mode requires JavaScript to be enabled in order to work correctly."
                           									 preferredStyle:UIAlertControllerStyleAlert];

			UIAlertAction *ignore = [UIAlertAction actionWithTitle:@"Ignore" style:UIAlertActionStyleDestructive
																 handler:^(UIAlertAction * action) {}];

			UIAlertAction *enable = [UIAlertAction actionWithTitle:@"Enable" style:UIAlertActionStyleDefault
														 			handler:^(UIAlertAction * action) {
																		change();
																		[web performSelector:@selector(reload)];
																		}];

			[alert addAction:ignore];
			[alert addAction:enable];
			[[[[UIApplication sharedApplication] keyWindow] rootViewController] presentViewController:alert animated:YES completion:nil];
		});
	}
}

%end

//dark keyboard
%hook UIKBRenderConfig
- (void)setLightKeyboard:(BOOL)light {
	%orig(NO);
}
%end

%hook UIDevice
- (long long)_keyboardGraphicsQuality {
	return 10;
}
%end
