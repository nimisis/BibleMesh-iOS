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
    //NSCachedURLResponse *resp = [[NSURLCache sharedURLCache] cachedResponseForRequest:webView.request];
    //NSLog(@"%@",[(NSHTTPURLResponse*)resp.response allHeaderFields]);
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    //check that token is of expected format. Use regular expression?
    if ([jsonString hasPrefix:@"{\"error"]) {
        NSLog(@"error");//fix
    } else if ([jsonString hasPrefix:@"{\"userInfo"]) {
        NSLog(@"token is %@", jsonString);
        
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
                    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                    [defaults setInteger:[[dic valueForKey:@"id"] integerValue] forKey:@"userid"];
                    [defaults synchronize];
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
            [appDelegate getLibrary:true];
        }];
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    NSLog(@"did fail load");
    //fix could get stuck here if no internet
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
