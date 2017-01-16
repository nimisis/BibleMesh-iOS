//
//  Book.m
//
//  Created by David Butler on 06/08/2013.
//  Copyright (c) 2013 David Butler. All rights reserved.
//

#import "Book.h"
#import "ASIHTTPRequest.h"
#import "AppDelegate.h"

@interface Book (Private)
- (void)loadThumb:(NSURL *)url;
- (void)loadCover:(NSURL *)url;
@end

@implementation Book

@synthesize title;
@synthesize author;
@synthesize img;
@synthesize book_id;
@synthesize thumbnail;
@synthesize cover;
@synthesize delegate;
@synthesize thumbTried;
@synthesize coverTried;

- (void) dealloc
{
    delegate = nil;
    //[thumbnail release];
    //[thumbnailURL release];
    //[img release];
	//[title release];
	//[author release];
	//[isbn release];
	//[isbn13 release];
	//[super dealloc];
}

#pragma mark -
#pragma mark Public methods

- (BOOL)hasLoadedThumbnail
{
    return (thumbnail != nil) || thumbTried;
}

- (BOOL)hasLoadedCover
{
    return (cover != nil) || coverTried;
}

#pragma mark -
#pragma mark Overridden setters

- (UIImage *)thumbnail
{
    if ((thumbnail == nil) && !thumbTried)
    {
        //NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://ecx.images-amazon.com/images/I/%@._SL75_.jpg", self.img]];//
        NSString *urlstr = [NSString stringWithFormat:@"http://biblemesh-readium.us-west-2.elasticbeanstalk.com/epub_content/book_%ld/%@/Images/cover.jpg", (long) self.book_id, self.img];
        //NSLog(@"urlstr %@", urlstr);
        NSURL *url = [NSURL URLWithString:urlstr];
        //book.thumbnailURL = [NSString stringWithFormat:@"http://ecx.images-amazon.com/images/I/%@._SL75_.jpg", currentImg];
        [self loadThumb:url];
        thumbTried = true;
    }
    return thumbnail;
}

- (UIImage *)cover
{
    if ((cover == nil) && !coverTried)
    {
        //https://biblemesh-readium.s3.amazonaws.com/epub_content/book_2/OEBPS/Images/cover.jpg
        //NSLog(@"loading %@", [NSString stringWithFormat:@"http://ecx.images-amazon.com/images/I/%@._SL160_.jpg", self.img]);
        //NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://ecx.images-amazon.com/images/I/%@._SL160_.jpg", self.img]];
        
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://biblemesh-readium.us-west-2.elasticbeanstalk.com/epub_content/book_%ld/%@/Images/cover.jpg", (long)self.book_id, self.img]];
        [self loadCover:url];
        coverTried = true;
    }
    return cover;
}

#pragma mark -
#pragma mark ASIHTTPRequest delegate methods

- (void)requestThumbDone:(ASIHTTPRequest *)request
{
    NSData *data = [request responseData];
    UIImage *remoteImage = [[UIImage alloc] initWithData:data];
    self.thumbnail = remoteImage;
    if ([delegate respondsToSelector:@selector(book:didLoadImage:)])
    {
        [delegate book:self didLoadImage:self.thumbnail];
    }
    //[remoteImage release];
}

- (void)requestThumbWentWrong:(ASIHTTPRequest *)request
{
    NSError *error = [request error];
    if ([delegate respondsToSelector:@selector(book:couldNotLoadImageError:)])
    {
        [delegate book:self couldNotLoadImageError:error];
    }
}

- (void)requestCoverDone:(ASIHTTPRequest *)request
{
    NSData *data = [request responseData];
    UIImage *remoteImage = [[UIImage alloc] initWithData:data];
    self.cover = remoteImage;
    if ([delegate respondsToSelector:@selector(book:didLoadImage:)])
    {
        [delegate book:self didLoadImage:self.cover];
    }
    //[remoteImage release];
}

- (void)requestCoverWentWrong:(ASIHTTPRequest *)request
{
    NSError *error = [request error];
    if ([delegate respondsToSelector:@selector(book:couldNotLoadImageError:)])
    {
        [delegate book:self couldNotLoadImageError:error];
    }
}

#pragma mark -
#pragma mark Private methods

- (void)loadThumb:(NSURL *)url
{
	AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    ASIHTTPRequest *request = [[ASIHTTPRequest alloc] initWithURL:url];
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(requestThumbDone:)];
    [request setDidFailSelector:@selector(requestThumbWentWrong:)];
    NSOperationQueue *queue = appDelegate.downloadQueue;
    [queue addOperation:request];
    //[request release];
}

- (void)loadCover:(NSURL *)url
{
	AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    ASIHTTPRequest *request = [[ASIHTTPRequest alloc] initWithURL:url];
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(requestCoverDone:)];
    [request setDidFailSelector:@selector(requestCoverWentWrong:)];
    NSOperationQueue *queue = appDelegate.downloadQueue;
    [queue addOperation:request];
    //[request release];
}
@end
