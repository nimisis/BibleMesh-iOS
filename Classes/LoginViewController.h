//
//  LoginViewController.h
//  AuthTest
//
//  Created by David Butler on 21/12/2016.
//  Copyright © 2016 David Butler. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GAITrackedViewController.h"

@interface LoginViewController : GAITrackedViewController {
    BOOL firstload;
}

@property BOOL firstload;
@property (nonatomic, retain) IBOutlet UIButton *loginBtn;
- (IBAction)login:(id)sender;

@end
