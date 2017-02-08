//
//  EPubViewController.m
//  SDKLauncher-iOS
//
//  Created by Shane Meyer on 6/5/13.
//  Copyright (c) 2014 Readium Foundation and/or its licensees. All rights reserved.
//  
//  Redistribution and use in source and binary forms, with or without modification, 
//  are permitted provided that the following conditions are met:
//  1. Redistributions of source code must retain the above copyright notice, this 
//  list of conditions and the following disclaimer.
//  2. Redistributions in binary form must reproduce the above copyright notice, 
//  this list of conditions and the following disclaimer in the documentation and/or 
//  other materials provided with the distribution.
//  3. Neither the name of the organization nor the names of its contributors may be 
//  used to endorse or promote products derived from this software without specific 
//  prior written permission.
//  
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
//  IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
//  INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
//  BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
//  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE 
//  OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED 
//  OF THE POSSIBILITY OF SUCH DAMAGE.

#import "EPubViewController.h"
#import "Bookmark.h"
#import "BookmarkDatabase.h"
#import "EPubSettings.h"
#import "EPubSettingsController.h"
#import "RDContainer.h"
#import "RDNavigationElement.h"
#import "RDPackage.h"
#import "RDPackageResourceServer.h"
#import "RDSpineItem.h"
#import <WebKit/WebKit.h>
#import "GAI.h"
#import "GAIDictionaryBuilder.h"
#import "GAIFields.h"
#import "AppDelegate.h"

@interface EPubViewController () <
	RDPackageResourceServerDelegate,
	UIAlertViewDelegate,
	UIPopoverControllerDelegate,
	UIWebViewDelegate,
    UIGestureRecognizerDelegate,
	WKScriptMessageHandler,
    UITextViewDelegate
>
{
	@private UIAlertView *m_alertAddBookmark;
	@private RDContainer *m_container;
	@private BOOL m_currentPageCanGoLeft;
	@private BOOL m_currentPageCanGoRight;
	@private BOOL m_currentPageIsFixedLayout;
	@private NSArray* m_currentPageOpenPagesArray;
	@private BOOL m_currentPageProgressionIsLTR;
	@private int m_currentPageSpineItemCount;
	@private NSString *m_initialCFI;
	@private BOOL m_moIsPlaying;
	@private RDNavigationElement *m_navElement;
	@private RDPackage *m_package;
	@private UIPopoverController *m_popover;
	@private RDPackageResourceServer *m_resourceServer;
	@private RDSpineItem *m_spineItem;
	@private __weak UIWebView *m_webViewUI;
	@private __weak WKWebView *m_webViewWK;
    @private NSTimer *hideTimer;
    @private UIProgressView *progress;
}

@end

@implementation EPubViewController

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	m_alertAddBookmark = nil;

	if (buttonIndex == 1) {
		UITextField *textField = [alertView textFieldAtIndex:0];

		NSString *title = [textField.text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];

		[self executeJavaScript:@"ReadiumSDK.reader.bookmarkCurrentPage()"
			completionHandler:^(id response, NSError *error)
		{
			NSString *s = response;

			if (error != nil || s == nil || ![s isKindOfClass:[NSString class]] || s.length == 0) {
				return;
			}

			NSData *data = [s dataUsingEncoding:NSUTF8StringEncoding];

			NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data
				options:0 error:&error];

			Bookmark *bookmark = [[Bookmark alloc]
				initWithCFI:[dict objectForKey:@"contentCFI"]
				containerPath:m_container.path
				idref:[dict objectForKey:@"idref"]
				title:title];

			if (bookmark == nil) {
				NSLog(@"The bookmark is nil!");
			}
			else {
				[[BookmarkDatabase shared] addBookmark:bookmark];
			}
		}];
	}
}

- (void)cleanUp {
    if (m_webViewWK != nil) {
        [m_webViewWK.configuration.userContentController removeScriptMessageHandlerForName:@"readium"];
    }
    
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	m_moIsPlaying = NO;

	if (m_alertAddBookmark != nil) {
		m_alertAddBookmark.delegate = nil;
		[m_alertAddBookmark dismissWithClickedButtonIndex:999 animated:NO];
		m_alertAddBookmark = nil;
	}

	if (m_popover != nil) {
		[m_popover dismissPopoverAnimated:NO];
		m_popover = nil;
    }
    if (hideTimer != nil) {
        [hideTimer invalidate];
        hideTimer = nil;
    }
}

- (BOOL)commonInit {

	// Load the special payloads. This is optional (the payloads can be nil), in which case
	// MathJax and annotations.css functionality will be disabled.

	NSBundle *bundle = [NSBundle mainBundle];
	NSString *path = [bundle pathForResource:@"annotations" ofType:@"css"];
	NSData *payloadAnnotations = (path == nil) ? nil : [[NSData alloc] initWithContentsOfFile:path];
	path = [bundle pathForResource:@"MathJax" ofType:@"js" inDirectory:@"mathjax"];
	NSData *payloadMathJax = (path == nil) ? nil : [[NSData alloc] initWithContentsOfFile:path];

	m_resourceServer = [[RDPackageResourceServer alloc]
		initWithDelegate:self
		package:m_package
		specialPayloadAnnotationsCSS:payloadAnnotations
		specialPayloadMathJaxJS:payloadMathJax];

	if (m_resourceServer == nil) {
		return NO;
	}

	// Configure the package's root URL. Rather than "localhost", "127.0.0.1" is specified in the
	// following URL to work around an issue introduced in iOS 7.0. When an iOS 7 device is offline
	// (Wi-Fi off, or airplane mode on), audio and video fails to be served by UIWebView / QuickTime,
	// even though being offline is irrelevant for an embedded HTTP server. Daniel suggested trying
	// 127.0.0.1 in case the underlying issue was host name resolution, and it works.

	m_package.rootURL = [NSString stringWithFormat:@"http://127.0.0.1:%d/", m_resourceServer.port];

    // Observe application background/foreground notifications
    // HTTP server becomes unreachable after the application has become inactive
    // so we need to stop and restart it whenever it happens
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAppWillResignActiveNotification:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAppWillEnterForegroundNotification:) name:UIApplicationWillEnterForegroundNotification object:nil];

    [self updateNavigationItems];
	return YES;
}

