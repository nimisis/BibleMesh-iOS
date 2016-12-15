//
//  Book_BookDelegate.h
//
//  Created by David Butler on 20/08/2013.
//  Copyright (c) 2013 David Butler. All rights reserved.
//

@class Book;

@protocol BookDelegate

@required
- (void)book:(Book *)book couldNotLoadImageError:(NSError *)error;

@optional
//- (void)book:(Book *)book didLoadImage:(UIImage *)image;
- (void)book:(Book *)book didLoadImage:(UIImage *)image;

@end
