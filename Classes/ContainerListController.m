//
//  ContainerListController.m
//  SDKLauncher-iOS
//
//  Created by Shane Meyer on 2/1/13.
//  Copyright (c) 2014 Readium Foundation and/or its licensees. All rights reserved.
//  
//  Redistribution and use in source and binary forms, with or without modification, 
//  are permitted provided that the following conditions are met:
//  1. Redistributions of source code must retain the above copyright notice, this 
//  list of conditions and the following disclaimer.
//  2. Redistributions in binary form must reproduce the above copyright notice, 
//  this list of conditions and the following disclaimer in the documentation and/or 
//  other materials provided with the distribution.
//  3. Neither the name of the organization nor the names of its contributors may be 
//  used to endorse or promote products derived from this software without specific 
//  prior written permission.
//  
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
//  IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
//  INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
//  BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
//  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE 
//  OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED 
//  OF THE POSSIBILITY OF SUCH DAMAGE.

#import "ContainerListController.h"
#import "ContainerList.h"
#import "BooksTableViewCell.h"
#import "Book.h"
#import "RDContainer.h"
#import "RDPackage.h"
#import "EPubViewController.h"
#import "GAI.h"
#import "GAIDictionaryBuilder.h"
#import "GAIFields.h"
#import "AppDelegate.h"
#import "BibleMesh-swift.h" //required for new CoreData codegen
#import "Download.h"
#import "RDSpineItem.h"
#import "NSString+FontAwesome.h"

@implementation ContainerListController

@synthesize m_table;

- (BOOL)container:(RDContainer *)container handleSdkError:(NSString *)message isSevereEpubError:(BOOL)isSevereEpubError {
    
    NSLog(@"READIUM SDK: %@\n", message);
    
    if (isSevereEpubError == YES) {
        //fix! [m_sdkErrorMessages addObject:message];
    }
    
    // never throws an exception
    return YES;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)init {
	if (self = [super initWithTitle:LocStr(@"CONTAINER_LIST_TITLE") navBarHidden:NO]) {
		
		/*[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(onContainerListDidChange)
			name:kSDKLauncherContainerListDidChange object:nil];*/
	}

	return self;
}

- (void)loadView {
    id<GAITracker> tracker = [[GAI sharedInstance] defaultTracker];
    [tracker set:kGAIScreenName value:@"Library"];
    [tracker send:[[GAIDictionaryBuilder createAppView]  build]];
    
	self.view = [[UIView alloc] init];
    
    thumbsArray = [[NSMutableArray alloc] init];

	UITableView *table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
	m_table = table;
	table.dataSource = self;
	table.delegate = self;
	[self.view addSubview:table];
    
    UIBarButtonItem *logoutButton = [[UIBarButtonItem alloc] initWithTitle:@"logout" style:UIBarButtonItemStylePlain target:self action:@selector(logout)];
    self.navigationItem.rightBarButtonItem = logoutButton;
    UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithTitle:@"refresh" style:UIBarButtonItemStylePlain target:self action:@selector(refresh)];
    self.navigationItem.leftBarButtonItem = refreshButton;
    
    UIFont *f1 = [UIFont fontWithName:kFontAwesomeFamilyName size:24];
    NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:f1, NSFontAttributeName, nil];
    [self.navigationItem.rightBarButtonItem setTitleTextAttributes:dict forState:UIControlStateNormal];
    self.navigationItem.rightBarButtonItem.title = [NSString fontAwesomeIconStringForEnum:FASignOut];
    
    [self.navigationItem.leftBarButtonItem setTitleTextAttributes:dict forState:UIControlStateNormal];
    self.navigationItem.leftBarButtonItem.title = [NSString fontAwesomeIconStringForEnum:FARefresh];
}

- (void) refresh {
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate getLibrary:NO];
}