- (void)
	executeJavaScript:(NSString *)javaScript
	completionHandler:(void (^)(id response, NSError *error))completionHandler
{
	if (m_webViewUI != nil) {
		NSString *response = [m_webViewUI stringByEvaluatingJavaScriptFromString:javaScript];
		if (completionHandler != nil) {
			completionHandler(response, nil);
		}
	}
	else if (m_webViewWK != nil) {
		[m_webViewWK evaluateJavaScript:javaScript completionHandler:^(id response, NSError *error) {
			if (error != nil) {
				NSLog(@"%@", error);
			}
			if (completionHandler != nil) {
				if ([NSThread isMainThread]) {
					completionHandler(response, error);
				}
				else {
					dispatch_async(dispatch_get_main_queue(), ^{
						completionHandler(response, error);
					});
				}
			}
		}];
	}
	else if (completionHandler != nil) {
		completionHandler(nil, nil);
	}
}

- (void)handleMediaOverlayStatusDidChange:(NSString *)payload {
	NSData *data = [payload dataUsingEncoding:NSUTF8StringEncoding];
	NSError *error = nil;
	NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];

	if (error != nil || dict == nil || ![dict isKindOfClass:[NSDictionary class]]) {
		NSLog(@"The mediaOverlayStatusDidChange payload is invalid! (%@, %@)", error, dict);
	}
	else {
		NSNumber *n = dict[@"isPlaying"];

		if (n != nil && [n isKindOfClass:[NSNumber class]]) {
			m_moIsPlaying = n.boolValue;
			[self updateToolbar];
		}
	}
}


- (void)handlePageDidChange:(NSString *)payload {
	NSData *data = [payload dataUsingEncoding:NSUTF8StringEncoding];
	NSError *error = nil;
	NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];

	if (error != nil || dict == nil || ![dict isKindOfClass:[NSDictionary class]]) {
		NSLog(@"The pageDidChange payload is invalid! (%@, %@)", error, dict);
	}
	else {
		NSNumber *n = dict[@"canGoLeft_"];
		m_currentPageCanGoLeft = [n isKindOfClass:[NSNumber class]] && n.boolValue;

		n = dict[@"canGoRight_"];
		m_currentPageCanGoRight = [n isKindOfClass:[NSNumber class]] && n.boolValue;

		n = dict[@"isRightToLeft"];
		m_currentPageProgressionIsLTR = [n isKindOfClass:[NSNumber class]] && !n.boolValue;

		n = dict[@"isFixedLayout"];
		m_currentPageIsFixedLayout = [n isKindOfClass:[NSNumber class]] && n.boolValue;

		n = dict[@"spineItemCount"];
		m_currentPageSpineItemCount = [n isKindOfClass:[NSNumber class]] ? n.intValue : 0;

		NSArray *array = dict[@"openPages"];
		m_currentPageOpenPagesArray = [array isKindOfClass:[NSArray class]] ? array : nil;

		if (m_webViewUI != nil) {
			m_webViewUI.hidden = NO;
		}
		else if (m_webViewWK != nil) {
			m_webViewWK.hidden = NO;
		}

        [self updateToolbar];
        
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        //update local values, then update server
        
        NSNumber *unixtime = [NSNumber numberWithLongLong:(1000*[[NSDate date] timeIntervalSince1970]) + [appDelegate serverTimeOffset]];
        [self updateLocation:unixtime highlight:nil delete:NO];
        if ([array count] > 0) {
            NSLog(@"idref: %@", [(NSDictionary *)[array objectAtIndex:0] valueForKey:@"idref"]);
            [self updateHighlights:[(NSDictionary *)[array objectAtIndex:0] valueForKey:@"idref"]];
        } else {
            NSLog(@"idref: nil");
            [self updateHighlights:nil];
        }
	}
}

- (void)handleReaderDidInitialize {
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	dict[@"package"] = m_package.dictionary;
	dict[@"settings"] = [EPubSettings shared].dictionary;

	NSDictionary *pageDict = nil;

	if (m_spineItem == nil) {
	}
	else if (m_initialCFI != nil && m_initialCFI.length > 0) {
		pageDict = @{
			@"idref" : m_spineItem.idref,
			@"elementCfi" : m_initialCFI
		};
	}
	else if (m_navElement.content != nil && m_navElement.content.length > 0) {
		pageDict = @{
			@"contentRefUrl" : m_navElement.content,
			@"sourceFileHref" : (m_navElement.sourceHref == nil ?
				@"" : m_navElement.sourceHref)
		};
	}
	else {
		pageDict = @{
			@"idref" : m_spineItem.idref
		};
	}

	if (pageDict != nil) {
		dict[@"openPageRequest"] = pageDict;
	}

	NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];

	if (data != nil) {
		NSString *arg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		arg = [NSString stringWithFormat:@"ReadiumSDK.reader.openBook(%@)", arg];
		[self executeJavaScript:arg completionHandler:nil];
	}
}


- (instancetype)
	initWithContainer:(RDContainer *)container
	package:(RDPackage *)package
{
	return [self initWithContainer:container package:package spineItem:nil cfi:nil];
}


- (instancetype)
	initWithContainer:(RDContainer *)container
	package:(RDPackage *)package
	bookmark:(Bookmark *)bookmark
{
	RDSpineItem *spineItem = nil;

	for (RDSpineItem *currSpineItem in package.spineItems) {
		if ([currSpineItem.idref isEqualToString:bookmark.idref]) {
			spineItem = currSpineItem;
			break;
		}
	}

	return [self
		initWithContainer:container
		package:package
		spineItem:spineItem
		cfi:bookmark.cfi];
}


- (instancetype)
	initWithContainer:(RDContainer *)container
	package:(RDPackage *)package
	navElement:(RDNavigationElement *)navElement
{
	if (container == nil || package == nil) {
		return nil;
	}

	RDSpineItem *spineItem = nil;

	if (package.spineItems.count > 0) {
		spineItem = [package.spineItems objectAtIndex:0];
	}

	if (spineItem == nil) {
		return nil;
	}

	if (self = [super initWithTitle:package.title navBarHidden:NO]) {
		m_container = container;
		m_navElement = navElement;
		m_package = package;
		m_spineItem = spineItem;

		if (![self commonInit]) {
			return nil;
		}
	}

	return self;
}


- (instancetype)
	initWithContainer:(RDContainer *)container
	package:(RDPackage *)package
	spineItem:(RDSpineItem *)spineItem
	cfi:(NSString *)cfi
{
	if (container == nil || package == nil) {
		return nil;
	}

	if (spineItem == nil && package.spineItems.count > 0) {
		spineItem = [package.spineItems objectAtIndex:0];
	}

	if (spineItem == nil) {
		return nil;
	}

	if (self = [super initWithTitle:package.title navBarHidden:NO]) {
		m_container = container;
		m_initialCFI = cfi;
		m_package = package;
		m_spineItem = spineItem;

		if (![self commonInit]) {
			return nil;
		}
	}

	return self;
}

