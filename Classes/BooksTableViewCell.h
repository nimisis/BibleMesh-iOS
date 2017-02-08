//
//  BooksTableViewCell.h
//  BibleMesh
//
//  Created by David Butler on 13/12/2016.
//  Copyright © 2016 The Readium Foundation. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BookDelegate.h"

@class Book; 

@interface BooksTableViewCell : UITableViewCell <BookDelegate>{
    UIImageView *photo;
    UILabel *nameLabel;
    UILabel *authorLabel;
    UILabel *statusLabel;
    Book *book;
    UIActivityIndicatorView *scrollingWheel;
}

@property (nonatomic, retain) Book *book;
@property (nonatomic, retain) UILabel *statusLabel;

- (void)setBook:(Book *)newBook therow:(NSInteger)therow;
- (void)loadImage;

@end