- (void) logout {
    UIAlertController * alert = [UIAlertController
                                 alertControllerWithTitle:@"Log out"
                                 message:@"Are you sure you want to log out?"
                                 preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* yesButton = [UIAlertAction
                                 actionWithTitle:@"Yes"
                                 style:UIAlertActionStyleDefault
                                handler:^(UIAlertAction * action) {
                                    //fix start spinner?
                                    NSURL *url = [NSURL URLWithString:@"https://read.biblemesh.com/logout"];
                                    [AppDelegate downloadDataFromURL:url patch:nil withCompletionHandler:^(NSData *data) {
                                        NSLog(@"logout returned");
                                        
                                        NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
                                        for (NSHTTPCookie *cookie in [storage cookies])
                                        {
                                            [storage deleteCookie:cookie];
                                        }
                                        
                                        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                                        [[appDelegate lvc] setFirstload:YES];
                                        [appDelegate window].rootViewController = [appDelegate lvc];
                                    }];
                                }];
    
    [alert addAction:yesButton];
    UIAlertAction* cancelButton = [UIAlertAction
                                   actionWithTitle:@"Cancel"
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction * action) {
                                       NSLog(@"Cancel");
                                   }];
    
    [alert addAction:cancelButton];
    [self presentViewController:alert animated:YES completion:nil];
    
}