- (void)loadView {
    
    id<GAITracker> tracker = [[GAI sharedInstance] defaultTracker];
    [tracker set:kGAIScreenName value:@"EPubView"];
    [tracker send:[[GAIDictionaryBuilder createAppView]  build]];
    
	self.view = [[UIView alloc] init];
	self.view.backgroundColor = [UIColor whiteColor];

    hideTimer = nil;
    
	// Notifications

	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

	[nc addObserver:self selector:@selector(onEPubSettingsDidChange:)
		name:kSDKLauncherEPubSettingsDidChange object:nil];

    
	// Create the web view. The choice of web view type is based on the existence of the WKWebView
	// class, but this could be decided some other way.
    
    // The "no optimize" RequireJS option means that the entire "readium-shared-js" folder must be copied in to the OSX app bundle's "scripts" folder! (including "node_modules" subfolder, which is populated when invoking the "npm run prepare" build command) There is therefore some significant filesystem / size overhead, but the benefits are significant too: no need for the WebView to fetch sourcemaps, and to attempt to un-mangle the obfuscated Javascript during debugging.
    // However, the recommended development-time pattern is to invoke "npm run build" in order to refresh the "build-output" folder, with the RJS_UGLY environment variable set to "false" or "no". This way, the RequireJS single/multiple bundle(s) will be in readable uncompressed form.
    //NSString* readerFileName = @"reader_RequireJS-no-optimize.html";
    
    //NSString* readerFileName = @"reader_RequireJS-multiple-bundles.html";
    NSString* readerFileName = @"reader_RequireJS-single-bundle.html";


	if ([WKWebView class] != nil) {
		WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
		config.allowsInlineMediaPlayback = YES;
		config.mediaPlaybackRequiresUserAction = NO;

		// Configure a "readium" message handler, which is used by host_app_feedback.js.

		WKUserContentController *contentController = [[WKUserContentController alloc] init];
		[contentController addScriptMessageHandler:self name:@"readium"];
		config.userContentController = contentController;

		WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
		m_webViewWK = webView;
		webView.hidden = YES;
        webView.scrollView.bounces = NO;
        [self.view addSubview:webView];
        
        UIProgressView *prog = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];;
        [self.view addSubview:prog];
        progress = prog;

		// RDPackageResourceConnection looks at corePaths and corePrefixes in the following
		// query string to determine what core resources it should provide responses for. Since
		// WKWebView can't handle file URLs, the web server must provide these resources.

		NSString *url = [NSString stringWithFormat:
			@"%@%@?"
			@"corePaths=readium-shared-js_all.js,readium-shared-js_all.js.map,epubReadingSystem.js,host_app_feedback.js,sdk.css&"
			@"corePrefixes=readium-shared-js",
			m_package.rootURL,
			readerFileName];

		[webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
	}
	else {
		UIWebView *webView = [[UIWebView alloc] init];
		m_webViewUI = webView;
		webView.delegate = self;
		webView.hidden = YES;
		webView.scalesPageToFit = YES;
		webView.scrollView.bounces = NO;
		webView.allowsInlineMediaPlayback = YES;
		webView.mediaPlaybackRequiresUserAction = NO;
		[self.view addSubview:webView];

		NSURL *url = [[NSBundle mainBundle] URLForResource:readerFileName withExtension:nil];
		[webView loadRequest:[NSURLRequest requestWithURL:url]];
	}
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
    //[tap setDelegate:self];
    //[[m_webViewWK scrollView] addGestureRecognizer:tap];
    //[[m_webViewWK scrollView] addGestureRecognizer:tap];
    [[self view] addGestureRecognizer:tap];
    //[[m_webViewWK scrollView] addGestureRecognizer:tap];
    
    /*UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)];
    [pan setDelegate:self];
    [[m_webViewWK scrollView] addGestureRecognizer:pan];
    [[m_webViewWK scrollView] addGestureRecognizer:pan];
    
    UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(pressed:)];
    [press setDelegate:self];
    [press setNumberOfTapsRequired:0];
    [press setMinimumPressDuration:0];
    [[m_webViewWK scrollView] addGestureRecognizer:press];
    [[m_webViewWK scrollView] addGestureRecognizer:press];
    
    [tap requireGestureRecognizerToFail:press];*/
    
    UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self  action:@selector(swipeRightAction:)];
    [swipeRight setDirection:UISwipeGestureRecognizerDirectionRight];
    [m_webViewUI addGestureRecognizer:swipeRight];
    [m_webViewWK addGestureRecognizer:swipeRight];
    
    UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeLeftAction:)];
    [swipeLeft setDirection:UISwipeGestureRecognizerDirectionLeft];
    [m_webViewUI addGestureRecognizer:swipeLeft];
    [m_webViewWK addGestureRecognizer:swipeLeft];
}

//- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
  //  shouldRecognizeSimultaneouslyWithGestureRecognizer:(nonnull UIGestureRecognizer *)otherGestureRecognizer {
    
    /*if (gestureRecognizer.view == m_webViewWK.scrollView) {
        NSLog(@"a %ld", (long)gestureRecognizer.state);
    } else {
        NSLog(@"b");
    }
    if (otherGestureRecognizer.view == m_webViewWK.scrollView) {
        NSLog(@"c %ld", (long)otherGestureRecognizer.state);
    } else {
        NSLog(@"d");
    }*/
  //  return YES;
//}

//-(void)popupMenu:(NSString *)context {
  //  NSLog(@"popupmenu");
    /*NSMenu *theMenu = [[NSMenu alloc] initWithTitle:@"Context Menu"];
    [theMenu insertItemWithTitle:@"Beep" action:@selector(beep:) keyEquivalent:@"" atIndex:0];
    [theMenu insertItemWithTitle:@"Honk" action:@selector(honk:) keyEquivalent:@"" atIndex:1];
    [theMenu popUpMenuPositioningItem:theMenu.itemArray[0] atLocation:NSPointFromCGPoint(CGPointMake(0,0)) inView:self.view];*/
//}

-(void)tapped:(UITapGestureRecognizer *) tap {
    NSLog(@"tap");
    if (self.navigationController != nil) {
        [self.navigationController setNavigationBarHidden:NO animated:YES];
        [self.navigationController setToolbarHidden:NO animated:YES];
        if (hideTimer != nil) {
            [hideTimer invalidate];
        }
        hideTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(hideNavController) userInfo:nil repeats:NO];
    }
}

-(void)panned:(UIPanGestureRecognizer *) pan {
    NSLog(@"pan");
}

