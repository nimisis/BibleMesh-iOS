//
//  WebViewController.h
//  AuthTest
//
//  Created by David Butler on 21/12/2016.
//  Copyright © 2016 David Butler. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface WebViewController : UIViewController <UIWebViewDelegate>

@property (nonatomic, retain) IBOutlet UIWebView *webView;

@end