#pragma mark -
#pragma mark UIScrollViewDelegate Methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate{
    if (!decelerate)
    {
        [self loadContentForVisibleCells];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView;
{
    [self loadContentForVisibleCells];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [m_table reloadData];
    [self loadContentForVisibleCells];
}

- (void)loadContentForVisibleCells
{
    NSArray *visiblePaths = [m_table indexPathsForVisibleRows];
    for (NSIndexPath *indexPath in visiblePaths)
    {
        switch (indexPath.section) {
            case 0:
            {
                BooksTableViewCell *cell = (BooksTableViewCell *)[m_table cellForRowAtIndexPath:indexPath];
                [cell loadImage];
            }
                break;
            default:
                break;
        };
    }
}

/*- (void)onContainerListDidChange {
	m_paths = [ContainerList shared].paths;
	[m_table reloadData];
}*/

- (UITableViewCell *)
	tableView:(UITableView *)tableView
	cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"BookCell";
    BooksTableViewCell *cell = (BooksTableViewCell *)[tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil)
    {
        //CGRect rect = CGRectMake(0.0, 0.0, 320.0, 100.0);
        //cell = [[[ItemTableViewCell alloc] initWithFrame:rect reuseIdentifier:identifier] autorelease];
        cell = [[BooksTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }
    
    //fix
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    Location *ep = [[appDelegate locsArray] objectAtIndex:indexPath.row];
    Book *book = nil;
    for (Book *b in thumbsArray) {
        if ([b.title isEqualToString:[[ep locationToEpub] title]]) {
            book = b;
            break;
        }
    }
    if (book == nil) {
        book = [[Book alloc] init];
        book.title = [[ep locationToEpub] title];
        book.author = [[ep locationToEpub] author];
        //epub_content/book_[bookId]/cover_thumbnail_created_on_import.png
        //book.img = [NSString stringWithFormat:@"https://read.biblemesh.com/%@", [[ep locationToEpub] coverHref]];
        book.img = [NSString stringWithFormat:@"https://read.biblemesh.com/epub_content/book_%d/cover_thumbnail_created_on_import.png", [ep bookid]];
        [thumbsArray addObject:book];
    }
    
    //Book *book = [[Book alloc] init];
    {
        //switch ([[[appDelegate latestLocation] locationToEpub] downloadstatus]) {
        //NSLog(@"img: %@", book.img);
        switch ([[ep locationToEpub] downloadstatus]) {
            case 0://not downloaded
                book.status = @"Download";
                break;
            case 1://downloading
                book.status = @"Downloading...";
                break;
            case 2://downloaded
                book.status = @"";
                break;
        }
    }
    
    [cell setBook:book therow:indexPath.row];
    return cell;
}

- (bool) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    Location *ep = [[appDelegate locsArray] objectAtIndex:indexPath.row];
    if ([[ep locationToEpub] downloadstatus] == 2) {
        return YES;
    } else {
        return NO;
    }
}

- (void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"commit");
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    Location *ep = [[appDelegate locsArray] objectAtIndex:indexPath.row];
    //check if book exists in folder
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains
    (NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *homePath = [paths objectAtIndex:0];
    NSString *ePubFile = [homePath stringByAppendingPathComponent:[NSString stringWithFormat:@"book_%d.epub", [ep bookid]]];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:ePubFile]) {
        [[NSFileManager defaultManager] removeItemAtPath:ePubFile error:NULL];
    }

    //reset the download status to "not downloaded"
    //fix note that another user who has downloaded the file will then have to re-download.
    [[ep locationToEpub] setDownloadstatus:0];
    
    NSError *error = nil;
    if (![[appDelegate managedObjectContext] save:&error]) {
        // Handle the error.
        NSLog(@"Handle the error");
    }
    
    [tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                     withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)
	tableView:(UITableView *)tableView
	didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    {
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        //Location *ep = [[appDelegate locsArray] objectAtIndex:indexPath.row];
        
        [appDelegate setLatestLocation:[[appDelegate locsArray] objectAtIndex:indexPath.row]];
        
        //check if book exists in folder
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains
        (NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *homePath = [paths objectAtIndex:0];
        NSString *ePubFile = [homePath stringByAppendingPathComponent:[NSString stringWithFormat:@"book_%d.epub", [[appDelegate latestLocation] bookid]]];
        
        Boolean downloadit = false;
        switch ([[[appDelegate latestLocation] locationToEpub] downloadstatus]) {
            case 1:
                //downloading
            {
                UIAlertView *alert = [[UIAlertView alloc]
                                      initWithTitle:@"Please wait"
                                      message:@"Download in progress."
                                      delegate:nil
                                      cancelButtonTitle:@"OK"
                                      otherButtonTitles:nil];
                [alert show];
            }
                break;
            case 0://not downloaded, but could already exist because another user had downloaded it
            case 2:
                //downloaded
                //check exists, open if so. If not, download again
                if ([[NSFileManager defaultManager] fileExistsAtPath:ePubFile]) {
                    NSError *attributesError;
                    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:ePubFile error:&attributesError];
                    if ([fileAttributes fileSize] != [[[appDelegate latestLocation] locationToEpub] fsize]) {
                        NSLog(@"Unexpected filesize, delete and re-download");
                        NSError *error;
                        [[NSFileManager defaultManager] removeItemAtPath:ePubFile error:&error];
                        downloadit = true;
                    } else {
                        //open epub
                        [appDelegate refreshData:ePubFile];
                    }
                } else {
                    downloadit = true;
                }
                break;
        };
        
        if (downloadit) {
            NetworkStatus netStatus = [[appDelegate hostReachability] currentReachabilityStatus];
            if (netStatus == NotReachable) {
                UIAlertView *alert = [[UIAlertView alloc]
                                      initWithTitle:@"No internet"
                                      message:@"Please find an internet connection before downloading."
                                      delegate:nil
                                      cancelButtonTitle:@"OK"
                                      otherButtonTitles:nil];
                [alert show];
            } else {
                //download it
                NSLog(@"download epub");
                Download *dl = [[Download alloc] init];
                
                BooksTableViewCell *btv = (BooksTableViewCell *) [tableView cellForRowAtIndexPath:indexPath];
                btv.statusLabel.text = @"Downloading...";
                
                [dl setBookcell:btv];
                [dl setEPubFile:ePubFile];
                [dl setTitle:[[appDelegate latestLocation] locationToEpub]];
                
                [[[appDelegate latestLocation] locationToEpub] setDownloadstatus:1];//fix downloading
                NSError *error = nil;
                if (![[appDelegate managedObjectContext] save:&error]) {
                    // Handle the error.
                    NSLog(@"Handle the error");
                }
                
                UIApplication *app = [UIApplication sharedApplication];
                dl.bgTask = [app beginBackgroundTaskWithExpirationHandler:^{
                    [app endBackgroundTask:dl.bgTask];
                    dl.bgTask = UIBackgroundTaskInvalid;
                }];
                
                NSURLRequest *theRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://read.biblemesh.com/epub_content/book_%d/book.epub", [[appDelegate latestLocation] bookid]]]
                                                            cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                        timeoutInterval:60.0];
                dl.theConnection = [[NSURLConnection alloc] initWithRequest:theRequest delegate:dl];
                if (dl.theConnection) {
                    //fix
                } else {
                    // Inform the user that the connection failed.
                    NSLog(@"Connection failed.");
                }
            }
        }
    }
}

- (NSInteger)
	tableView:(UITableView *)tableView
	numberOfRowsInSection:(NSInteger)section
{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    return [[appDelegate locsArray] count];
}

- (void)viewDidLayoutSubviews {
	m_table.frame = self.view.bounds;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 75.0;
}

@end