-(void)pressed:(UILongPressGestureRecognizer *) press {
    NSLog(@"press");
}

-(void)swipeLeftAction:(UISwipeGestureRecognizer *) swipe {
    [self executeJavaScript:@"ReadiumSDK.reader.openPageNext()" completionHandler:nil];
}

-(void)swipeRightAction:(UISwipeGestureRecognizer *) swipe {
    [self executeJavaScript:@"ReadiumSDK.reader.openPagePrev()" completionHandler:nil];
}

- (void)onClickAddBookmark {
    
    [self executeJavaScript:@"ReadiumSDK.reader.plugins.highlights.getCurrentSelectionCfi()" completionHandler:^(id response, NSError *error){
        NSDictionary *dict = response;
        //NSLog(@"get selection done %@", s);
        int r = arc4random() % 1000000 + 1;
        
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        Highlight *hl = (Highlight *)[NSEntityDescription insertNewObjectForEntityForName:@"Highlight" inManagedObjectContext:[appDelegate managedObjectContext]];
        [hl setCfi:[dict valueForKey:@"cfi"]];
        [hl setAnnotationID:r];
        [hl setIdref:[dict valueForKey:@"idref"]];
        NSNumber *unixtime = [NSNumber numberWithLongLong:(1000*[[NSDate date] timeIntervalSince1970]) + [appDelegate serverTimeOffset]];
        [hl setLastUpdated:[unixtime longLongValue]];
        [hl setColor:1];
        [hl setNote:@""];
        [hl setUserid:[appDelegate userid]];
        [hl setBookid:[[appDelegate latestLocation] bookid]];
        
        //NSError *error = nil;
        if ([[appDelegate managedObjectContext] save:&error]) {
            NSLog(@"saved");
            [[appDelegate highlightsArray] addObject:hl];
        } else {
            // Handle the error.
            NSLog(@"Handle the error");
        }
        
        NSString *js = [NSString stringWithFormat:@"ReadiumSDK.reader.plugins.highlights.addHighlight('%@', '%@', %d, 'highlight')",
                        [dict valueForKey:@"idref"], [dict valueForKey:@"cfi"], r];
        [self executeJavaScript:js completionHandler:^(id response, NSError *error)
         {
             if (response != nil) {
                 NSLog(@"got response");
             }
             if (error != nil) {
                 NSLog(@"%@", [error description]);
             }
             NSLog(@"completed addition of highlight");
         }];
        [self updateLocation:[NSNumber numberWithLong:[[appDelegate latestLocation] lastUpdated]] highlight:hl delete:NO];
    }];
    /*return;
    int r = arc4random() % 1000000;
    [self executeJavaScript:[NSString stringWithFormat:@"ReadiumSDK.reader.plugins.highlights.addSelectionHighlight(%d, 'highlight')", r] completionHandler:^(id response, NSError *error){
        NSString *s = response;
        NSLog(@"add selection done %@", s);*/
        
        /*AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        Highlight *hl = (Highlight *)[NSEntityDescription insertNewObjectForEntityForName:@"Highlight" inManagedObjectContext:[appDelegate managedObjectContext]];
        [hl setCfi:[temphl cfi]];
        [hl setIdref:[temphl idref]];
        [hl setLastUpdated:[temphl lastUpdated]];
        [hl setColor:[temphl color]];
        [hl setNote:[temphl note]];
        [hl setUserid:[self userid]];
        [hl setBookid:[[self latestLocation] bookid]];
        
        NSError *error = nil;
        if ([[self managedObjectContext] save:&error]) {
            NSLog(@"saved");
            [[self highlightsArray] addObject:hl];
        } else {
            // Handle the error.
            NSLog(@"Handle the error");
        }*/
    //}];
    /*[self executeJavaScript:@"ReadiumSDK.reader.plugins.highlights.on('annotationClicked', function(type, idref, cfi, id) {console.debug('ANNOTATION CLICK: ' + id);});" completionHandler:^(id response, NSError *error)
     {
         NSString *s = response;
         int i;
         i++;
     }];*/
    //getFirstVisibleCfi
    /*[self executeJavaScript:@"ReadiumSDK.reader.bookmarkCurrentPage()" completionHandler:^(id response, NSError *error)
     {
         NSString *s = response;
     }];*/
    /*[self executeJavaScript:@"ReadiumSDK.reader.getPaginationInfo().openPages" completionHandler:^(id response, NSError *error)
     {
     NSString *s = response;
     }];*/
    //[self executeJavaScript:@"ReadiumSDK.reader.plugins.highlights.addHighlight('xchapter_001', '/4/2/4,/8[c001s0004]/1:429,/14[c001s0007]/1:25', 123, 'highlight')" completionHandler:nil];
    /*[self executeJavaScript:@"ReadiumSDK.reader.plugins.highlights.on('annotationClicked', function(type, idref, cfi, id) {console.debug('ANNOTATION CLICK: ' + id);});" completionHandler:^(id response, NSError *error)
     {
     NSString *s = response;
     }];*/
    //cfi = "/4/2/4,/8[c001s0004]/1:429,/14[c001s0007]/1:25";
    //idref = "xchapter_001";
    
    /*[self executeJavaScript:@"ReadiumSDK.reader.plugins.highlights.getCurrentSelectionCfi()" completionHandler:^(id response, NSError *error)
    {
      NSDictionary *s = response;
        
    if (error != nil || s == nil || ![s isKindOfClass:[NSDictionary class]]) {
        return;
    }
     
    [self executeJavaScript:[NSString stringWithFormat:@"ReadiumSDK.reader.plugins.highlights.addHighlight('%@', '%@', 123, 'highlight')", [s objectForKey:@"idref"], [s objectForKey:@"cfi"]] completionHandler:nil];*/
    /*[self executeJavaScript:@"ReadiumSDK.reader.plugins.highlights.on('annotationClicked', function(type, idref, cfi, id) {console.debug('ANNOTATION CLICK: ' + id);});" completionHandler:^(id response, NSError *error)
         {
             int i;
             i++;
             NSString *t = response;
         }];*/
     /*NSData *data = [s dataUsingEncoding:NSUTF8StringEncoding];
     
     NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data
     options:0 error:&error];*/
     
     /*Bookmark *bookmark = [[Bookmark alloc]
     initWithCFI:[s objectForKey:@"contentCFI"]
     containerPath:m_container.path
     idref:[s objectForKey:@"idref"]
     title:@"title"];*/
     
     /*if (bookmark == nil) {
     NSLog(@"The bookmark is nil!");
     } else {
     [[BookmarkDatabase shared] addBookmark:bookmark];
     }*/
    //}];
    //[self executeJavaScript:@"ReadiumSDK.reader.plugins.highlights.addSelectionHighlight(Math.floor((Math.random()*1000000)), 'highlight')" completionHandler:nil];
    /*if (m_alertAddBookmark == nil) {
     m_alertAddBookmark = [[UIAlertView alloc]
     initWithTitle:LocStr(@"ADD_BOOKMARK_PROMPT_TITLE")
     message:nil
     delegate:self
     cancelButtonTitle:LocStr(@"GENERIC_CANCEL")
     otherButtonTitles:LocStr(@"GENERIC_OK"), nil];
     m_alertAddBookmark.alertViewStyle = UIAlertViewStylePlainTextInput;
     UITextField *textField = [m_alertAddBookmark textFieldAtIndex:0];
     textField.placeholder = LocStr(@"ADD_BOOKMARK_PROMPT_PLACEHOLDER");
     [m_alertAddBookmark show];
     }*/
}

