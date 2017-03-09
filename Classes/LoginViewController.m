//
//  LoginViewController.m
//  AuthTest
//
//  Created by David Butler on 21/12/2016.
//  Copyright © 2016 David Butler. All rights reserved.
//

#import "LoginViewController.h"
#import "WebViewController.h"
#import "AppDelegate.h"

@interface LoginViewController ()

@end

@implementation LoginViewController

@synthesize firstload;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Login";
    self.screenName = @"Login";
    firstload = TRUE;
}

- (void) viewDidAppear:(BOOL)animated {
    //check internet connection
    
    /*NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [storage cookies])
    {
        NSLog(@"cookie name:%@ domain:%@ expires:%@", [cookie name], [cookie domain], [cookie expiresDate]);
        //[storage deleteCookie:cookie];
    }*/
    
    if (firstload) {
        firstload = FALSE;
        
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        
        if (true) {
            NSLog(@"method 2: test cookie first");
            BOOL livesession = FALSE;
            NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
            for (NSHTTPCookie *cookie in [storage cookies])
            {
                NSLog(@"cookie name:%@ domain:%@ expires:%@", [cookie name], [cookie domain], [cookie expiresDate]);
                //[storage deleteCookie:cookie];
                if ([[cookie domain] isEqualToString:@"read.biblemesh.com"] &&
                    [[cookie name] isEqualToString:@"connect.sid"] &&
                    ([[NSDate date] compare:[cookie expiresDate]] == NSOrderedAscending)
                    ) {
                    livesession = TRUE;
                    NSLog(@"have live session");
                    break;
                }
            }
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            NSInteger userid = [defaults integerForKey:@"userid"];
            if (livesession && (userid > 0)) {
                [appDelegate setUserid:userid];
                //show library view
                ContainerListController *c = [[ContainerListController alloc] init];
                [appDelegate window].rootViewController = [[UINavigationController alloc] initWithRootViewController:c];
            } else {
                NetworkStatus netStatus = [[appDelegate hostReachability] currentReachabilityStatus];
                if (netStatus == NotReachable) {
                    //show login button
                    [_loginBtn setHidden:FALSE];
                    UIAlertView *alert = [[UIAlertView alloc]
                                          initWithTitle:@"No connectivity"
                                          message:@"Please connect to the internet to authenticate your device."
                                          delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
                    [alert show];
                } else {
                    NSLog(@"presenting webview for log in");
                    WebViewController *wvc = [[WebViewController alloc] initWithNibName:@"WebViewController" bundle:nil];
                    [self presentViewController:wvc animated:YES completion:nil];
                }
            }
        } else {
            NSLog(@"method 1: test connection first");
            NetworkStatus netStatus = [[appDelegate hostReachability] currentReachabilityStatus];
            if (netStatus == NotReachable) {
                NSLog(@"No internet, checking cookies");
                //check cookies
                BOOL livesession = FALSE;
                NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
                for (NSHTTPCookie *cookie in [storage cookies])
                {
                    NSLog(@"cookie name:%@ domain:%@ expires:%@", [cookie name], [cookie domain], [cookie expiresDate]);
                    //[storage deleteCookie:cookie];
                    if ([[cookie domain] isEqualToString:@"read.biblemesh.com"] &&
                        [[cookie name] isEqualToString:@"connect.sid"] &&
                        ([[NSDate date] compare:[cookie expiresDate]] == NSOrderedAscending)
                        ) {
                        livesession = TRUE;
                        NSLog(@"have live session");
                        break;
                    }
                }
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                NSInteger userid = [defaults integerForKey:@"userid"];
                if (livesession && (userid > 0)) {
                    [appDelegate setUserid:userid];
                    //show library view
                    ContainerListController *c = [[ContainerListController alloc] init];
                    [appDelegate window].rootViewController = [[UINavigationController alloc] initWithRootViewController:c];
                } else {
                    //show login button
                    [_loginBtn setHidden:FALSE];
                    UIAlertView *alert = [[UIAlertView alloc]
                                          initWithTitle:@"No connectivity"
                                          message:@"Please connect to the internet to authenticate your device."
                                          delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
                    [alert show];
                }
            } else {
                NSLog(@"presenting webview for log in");
                WebViewController *wvc = [[WebViewController alloc] initWithNibName:@"WebViewController" bundle:nil];
                [self presentViewController:wvc animated:YES completion:nil];
            }
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (IBAction)login:(id)sender {
    NSLog(@"login");
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NetworkStatus netStatus = [[appDelegate hostReachability] currentReachabilityStatus];
    if (netStatus == NotReachable) {
        UIAlertView *alert = [[UIAlertView alloc]
                              initWithTitle:@"No connectivity"
                              message:@"Please connect to the internet to authenticate your device."
                              delegate:nil
                              cancelButtonTitle:@"OK"
                              otherButtonTitles:nil];
        [alert show];
    } else {
        [_loginBtn setHidden:TRUE];
        WebViewController *wvc = [[WebViewController alloc] initWithNibName:@"WebViewController" bundle:nil];
        [self presentViewController:wvc animated:YES completion:nil];
    }
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
