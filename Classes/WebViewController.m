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
    
    NSInteger userid = 54;//fix
    
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
            
            /*NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"downloadDate" ascending:NO];
             NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
             [request setSortDescriptors:sortDescriptors];
             [sortDescriptors release];
             [sortDescriptor release];*/
            
            NSError *error = nil;
            NSMutableArray *mutableFetchResults = [[[appDelegate managedObjectContext] executeFetchRequest:request error:&error] mutableCopy];
            if (mutableFetchResults == nil) {
                // Handle the error.
            }
            
            //[self setEpubtitlesArray:mutableFetchResults];
            NSLog(@"Got %lu Epubtitles", (unsigned long)[mutableFetchResults count]);
            for(Epubtitle *title in mutableFetchResults) {
                if (title.userid == userid) {
                    [[appDelegate managedObjectContext] deleteObject:title];
                }
            }
            
            //[appDelegate ePubTitlesArray] = [[NSMutableArray alloc] init];
            
            for(NSDictionary *item in jsonArray) {
                NSLog(@"Item: %@", item);
                Epubtitle *ep = (Epubtitle *)[NSEntityDescription insertNewObjectForEntityForName:@"Epubtitle" inManagedObjectContext:[appDelegate managedObjectContext]];
                ep.userid = userid;
                [item enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop) {
                    if ([(NSString *) key  isEqual: @"id"]) {
                        ep.bookid = [obj integerValue];
                    } else if ([(NSString *) key  isEqual: @"author"]) {
                        ep.author = obj;
                    } else if ([(NSString *) key  isEqual: @"coverHref"]) {
                        ep.coverHref = obj;
                    } else if ([(NSString *) key  isEqual: @"rootUrl"]) {
                        ep.rootUrl = obj;
                    } else if ([(NSString *) key  isEqual: @"title"]) {
                        ep.title = obj;
                    }
                }];
                if ([[appDelegate managedObjectContext] save:&error]) {
                    NSLog(@"saved");
                    [[appDelegate ePubTitlesArray] addObject:ep];
                } else {
                    // Handle the error.
                    NSLog(@"Handle the error");
                }
            }
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
