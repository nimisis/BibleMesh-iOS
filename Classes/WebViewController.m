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

@interface WebViewController ()

@end

@implementation WebViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://nimisis.com/blogin.php"]];
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
    NSString *html = [webView stringByEvaluatingJavaScriptFromString:
                      @"document.body.innerHTML"];
    NSLog(@"html: %@", html);
    NSCachedURLResponse *resp = [[NSURLCache sharedURLCache] cachedResponseForRequest:webView.request];
    NSLog(@"%@",[(NSHTTPURLResponse*)resp.response allHeaderFields]);
    
    //check that token is of expected format. Use regular expression?
    if ([html hasPrefix:@"sometoken"]) {
        
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        
        [self dismissViewControllerAnimated:NO completion:^{
            
            NSLog(@"token is %@", html);
            
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
