//
//  Book.h
//
//  Created by David Butler on 06/08/2013.
//  Copyright (c) 2013 David Butler. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BookDelegate.h"

@interface Book : NSObject {
    @private
    NSString *title;
    NSString *author;
    NSString *img;
    NSString *status;
    
    NSInteger book_id;
    
    UIImage *thumbnail;
    UIImage *cover;
    BOOL thumbTried;
    BOOL coverTried;
	
    // Why NSObject instead of "id"? Because this way
    // we can ask if it "respondsToSelector:" before invoking
    // any delegate method...
    //NSObject<BookDelegate> *delegate;
}

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *author;
@property (nonatomic, copy) NSString *img;
@property (nonatomic, copy) NSString *status;
@property NSInteger book_id;
@property (nonatomic, retain) UIImage *thumbnail;
@property (nonatomic, retain) UIImage *cover;
@property (nonatomic, assign) NSObject<BookDelegate> *delegate;

- (BOOL)hasLoadedThumbnail;
- (BOOL)hasLoadedCover;

@property BOOL thumbTried;
@property BOOL coverTried;

@property NSInteger bookID;
@property NSInteger own;
@property NSInteger wish;

@end
