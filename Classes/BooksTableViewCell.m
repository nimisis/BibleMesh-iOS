//
//  BooksTableViewCell.m
//  BibleMesh
//
//  Created by David Butler on 13/12/2016.
//  Copyright © 2016 The Readium Foundation. All rights reserved.
//

#import "BooksTableViewCell.h"
#import "AppDelegate.h"
#import "Book.h"

@implementation BooksTableViewCell

#define IMAGE_HEIGHT          75.0
#define IMAGE_WIDTH          55.0
#define EDITING_INSET       0.0
#define TEXT_LEFT_MARGIN    0.0

@synthesize book;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        //self.backgroundColor = [UIColor blackColor];
        
        didOwn = FALSE;
        didWish = FALSE;
        
        photo = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, 0.0, IMAGE_HEIGHT, IMAGE_HEIGHT)];
        [photo setContentMode:UIViewContentModeLeft];
        [photo setClipsToBounds:YES];
        //titleLabel.contentMode = UIViewContentModeRight;
        [self.contentView addSubview:photo];
        
        nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        [nameLabel setFont:[UIFont boldSystemFontOfSize:14.0]];
        [nameLabel setContentMode:UIViewContentModeScaleToFill];
        [nameLabel setHighlightedTextColor:[UIColor whiteColor]];
        //[nameLabel setLineBreakMode:UILineBreakModeWordWrap];
        [nameLabel setNumberOfLines:2];
        [self.contentView addSubview:nameLabel];
        
        authorLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        [authorLabel setFont:[UIFont systemFontOfSize:12.0]];
        [authorLabel setTextColor:[UIColor darkGrayColor]];
        [authorLabel setHighlightedTextColor:[UIColor whiteColor]];
        [authorLabel setNumberOfLines:2];
        [self.contentView addSubview:authorLabel];
        
        scrollingWheel = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(17.5, 27.5, 20.0, 20.0)];
        [scrollingWheel setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleGray];
        [scrollingWheel setHidesWhenStopped:YES];
        [scrollingWheel stopAnimating];
        [self.contentView addSubview:scrollingWheel];
        
        self.accessoryType = UITableViewCellAccessoryNone;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    //[photo setFrame:CGRectMake(0.0, 0.0, IMAGE_HEIGHT, IMAGE_HEIGHT)];
    
    [authorLabel setFrame:CGRectMake(IMAGE_WIDTH, 42.0, self.contentView.bounds.size.width - IMAGE_WIDTH - 132, 32.0)];
    [nameLabel setFrame:CGRectMake(IMAGE_WIDTH, 4.0, self.contentView.bounds.size.width - IMAGE_WIDTH, 32.0)];//CGRectMake(80.0, 5.0, 290.0, 70.0)];
    
    
}

- (void)setBook:(Book *)newBook therow:(NSInteger)therow
{
    BOOL needOwnUpdate = FALSE;
    BOOL needWishUpdate = FALSE;
    if (newBook == book) {
        if (didOwn != book.own) {
            needOwnUpdate = TRUE;
        }
        if (didWish != book.wish) {
            needWishUpdate = TRUE;
        }
    } else {
        if (book) {
            book.delegate = nil;
            //fix[book release];
        }
        book = nil;
        
        //book = [newBook retain];//fix
        book = newBook;//[newBook copy];
        [book setDelegate:self];
        
        if (book != nil) {
            nameLabel.text = book.title;
            authorLabel.text = book.author;
            
            // This is to avoid the item loading the image
            // when this setter is called; we only want that
            // to happen depending on the scrolling of the table
            if ([book hasLoadedThumbnail]) {
                photo.image = book.thumbnail;
            } else {
                [scrollingWheel startAnimating];
                photo.image = nil;
            }
            needOwnUpdate = TRUE;
            needWishUpdate = TRUE;
        }
    }
    
    
    if (needOwnUpdate) {
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        /*[ownBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        if (book.own) {
            didOwn = TRUE;
            [ownBtn addTarget:appDelegate action:@selector(disownIt:) forControlEvents:UIControlEventTouchDown];
            [ownBtn setTitle:@"Remove" forState:UIControlStateNormal];
            [ownBtn setBackgroundColor:[UIColor colorWithRed:273/255.0f green:83/255.0f blue:79/255.0f alpha:1.0]];
            [ownBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            ownBtn.tag = book.bookID;
        } else {
            didOwn = FALSE;
            [ownBtn setTitle:@"Own" forState:UIControlStateNormal];
            if (book.bookID == 0) {
                [ownBtn addTarget:appDelegate action:@selector(ownNew:) forControlEvents:UIControlEventTouchDown];
                ownBtn.tag = therow;
            } else {
                [ownBtn addTarget:appDelegate action:@selector(ownIt:) forControlEvents:UIControlEventTouchDown];
                ownBtn.tag = book.bookID;
            }
            [ownBtn setBackgroundColor:[UIColor colorWithRed:66/255.0f green:139/255.0f blue:202/255.0f alpha:1.0]];
            [ownBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        }*/
    }
    if (needWishUpdate) {
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        /*[wishBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        if (book.wish) {
            didWish = TRUE;
            [wishBtn addTarget:appDelegate action:@selector(unwishIt:) forControlEvents:UIControlEventTouchDown];
            [wishBtn setTitle:@"Un-wish" forState:UIControlStateNormal];
            [wishBtn setBackgroundColor:[UIColor colorWithRed:92/255.0f green:184/255.0f blue:92/255.0f alpha:1.0]];
            [wishBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            wishBtn.tag = book.bookID;
        } else {
            didWish = FALSE;
            [wishBtn setTitle:@"Wish" forState:UIControlStateNormal];
            if (book.bookID == 0) {
                [wishBtn addTarget:appDelegate action:@selector(wishNew:)
                  forControlEvents:UIControlEventTouchDown];
                wishBtn.tag = therow;//indexPath.row;
            } else {
                [wishBtn addTarget:appDelegate action:@selector(wishIt:) forControlEvents:UIControlEventTouchDown];
                wishBtn.tag = book.bookID;
            }
            [wishBtn setBackgroundColor:[UIColor whiteColor]];
            [wishBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        }*/
    }
}

- (void)loadImage
{
    // The getter in the FlickrItem class is overloaded...!
    // If the image is not yet downloaded, it returns nil and
    // begins the asynchronous downloading of the image.
    UIImage *image = book.thumbnail;
    /*if (image == nil)
     {
     [scrollingWheel startAnimating];
     }*/
    photo.image = image;
}

- (void)book:(Book *)book didLoadImage:(UIImage *)image
{
    //NSLog(@"didloadimage cell");
    photo.image = image;
    [scrollingWheel stopAnimating];
}

- (void)book:(Book *)book couldNotLoadImageError:(NSError *)error
{
    // Here we could show a "default" or "placeholder" image...
    [scrollingWheel stopAnimating];
}

- (void)dealloc {
    //[photo release];
    //[nameLabel release];
    [book setDelegate:nil];
    //[book release];
    //[super dealloc];
}

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
