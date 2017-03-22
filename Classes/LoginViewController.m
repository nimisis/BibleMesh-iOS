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
@synthesize loginBtn;

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
                
                NSFetchRequest *request2 = [[NSFetchRequest alloc] init];
                NSEntityDescription *entity2 = [NSEntityDescription entityForName:@"Location" inManagedObjectContext:[appDelegate managedObjectContext]];
                [request2 setEntity:entity2];
                
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userid == %d", [appDelegate userid]];
                [request2 setPredicate:predicate];
                
                NSError *error2 = nil;
                NSMutableArray *mutableFetchResults2 = [[[appDelegate managedObjectContext] executeFetchRequest:request2 error:&error2] mutableCopy];
                if (mutableFetchResults2 == nil) {
                    // Handle the error.
                }
                
                //latestLocation = [[Location alloc] init];
                if ([mutableFetchResults2 count] > 0) {
                    //[self setLatestLocation:[mutableFetchResults2 objectAtIndex:0]];
                    [appDelegate setLocsArray:mutableFetchResults2];
                    //NSLog(@"userid %d", [[self latestLocation] userid]);
                }
                NSLog(@"Got %lu locations", (unsigned long)[mutableFetchResults2 count]);
                
                for (int i = 0; i < (unsigned long)[mutableFetchResults2 count]; i++) {
                    Location *loc = [mutableFetchResults2 objectAtIndex:i];
                    if ([[loc locationToEpub] downloadstatus] == 1) {
                        NSLog(@"found a title that is mid-download");
                        [[loc locationToEpub] setDownloadstatus:0];
                        NSError *error = nil;
                        if (![[appDelegate managedObjectContext] save:&error]) {
                            // Handle the error.
                        }
                    }
                    //NSLog(@"downloadstatus %d", ept.downloadstatus);
                }
                
                //get servertime
                [appDelegate getServerTime];
                
                //show library view
                [appDelegate window].rootViewController = [[UINavigationController alloc] initWithRootViewController:[appDelegate clc]];
            } else {
                NetworkStatus netStatus = [[appDelegate hostReachability] currentReachabilityStatus];
                if (netStatus == NotReachable) {
                    //show login button
                    [loginBtn setHidden:FALSE];
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
                    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:wvc];
                    [self presentViewController:nav animated:YES completion:nil];
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
                    
                    NSFetchRequest *request2 = [[NSFetchRequest alloc] init];
                    NSEntityDescription *entity2 = [NSEntityDescription entityForName:@"Location" inManagedObjectContext:[appDelegate managedObjectContext]];
                    [request2 setEntity:entity2];
                    
                    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userid == %d", [appDelegate userid]];
                    [request2 setPredicate:predicate];
                    
                    NSError *error2 = nil;
                    NSMutableArray *mutableFetchResults2 = [[[appDelegate managedObjectContext] executeFetchRequest:request2 error:&error2] mutableCopy];
                    if (mutableFetchResults2 == nil) {
                        // Handle the error.
                    }
                    
                    //latestLocation = [[Location alloc] init];
                    if ([mutableFetchResults2 count] > 0) {
                        //[self setLatestLocation:[mutableFetchResults2 objectAtIndex:0]];
                        [appDelegate setLocsArray:mutableFetchResults2];
                        //NSLog(@"userid %d", [[self latestLocation] userid]);
                    }
                    NSLog(@"Got %lu locations", (unsigned long)[mutableFetchResults2 count]);
                    
                    for (int i = 0; i < (unsigned long)[mutableFetchResults2 count]; i++) {
                        Location *loc = [mutableFetchResults2 objectAtIndex:i];
                        if ([[loc locationToEpub] downloadstatus] == 1) {
                            NSLog(@"found a title that is mid-download");
                            [[loc locationToEpub] setDownloadstatus:0];
                            NSError *error = nil;
                            if (![[appDelegate managedObjectContext] save:&error]) {
                                // Handle the error.
                            }
                        }
                        //NSLog(@"downloadstatus %d", ept.downloadstatus);
                    }
                    
                    //get servertime
                    [appDelegate getServerTime];
                    
                    //show library view
                    [appDelegate window].rootViewController = [[UINavigationController alloc] initWithRootViewController:[appDelegate clc]];
                } else {
                    //show login button
                    [loginBtn setHidden:FALSE];
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
                UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:wvc];
                [self presentViewController:nav animated:YES completion:nil];
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
        [loginBtn setHidden:TRUE];
        WebViewController *wvc = [[WebViewController alloc] initWithNibName:@"WebViewController" bundle:nil];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:wvc];
        [self presentViewController:nav animated:YES completion:nil];
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
