//
//  WebViewController.m
//  AuthTest
//
//  Created by David Butler on 21/12/2016.
//  Copyright © 2016 David Butler. All rights reserved.
//

#import "WebViewController.h"
#import "AppDelegate.h"
#import "ContainerListController.h"
#import "Biblemesh-swift.h"

@interface WebViewController ()

@end

@implementation WebViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSMutableURLRequest* urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://read.biblemesh.com/usersetup.json"]];
    [urlRequest setValue:@"true" forHTTPHeaderField:@"App-Request"];
    
    [_webView loadRequest:urlRequest];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    NSLog(@"should start load with request to %@", [[request URL] absoluteString]);
    if (navigationType == UIWebViewNavigationTypeFormSubmitted) {
        NSLog(@"form submitted");
    }
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    NSLog(@"did start load");
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    NSLog(@"did finish load");
    //NSString *html = [webView stringByEvaluatingJavaScriptFromString:
    //                  @"document.body.innerHTML"];
    //NSLog(@"html: %@", html);
    NSString *jsonString = [webView stringByEvaluatingJavaScriptFromString:@"document.getElementsByTagName(\"pre\")[0].innerHTML"];
    NSLog(@"json: %@", jsonString);
    //header info
    NSCachedURLResponse *resp = [[NSURLCache sharedURLCache] cachedResponseForRequest:webView.request];
    NSLog(@"%@",[(NSHTTPURLResponse*)resp.response allHeaderFields]);
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    //check that token is of expected format. Use regular expression?
    if ([jsonString hasPrefix:@"{\"userInfo"]) {
        
        NSData *userdata = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
        
        __block NSInteger serverTime;
        //check local data against data returned
        if (userdata == nil) {
            NSLog(@"no data");
            //return;
        } else {
            NSError *error = nil;
            id jsonObject = [NSJSONSerialization JSONObjectWithData:userdata options:NSJSONReadingMutableContainers error:&error];
            if (error) {
                NSLog(@"Error parsing JSON: %@", error);
                return;
            }
            if ([jsonObject isKindOfClass:[NSArray class]]) {
                NSLog(@"is array");
                return;
            }
            
            NSNumber *unixtime = [NSNumber numberWithLongLong:(1000*[[NSDate date] timeIntervalSince1970])];
            NSLog(@"unix time is %lld", [unixtime longLongValue]);
            [jsonObject enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                if ([(NSString *) key isEqualToString:@"currentServerTime"]) {
                    serverTime = [(NSNumber *) obj longLongValue];
                    NSLog(@"servertime %ld diff:%lld", serverTime, (serverTime - [unixtime longLongValue]));
                    [appDelegate setServerTimeOffset:(serverTime - [unixtime longLongValue])];
                } else if ([(NSString *) key isEqualToString:@"userInfo"]) {
                    NSDictionary *dic = (NSDictionary *)obj;
                    NSLog(@"userID is %ld", [[dic valueForKey:@"id"] integerValue]);
                    [appDelegate setUserid: [[dic valueForKey:@"id"] integerValue]];
                } else if ([(NSString *) key isEqualToString:@"gaCode"]) {//fix todo
                } else if ([(NSString *) key isEqualToString:@"error"]) {//fix todo
                } else {
                    NSLog(@"other usersetup value");
                }
            }];
        }
        
        /*if (error)
            NSLog(@"JSONObjectWithData error: %@", error);
        
        for (NSMutableDictionary *dictionary in array)
        {
            NSString *arrayString = dictionary[@"array"];
            if (arrayString)
            {
                NSData *data = [arrayString dataUsingEncoding:NSUTF8StringEncoding];
                NSError *error = nil;
                dictionary[@"array"] = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                if (error)
                    NSLog(@"JSONObjectWithData for array error: %@", error);
            }
        }*/
        
        [self dismissViewControllerAnimated:NO completion:^{
            
            NSLog(@"token is %@", jsonString);
            
            //get servertime
            NSString *URLString = @"https://read.biblemesh.com/epub_content/epub_library.json";
            NSURL *url = [NSURL URLWithString:URLString];
            [AppDelegate downloadDataFromURL:url patch:nil withCompletionHandler:^(NSData *data) {
                
                NSLog(@"returned");
                
                NSError *error = nil;
                NSArray *jsonArray = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
                if (!jsonArray) {
                    NSLog(@"Error parsing JSON: %@", error);
                } else {
                    //fix!
                    //delete current local store for this user?
                    NSFetchRequest *request = [[NSFetchRequest alloc] init];
                    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Location" inManagedObjectContext:[appDelegate managedObjectContext]];
                    [request setEntity:entity];
                    
                    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userid == %d", [appDelegate userid]];
                    [request setPredicate:predicate];
                    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"bookid" ascending:YES];
                    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
                    [request setSortDescriptors:sortDescriptors];
                    
                    NSError *error = nil;
                    NSMutableArray *mutableFetchResults = [[[appDelegate managedObjectContext] executeFetchRequest:request error:&error] mutableCopy];
                    if (mutableFetchResults == nil) {
                        // Handle the error.
                    }
                    
                    //[self setEpubtitlesArray:mutableFetchResults];
                    NSLog(@"Got %lu Locations", (unsigned long)[mutableFetchResults count]);
                    /*for(Location *title in mutableFetchResults) {
                     if (title.locationToEpub == nil) {
                     NSLog(@"nil loc to Epub");
                     } else {
                     NSLog(@"bookid %d", title.locationToEpub.bookid);
                     }
                     }*/
                    
                    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
                    int localIndex = 0;
                    for(NSDictionary *item in jsonArray) {
                        NSLog(@"Item: %@", item);
                        
                        __block NSInteger bookid;
                        __block NSDate *updatedAt;
                        __block NSString *author;
                        __block NSString *coverHref;
                        __block NSString *rootUrl;
                        __block NSString *title;
                        [item enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop) {
                            if ([(NSString *) key  isEqual: @"id"]) {
                                bookid = [obj integerValue];
                            } else if ([(NSString *) key  isEqual: @"author"]) {
                                author = obj;
                            } else if ([(NSString *) key  isEqual: @"coverHref"]) {
                                coverHref = obj;
                            } else if ([(NSString *) key  isEqual: @"rootUrl"]) {
                                rootUrl = obj;
                            } else if ([(NSString *) key  isEqual: @"title"]) {
                                title = obj;
                            } else if ([(NSString *) key  isEqual: @"updated_at"]) {
                                updatedAt = [dateFormatter dateFromString:obj];
                            }
                        }];
                        Location *lep = nil;
                        if (localIndex < [mutableFetchResults count]) {
                            lep = [mutableFetchResults objectAtIndex:localIndex];
                        }
                        while ((lep != nil) && ([lep bookid] < bookid)) {
                            //delete all epub titles until we get a match
                            [[appDelegate managedObjectContext] deleteObject:lep];
                            //fix delete all associated highlights too.
                            if ([[appDelegate managedObjectContext] save:&error]) {
                                NSLog(@"saved");
                            } else {
                                // Handle the error.
                                NSLog(@"Handle the error");
                            }
                            [mutableFetchResults removeObjectAtIndex:localIndex];
                            if (localIndex < [mutableFetchResults count]) {
                                lep = nil;
                            } else {
                                lep = [mutableFetchResults objectAtIndex:localIndex];
                            }
                        }
                        Boolean insertnew = false;
                        if (lep != nil) {
                            if ([lep bookid] == bookid) {
                                //test for dates
                                //if server is newer, update with new server values
                                /*NSLog(@"comparing %ld %lld", (long) [updatedAt timeIntervalSince1970], [lep lastUpdated]);
                                 if ([updatedAt timeIntervalSince1970] > [lep lastUpdated]) {
                                 [lep setAuthor:author];
                                 [lep setTitle:title];
                                 [lep setLastUpdated:[updatedAt timeIntervalSince1970]];
                                 [lep setCoverHref:coverHref];
                                 [lep setRootUrl:rootUrl];
                                 if ([[appDelegate managedObjectContext] save:&error]) {
                                 NSLog(@"saved");
                                 } else {
                                 // Handle the error.
                                 NSLog(@"Handle the error");
                                 }
                                 } else {
                                 //do nothing as local version is up-to-date
                                 }*/
                                localIndex++;
                            } else {
                                //new book
                                insertnew = true;
                            }
                        } else {
                            insertnew = true;
                        }
                        if (insertnew) {
                            //insert new location
                            Location *lo = (Location *)[NSEntityDescription insertNewObjectForEntityForName:@"Location" inManagedObjectContext:[appDelegate managedObjectContext]];
                            [lo setBookid:[[NSNumber numberWithInt:bookid] intValue]];
                            [lo setUserid:[[NSNumber numberWithInt:[appDelegate userid]] intValue]];
                            //search through epubs for this book id;
                            lo.locationToEpub = nil;
                            for (Epubtitle* ep in [appDelegate booksArray]) {
                                if ([ep bookid] == bookid) {
                                    lo.locationToEpub = ep;
                                    break;
                                }
                            }
                            if (lo.locationToEpub == nil) {
                                Epubtitle *ep = (Epubtitle *)[NSEntityDescription insertNewObjectForEntityForName:@"Epubtitle" inManagedObjectContext:[appDelegate managedObjectContext]];
                                //[ep setUserid:[[NSNumber numberWithInt:userid] intValue]];
                                [ep setBookid:[[NSNumber numberWithInt:bookid] intValue]];
                                [ep setAuthor:author];
                                [ep setTitle:title];
                                //[ep setLastUpdated:[updatedAt timeIntervalSince1970]];
                                [ep setCoverHref:coverHref];
                                [ep setRootUrl:rootUrl];
                                lo.locationToEpub = ep;
                            }
                            if ([[appDelegate managedObjectContext] save:&error]) {
                                NSLog(@"saved");
                                [mutableFetchResults insertObject:lo atIndex:localIndex];
                                localIndex++;
                            } else {
                                // Handle the error.
                                NSLog(@"Handle the error");
                            }
                        }
                    }
                    
                    Location *lep = nil;
                    while (localIndex < [mutableFetchResults count]) {
                        lep = [mutableFetchResults objectAtIndex:localIndex];
                        //delete all epub titles until we get a match
                        [[appDelegate managedObjectContext] deleteObject:lep];
                        //fix delete all associated highlights too.
                        if ([[appDelegate managedObjectContext] save:&error]) {
                            NSLog(@"saved");
                        } else {
                            // Handle the error.
                            NSLog(@"Handle the error");
                        }
                        [mutableFetchResults removeObjectAtIndex:localIndex];
                    }
                    
                    [appDelegate setLocsArray:mutableFetchResults];
                    
                    //while ((lep != nil) && ([lep bookid] < bookid)) {
                }
                
                
                
                //show library view
                ContainerListController *c = [[ContainerListController alloc] init];
                [appDelegate window].rootViewController = [[UINavigationController alloc] initWithRootViewController:c];
            }];
            
        }];
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    NSLog(@"did fail load");
    //show library view? No!
    /*AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    ContainerListController *c = [[ContainerListController alloc] init];
    [appDelegate window].rootViewController = [[UINavigationController alloc] initWithRootViewController:c];*/
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