- (void)onClickMONext {
	[self executeJavaScript:@"ReadiumSDK.reader.nextMediaOverlay()" completionHandler:nil];
}

- (void)onClickMOPause {
	[self executeJavaScript:@"ReadiumSDK.reader.toggleMediaOverlay()" completionHandler:nil];
}

- (void)onClickMOPlay {
	[self executeJavaScript:@"ReadiumSDK.reader.toggleMediaOverlay()" completionHandler:nil];
}

- (void)onClickMOPrev {
	[self executeJavaScript:@"ReadiumSDK.reader.previousMediaOverlay()" completionHandler:nil];
}

- (void)onClickNext {
	[self executeJavaScript:@"ReadiumSDK.reader.openPageNext()" completionHandler:nil];
}

- (void)onClickPrev {
	[self executeJavaScript:@"ReadiumSDK.reader.openPagePrev()" completionHandler:nil];
}

- (void)onClickSettings {
	EPubSettingsController *c = [[EPubSettingsController alloc] init];
	UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:c];

	if (IS_IPAD) {
		if (m_popover == nil) {
			m_popover = [[UIPopoverController alloc] initWithContentViewController:nav];
			m_popover.delegate = self;
			[m_popover presentPopoverFromBarButtonItem:self.navigationItem.rightBarButtonItem
				permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
		}
	}
	else {
		[self presentViewController:nav animated:YES completion:nil];
	}
}

- (void)onEPubSettingsDidChange:(NSNotification *)notification {
	[self passSettingsToJavaScript];
}

- (void)
	packageResourceServer:(RDPackageResourceServer *)packageResourceServer
	executeJavaScript:(NSString *)javaScript
{
	if ([NSThread isMainThread]) {
		[self executeJavaScript:javaScript completionHandler:nil];
	}
	else {
		dispatch_async(dispatch_get_main_queue(), ^{
			[self executeJavaScript:javaScript completionHandler:nil];
		});
	}
}

- (void)passSettingsToJavaScript {
	NSData *data = [NSJSONSerialization dataWithJSONObject:[EPubSettings shared].dictionary
		options:0 error:nil];

	if (data != nil) {
		NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

		if (s != nil && s.length > 0) {
			s = [NSString stringWithFormat:@"ReadiumSDK.reader.updateSettings(%@)", s];
			[self executeJavaScript:s completionHandler:nil];
		}
	}
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
	m_popover = nil;
}

- (void)updateNavigationItems {
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
		initWithBarButtonSystemItem:UIBarButtonSystemItemAction
		target:self
		action:@selector(onClickSettings)];
}

- (void)updateHighlights:(NSString *)idref {//fix could have more than one idref
    NSLog(@"update highlights");
    
    [self executeJavaScript:@"ReadiumSDK.reader.plugins.highlights.removeHighlightsByType('highlight')" completionHandler:^(id response, NSError *error)
     {
         if (response != nil) {
             NSLog(@"got response");
         }
         if (error != nil) {
             NSLog(@"%@", [error description]);
         }
         NSLog(@"completed removal of highlights");
         AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
         //int index = 1;
         NSLog(@"at spineIDRef %@", idref);
         for(Highlight *hl in [appDelegate highlightsArray]) {
             //NSLog(@"about to add id %d", index);
             //check that idref is [hl idref]
             if ([idref isEqualToString:[hl idref]]) {
                 int r = arc4random() % 1000000 + 1;
                 [hl setAnnotationID:r];
                 NSString *js = [NSString stringWithFormat:@"ReadiumSDK.reader.plugins.highlights.addHighlight('%@', '%@', %d, 'highlight')", [hl idref], [hl cfi], r];
                 [self executeJavaScript:js completionHandler:^(id response, NSError *error)
                  {
                      if (response != nil) {
                          NSLog(@"got response");
                      }
                      if (error != nil) {
                          NSLog(@"%@", [error description]);
                      }
                      NSLog(@"completed addition of highlight");
                  }];
                 NSError *error = nil;
                 if ([[appDelegate managedObjectContext] save:&error]) {
                     NSLog(@"saved annotation id");
                 } else {
                     // Handle the error.
                     NSLog(@"Handle the error");
                 }
             } else {
                 NSLog(@"skipped as idref not matched");
             }
         }
     }];
}

