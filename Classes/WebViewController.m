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
    
    //NSURLRequest *urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://nimisis.com/blogin.php"]];
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://read.biblemesh.com/epub_content/epub_library.json"]];

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
    //NSCachedURLResponse *resp = [[NSURLCache sharedURLCache] cachedResponseForRequest:webView.request];
    //NSLog(@"%@",[(NSHTTPURLResponse*)resp.response allHeaderFields]);
    
    NSInteger userid = 1;//fix
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    //check that token is of expected format. Use regular expression?
    if ([jsonString hasPrefix:@"[{"]) {
        NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
        NSError *error = nil;
        NSArray *jsonArray = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
        if (!jsonArray) {
            NSLog(@"Error parsing JSON: %@", error);
        } else {
            //fix!
            //delete current local store for this user?
            NSFetchRequest *request = [[NSFetchRequest alloc] init];
            NSEntityDescription *entity = [NSEntityDescription entityForName:@"Epubtitle" inManagedObjectContext:[appDelegate managedObjectContext]];
            //fix filter by user id;
            [request setEntity:entity];
            
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userid == %d", userid];
            //[request setEntity:[NSEntityDescription entityForName:@"DVD" inManagedObjectContext:moc]];
            [request setPredicate:predicate];
            NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"bookid" ascending:YES];
             NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
             [request setSortDescriptors:sortDescriptors];
            /* [sortDescriptors release];
             [sortDescriptor release];*/
            
            NSError *error = nil;
            NSMutableArray *mutableFetchResults = [[[appDelegate managedObjectContext] executeFetchRequest:request error:&error] mutableCopy];
            if (mutableFetchResults == nil) {
                // Handle the error.
            }
            
            //[self setEpubtitlesArray:mutableFetchResults];
            NSLog(@"Got %lu Epubtitles", (unsigned long)[mutableFetchResults count]);
            for(Epubtitle *title in mutableFetchResults) {
                NSLog(@"title %@ user %d book %d", title.title, title.userid, title.bookid);
                if (title.userid == userid) {
                    //[[appDelegate managedObjectContext] deleteObject:title];
                }
            }
            
            //[appDelegate ePubTitlesArray] = [[NSMutableArray alloc] init];
            
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
                Epubtitle *lep = nil;
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
                    Epubtitle *ep = (Epubtitle *)[NSEntityDescription insertNewObjectForEntityForName:@"Epubtitle" inManagedObjectContext:[appDelegate managedObjectContext]];
                    [ep setUserid:[[NSNumber numberWithInt:userid] intValue]];
                    [ep setBookid:[[NSNumber numberWithInt:bookid] intValue]];
                    [ep setAuthor:author];
                    [ep setTitle:title];
                    //[ep setLastUpdated:[updatedAt timeIntervalSince1970]];
                    [ep setCoverHref:coverHref];
                    [ep setRootUrl:rootUrl];
                    if ([[appDelegate managedObjectContext] save:&error]) {
                        NSLog(@"saved");
                        [mutableFetchResults insertObject:ep atIndex:localIndex];
                        localIndex++;
                    } else {
                        // Handle the error.
                        NSLog(@"Handle the error");
                    }
                }
            }
            
            Epubtitle *lep = nil;
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
            
            [appDelegate setEPubTitlesArray:mutableFetchResults];
            //while ((lep != nil) && ([lep bookid] < bookid)) {
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
            
            //fix todo. Make request to get titles
            
            
            //show library view
            ContainerListController *c = [[ContainerListController alloc] init];
            [appDelegate window].rootViewController = [[UINavigationController alloc] initWithRootViewController:c];
            
            /*UIAlertController * alert = [UIAlertController
                                         alertControllerWithTitle:@"Token"
                                         message:html
                                         preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction* okButton = [UIAlertAction
                                        actionWithTitle:@"OK"
                                        style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction * action) {
                                        }];
            
            [alert addAction:okButton];
            [[appDelegate lvc] presentViewController:alert animated:YES completion:nil];*/
        }];
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    NSLog(@"did fail load");
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