- (void)updateLocation:(NSNumber *)unixtime highlight:(Highlight *) hl delete:(Boolean)del{
    NSLog(@"update location");
    
    [self executeJavaScript:@"ReadiumSDK.reader.bookmarkCurrentPage()"
          completionHandler:^(id response, NSError *error)
     {
         NSString *s = response;
         
         if (error != nil || s == nil || ![s isKindOfClass:[NSString class]] || s.length == 0) {
             return;
         }
         
         NSData *data = [s dataUsingEncoding:NSUTF8StringEncoding];
         
         NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data
                                                              options:0 error:&error];
         
         if (del) {
         [self executeJavaScript:[NSString stringWithFormat:@"ReadiumSDK.reader.plugins.highlights.removeHighlight(%d)", hl.annotationID] completionHandler:^(id response2, NSError *error2)
          {
              NSString *s2 = response;
              NSLog(@"single highlight removed %@", s2);
          }];
         }
         
         AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
         //update local values, then update server
         
         //NSNumber *unixtime = [NSNumber numberWithLongLong:(1000*[[NSDate date] timeIntervalSince1970]) + [appDelegate serverTimeOffset]];
         NSLog(@"unix time is %lld", [unixtime longLongValue]);
         
         //update server
         NSMutableDictionary *postDict = [[NSMutableDictionary alloc] init];
         NSMutableDictionary *latest_location = [[NSMutableDictionary alloc] init];
         [latest_location setValue:[dict valueForKey:@"idref"] forKey:@"idref"];
         [latest_location setValue:[dict valueForKey:@"contentCFI"] forKey:@"elementCfi"];
         NSData * locData = [NSJSONSerialization  dataWithJSONObject:latest_location options:kNilOptions error:&error];
         NSString *locStr = [[NSString alloc] initWithData:locData encoding:NSUTF8StringEncoding];
         NSString *locStr2 = [locStr stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
         [postDict setValue:locStr2 forKey:@"latest_location"];
         [postDict setValue:unixtime forKey:@"updated_at"];
         NSMutableArray *highlights = [[NSMutableArray alloc] init];
         if (hl != nil) {
             NSMutableDictionary *hld = [[NSMutableDictionary alloc] init];
             [hld setValue:[hl idref] forKey:@"spineIdRef"];
             [hld setValue:[hl cfi] forKey:@"cfi"];
             [hld setValue:[NSNumber numberWithInt:hl.color] forKey:@"color"];
             [hld setValue:[hl note] forKey:@"note"];
             [hld setValue:[NSNumber numberWithLongLong:hl.lastUpdated] forKey:@"updated_at"];
             if (del) {
                 [hld setValue:@YES forKey:@"_delete"];
             }
             [highlights addObject:hld];
         }
         [postDict setValue:highlights forKey:@"highlights"];
         NSData *jsonData = [NSJSONSerialization dataWithJSONObject:postDict options:kNilOptions error:&error];
         if(!jsonData && error){
             NSLog(@"Error creating JSON: %@", [error localizedDescription]);
             return;
         }
         
         //NSJSONSerialization converts a URL string from http://... to http:\/\/... remove the extra escapes
         NSString *patch = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
         NSString *patch2 = [patch stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
         
         NSLog(@"patch2:%@", patch2);
         
         NSString *URLString = [NSString stringWithFormat:@"https://read.biblemesh.com/users/%ld/books/%d.json", (long)[appDelegate userid], [[appDelegate latestLocation] bookid]];
         NSURL *url = [NSURL URLWithString:URLString];
         
         [AppDelegate downloadDataFromURL:url patch:patch2 withCompletionHandler:^(NSData *data) {
             NSLog(@"returned");
         }];
         
         if (hl == nil) {
             NSString *dateString = [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                                   dateStyle:NSDateFormatterShortStyle
                                                                   timeStyle:NSDateFormatterFullStyle];
             NSLog(@"%@",dateString);
             
             [[appDelegate latestLocation] setLastUpdated:[unixtime longLongValue]];
             [[appDelegate latestLocation] setIdref:[dict valueForKey:@"idref"]];
             [[appDelegate latestLocation] setElementCfi:[dict valueForKey:@"contentCFI"]];
             
             NSError *error = nil;
             if ([[appDelegate managedObjectContext] save:&error]) {
                 NSLog(@"saved");
             } else {
                 // Handle the error.
                 NSLog(@"Handle the error");
             }
         } else if (del) {
             NSManagedObject *hlToDelete = hl;
             [[appDelegate managedObjectContext] deleteObject:hlToDelete];
             NSError *error = nil;
             if ([[appDelegate managedObjectContext] save:&error]) {
                 NSLog(@"deleted highlight");
                 [[appDelegate highlightsArray] removeObject:hl];
                 //[self ]
             } else {
                 // Handle the error.
                 NSLog(@"Handle the error");
             }
         }
     }];
}

- (void)updateToolbar {
	if ((m_webViewUI != nil && m_webViewUI.hidden) || (m_webViewWK != nil && m_webViewWK.hidden)) {
		self.toolbarItems = nil;
		return;
	}

	NSMutableArray *items = [NSMutableArray arrayWithCapacity:8];

	UIBarButtonItem *itemFixed = [[UIBarButtonItem alloc]
		initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
		target:nil
		action:nil];

	itemFixed.width = 12;

	/*static NSString *arrowL = @"\u2190";
	static NSString *arrowR = @"\u2192";

	UIBarButtonItem *itemNext = [[UIBarButtonItem alloc]
		initWithTitle:m_currentPageProgressionIsLTR ? arrowR : arrowL
		style:UIBarButtonItemStylePlain
		target:self
		action:@selector(onClickNext)];

	UIBarButtonItem *itemPrev = [[UIBarButtonItem alloc]
		initWithTitle:m_currentPageProgressionIsLTR ? arrowL : arrowR
		style:UIBarButtonItemStylePlain
		target:self
		action:@selector(onClickPrev)];

	if (m_currentPageProgressionIsLTR) {
		[items addObject:itemPrev];
		[items addObject:itemFixed];
		[items addObject:itemNext];
	}
	else {
		[items addObject:itemNext];
		[items addObject:itemFixed];
		[items addObject:itemPrev];
	}

	[items addObject:itemFixed];*/

	UILabel *label = [[UILabel alloc] init];
	label.backgroundColor = [UIColor clearColor];
	label.font = [UIFont systemFontOfSize:16];
	label.textColor = [UIColor blackColor];

    /*BOOL canGoNext = m_currentPageProgressionIsLTR ? m_currentPageCanGoRight : m_currentPageCanGoLeft;
    BOOL canGoPrevious = m_currentPageProgressionIsLTR ? m_currentPageCanGoLeft : m_currentPageCanGoRight;

    itemNext.enabled = canGoNext;
    itemPrev.enabled = canGoPrevious;*/

    int pindex = 0;
    int cindex = 0;
    int chapts = m_package.spineItems.count;
    int tpages = 0;
    
	if (m_currentPageOpenPagesArray == nil || [m_currentPageOpenPagesArray count] <= 0) {
		label.text = @"";
	}
	else {

        NSMutableArray *pageNumbers = [NSMutableArray array];

        for (NSDictionary *pageDict in m_currentPageOpenPagesArray) {

            NSNumber *spineItemIndex = [pageDict valueForKey:@"spineItemIndex"];
            NSNumber *spineItemPageIndex = [pageDict valueForKey:@"spineItemPageIndex"];

            int pageIndex = m_currentPageIsFixedLayout ? spineItemIndex.intValue : spineItemPageIndex.intValue;

            pindex = pageIndex+1;
            cindex = [spineItemIndex intValue];
            
            [pageNumbers addObject: [NSNumber numberWithInt:pageIndex + 1]];
        }

        NSString* currentPages = [NSString stringWithFormat:@"%@", [pageNumbers componentsJoinedByString:@"-"]];

        int pageCount = 0;
        if ([m_currentPageOpenPagesArray count] > 0)
        {
            NSDictionary *firstOpenPageDict = [m_currentPageOpenPagesArray objectAtIndex:0];
            NSNumber *number = [firstOpenPageDict valueForKey:@"spineItemPageCount"];

            pageCount = m_currentPageIsFixedLayout ? m_currentPageSpineItemCount: number.intValue;
            tpages = chapts * pageCount;
            pindex += cindex * pageCount;
        }
        NSString* totalPages = [NSString stringWithFormat:@"%d", pageCount];

        label.text = LocStr(@"PAGE_X_OF_Y", [currentPages UTF8String], [totalPages UTF8String], m_currentPageIsFixedLayout?[@"FXL" UTF8String]:[@"reflow" UTF8String]);
	}

	[label sizeToFit];

	[items addObject:[[UIBarButtonItem alloc] initWithCustomView:label]];

	[items addObject:[[UIBarButtonItem alloc]
		initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
		target:nil
		action:nil]
	];
    
    if (tpages > 0) {
        float prog = ((float)pindex / (float)tpages);
        if (prog > 1.0f) {
            NSLog(@"prog too big");
            prog = 1.0f;
        }
        [progress setProgress:prog];
    }
    
	[self executeJavaScript:@"ReadiumSDK.reader.isMediaOverlayAvailable()"
		completionHandler:^(id response, NSError *error)
	{
		if (error == nil && response != nil && (
			([response isKindOfClass:[NSNumber class]] && ((NSNumber *)response).boolValue)
				||
			([response isKindOfClass:[NSString class]] && [((NSString *)response) isEqualToString:@"true"])
		))
		{
			[items addObject:[[UIBarButtonItem alloc]
				initWithTitle:@"<"
				style:UIBarButtonItemStylePlain
				target:self
				action:@selector(onClickMOPrev)]
			];

			if (m_moIsPlaying) {
				[items addObject:[[UIBarButtonItem alloc]
					initWithBarButtonSystemItem:UIBarButtonSystemItemPause
					target:self
					action:@selector(onClickMOPause)]
				];
			}
			else {
				[items addObject:[[UIBarButtonItem alloc]
					initWithBarButtonSystemItem:UIBarButtonSystemItemPlay
					target:self
					action:@selector(onClickMOPlay)]
				];
			}

			[items addObject:[[UIBarButtonItem alloc]
				initWithTitle:@">"
				style:UIBarButtonItemStylePlain
				target:self
				action:@selector(onClickMONext)]
			];

			[items addObject:itemFixed];
		}

		[items addObject:[[UIBarButtonItem alloc]
			initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
			target:self
			action:@selector(onClickAddBookmark)]
		];

		self.toolbarItems = items;
	}];
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    if ([textView.text isEqualToString:@"Notes"]) {
        textView.text = @"";
        textView.textColor = [UIColor blackColor]; //optional
    }
    [textView becomeFirstResponder];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    if ([textView.text isEqualToString:@""]) {
        textView.text = @"Notes";
        textView.textColor = [UIColor lightGrayColor]; //optional
    }
    [textView resignFirstResponder];
}

- (void)
	userContentController:(WKUserContentController *)userContentController
	didReceiveScriptMessage:(WKScriptMessage *)message
{
	if (![NSThread isMainThread]) {
		NSLog(@"A script message unexpectedly arrived on a non-main thread!");
	}

	NSArray *body = message.body;

	if (message.name == nil ||
		![message.name isEqualToString:@"readium"] ||
		body == nil ||
		![body isKindOfClass:[NSArray class]] ||
		body.count == 0 ||
		![body[0] isKindOfClass:[NSString class]])
	{
		NSLog(@"Invalid script message! (%@, %@)", message.name, message.body);
		return;
	}

	NSString *messageName = body[0];

	if ([messageName isEqualToString:@"mediaOverlayStatusDidChange"]) {
		if (body.count < 2 || ![body[1] isKindOfClass:[NSString class]]) {
			NSLog(@"The mediaOverlayStatusDidChange payload is invalid!");
		}
		else {
			[self handleMediaOverlayStatusDidChange:body[1]];
		}
	}
	else if ([messageName isEqualToString:@"pageDidChange"]) {
		if (body.count < 2 || ![body[1] isKindOfClass:[NSString class]]) {
			NSLog(@"The pageDidChange payload is invalid!");
		}
		else {
			[self handlePageDidChange:body[1]];
		}
    }
    else if ([messageName isEqualToString:@"readerDidInitialize"]) {
        [self handleReaderDidInitialize];
    }
    else if ([messageName isEqualToString:@"annotationClicked"]) {
        if (body.count < 2 || ![body[1] isKindOfClass:[NSString class]]) {
            NSLog(@"The annotationClick payload is invalid!");
        }
        else {
            NSLog(@"annotation %@ clicked!", body[1]);
            
            UIAlertController * alert = [UIAlertController
                                         alertControllerWithTitle:@" "
                                         message:@" "//[NSString stringWithFormat:@"annotation clicked %@", body[1]]
                                         preferredStyle:UIAlertControllerStyleAlert];
            
            UITextView *tv = [[UITextView alloc] initWithFrame:CGRectNull];
            
            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            tv.text = @"Notes";
            tv.textColor = [UIColor lightGrayColor];
            Highlight *thl = nil;
            for (Highlight *hl in [appDelegate highlightsArray]) {
                NSLog(@"matching %d with %@", [hl annotationID], body[1]);
                if ([[NSString stringWithFormat:@"\"%d\"", [hl annotationID]] isEqualToString:body[1]]) {
                    NSLog(@"matched!");
                    thl = hl;
                    tv.text = [hl note];
                    tv.textColor = [UIColor blackColor];
                    break;
                } else {
                    NSLog(@"no match");
                }
            }
            tv.delegate = self;
            tv.layer.cornerRadius = 8;
            tv.layer.borderColor = [[UIColor grayColor] CGColor];
            tv.layer.borderWidth = 1.0f;
            
            [[alert view] addSubview:tv];
            
            /*[alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                textField.placeholder = @"Notes";
                textField.text = @"Hello";
                textField.num
                //textField.textColor = [UIColor blueColor];
                textField.clearButtonMode = UITextFieldViewModeWhileEditing;
                textField.borderStyle = UITextBorderStyleNone;
                //textField.secureTextEntry = YES;
            }];*/
            
            /*NSLayoutConstraint *constraint = [NSLayoutConstraint constraintWithItem:alert.view attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationLessThanOrEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:self.view.frame.size.height*1.8f];
            [alert.view addConstraint:constraint];*/
            
            UIAlertAction* saveButton = [UIAlertAction
                                       actionWithTitle:@"Save"
                                       style:UIAlertActionStyleDefault
                                       handler:^(UIAlertAction * action) {
                                           NSLog(@"Saved");
                                           [thl setNote:tv.text];
                                           NSNumber *unixtime = [NSNumber numberWithLongLong:(1000*[[NSDate date] timeIntervalSince1970]) + [appDelegate serverTimeOffset]];
                                           [thl setLastUpdated:[unixtime longLongValue]];
                                           NSError *error = nil;
                                           if ([[appDelegate managedObjectContext] save:&error]) {
                                               NSLog(@"saved highlight");
                                           } else {
                                               // Handle the error.
                                               NSLog(@"Handle the error");
                                           }
                                           [self updateLocation:[NSNumber numberWithLong:[[appDelegate latestLocation] lastUpdated]] highlight:thl delete:NO];
                                       }];
            
            [alert addAction:saveButton];
            UIAlertAction* deleteButton = [UIAlertAction
                                       actionWithTitle:@"Delete"
                                       style:UIAlertActionStyleDestructive
                                       handler:^(UIAlertAction * action) {
                                           NSLog(@"Deleted");
                                           
                                           [self updateLocation:[NSNumber numberWithLong:[[appDelegate latestLocation] lastUpdated]] highlight:thl delete:YES];
                                       }];
            
            [alert addAction:deleteButton];
            UIAlertAction* shareButton = [UIAlertAction
                                          actionWithTitle:@"Share"
                                          style:UIAlertActionStyleDefault
                                          handler:^(UIAlertAction * action) {
                                              NSLog(@"Shared");//fix todo
                                          }];
            
            [alert addAction:shareButton];
            UIAlertAction* cancelButton = [UIAlertAction
                                          actionWithTitle:@"Cancel"
                                          style:UIAlertActionStyleCancel
                                          handler:^(UIAlertAction * action) {
                                              NSLog(@"Cancel");
                                          }];
            
            [alert addAction:cancelButton];
            [self presentViewController:alert animated:YES completion:^{
                NSInteger margin = 5;
                tv.frame = CGRectMake(margin, margin, alert.view.frame.size.width-2*margin, alert.view.frame.size.height-4*46-margin);
            }];
        }
    } else if ([messageName isEqualToString:@"context"]) {
        NSLog(@"context");
        //[self popupMenu:message.body];
    } else if ([messageName isEqualToString:@"settingsDidApply"]) {
    } else {
        NSLog(@"messageName %@", messageName);
    }
    
}

- (void)viewDidLayoutSubviews {
	CGSize size = self.view.bounds.size;
    
    //NSLog(@"size h1 %.0f, h2 %.0f", size.height, self.view.frame.size.height);
	if (m_webViewUI != nil) {
		m_webViewUI.frame = self.view.bounds;
	}
	else if (m_webViewWK != nil) {
		self.automaticallyAdjustsScrollViewInsets = NO;
		CGFloat y0 = self.topLayoutGuide.length;
        if (y0 != 64.0f) {
            y0 = 64.0f;
        }
        //NSLog(@"y %0.f %0.f", size.height, self.bottomLayoutGuide.length);
        CGFloat y1 = size.height - self.bottomLayoutGuide.length;//seems to be required to prevent scrollview from being dragged upwards
        if (y1 == size.height) {
            y1 -= 44.0f;
        }
        m_webViewWK.frame = CGRectMake(0, y0, size.width, y1 - y0);
        //m_webViewWK.frame = CGRectMake(0, 64, size.width, 568 - 64.0f - 44.0f);//fix ipad the same?
        m_webViewWK.scrollView.contentInset = UIEdgeInsetsZero;
		m_webViewWK.scrollView.scrollIndicatorInsets = UIEdgeInsetsZero;
        
        progress.frame = CGRectMake(10, size.height - 10, size.width-20, 10);
    }
}

- (void)hideNavController {
    if (self.navigationController != nil) {
        [self.navigationController setNavigationBarHidden:YES animated:YES];
        [self.navigationController setToolbarHidden:YES animated:YES];
    }
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
    
    if (self.navigationController != nil) {
        [self.navigationController setNavigationBarHidden:NO animated:YES];
        [self.navigationController setToolbarHidden:NO animated:YES];
        if (hideTimer != nil) {
            [hideTimer invalidate];
        }
        hideTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(hideNavController) userInfo:nil repeats:NO];
    }
}


- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];

	/*if (self.navigationController != nil) {
		[self.navigationController setToolbarHidden:YES animated:YES];
	}*/
}


- (BOOL)
	webView:(UIWebView *)webView
	shouldStartLoadWithRequest:(NSURLRequest *)request
	navigationType:(UIWebViewNavigationType)navigationType
{
	BOOL shouldLoad = YES;
	NSString *url = request.URL.absoluteString;
	NSString *s = @"epubobjc:";
    
    // When opening the web inspector from Safari (on desktop OSX), the Javascript sourcemaps are requested and fetched automatically based on the location of their source file counterpart. In other words, no need for intercepting requests below (or via NSURLProtocol), unlike the OSX ReadiumSDK launcher app which requires building custom URL responses containing the sourcemap payload. This needs testing with WKWebView though (right now this works fine with UIWebView because local resources are fetched from the file:// app bundle.
    if ([url hasSuffix:@".map"]) {
        NSLog(@"%@", [NSString stringWithFormat:@"WEBVIEW-REQUESTED SOURCEMAP: %@", url]);
    }
    
	if ([url hasPrefix:s]) {
		url = [url substringFromIndex:s.length];
		shouldLoad = NO;

		s = @"mediaOverlayStatusDidChange?q=";

		if ([url hasPrefix:s]) {
			s = [url substringFromIndex:s.length];
			s = [s stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
			[self handleMediaOverlayStatusDidChange:s];
		}
		else {
			s = @"pageDidChange?q=";

			if ([url hasPrefix:s]) {
				s = [url substringFromIndex:s.length];
				s = [s stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
				[self handlePageDidChange:s];
			}
			else if ([url isEqualToString:@"readerDidInitialize"]) {
				[self handleReaderDidInitialize];
			}
		}
	}

	return shouldLoad;
}

- (void)handleAppWillResignActiveNotification:(NSNotification *)notification {
    [m_resourceServer stopHTTPServer];
}

- (void)handleAppWillEnterForegroundNotification:(NSNotification *)notification {
    [m_resourceServer startHTTPServer];
}


@end
