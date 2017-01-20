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

@implementation ContainerListController

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

	UITableView *table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
	m_table = table;
	table.dataSource = self;
	table.delegate = self;
	[self.view addSubview:table];
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
    
    Book *book = [[Book alloc] init];
    {
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        Epubtitle *ep = [[appDelegate ePubTitlesArray] objectAtIndex:indexPath.row];
        book.title = ep.title;
        book.author = ep.author;
        book.img = [NSString stringWithFormat:@"https://read.biblemesh.com/%@", [ep coverHref]];
        //NSLog(@"img: %@", book.img);
    }
    
    [cell setBook:book therow:indexPath.row];
    return cell;
}

- (bool) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    Epubtitle *ep = [[appDelegate ePubTitlesArray] objectAtIndex:indexPath.row];
    if ([ep downloadstatus] == 2) {
        return YES;
    } else {
        return NO;
    }
}

- (void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"commit");
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    Epubtitle *ep = [[appDelegate ePubTitlesArray] objectAtIndex:indexPath.row];
    //check if book exists in folder
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains
    (NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *homePath = [paths objectAtIndex:0];
    NSString *ePubFile = [homePath stringByAppendingPathComponent:[NSString stringWithFormat:@"book_%d.epub", ep.bookid]];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:ePubFile]) {
        [[NSFileManager defaultManager] removeItemAtPath:ePubFile error:NULL];
    }

    //reset the download status to "not downloaded"
    //fix note that another user who has downloaded the file will then have to re-download.
    [ep setDownloadstatus:0];
    
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
        Epubtitle *ep = [[appDelegate ePubTitlesArray] objectAtIndex:indexPath.row];
        //check if book exists in folder
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains
        (NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *homePath = [paths objectAtIndex:0];
        NSString *ePubFile = [homePath stringByAppendingPathComponent:[NSString stringWithFormat:@"book_%d.epub", ep.bookid]];
        
        Boolean downloadit = false;
        switch (ep.downloadstatus) {
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
                    //open epub
                    
                    /*NetworkStatus netStatus = [[appDelegate hostReachability] currentReachabilityStatus];
                    if (netStatus == NotReachable) {
                        NSLog(@"no internet");
                    } else*/
                    {
                        NSString *URLString = [NSString stringWithFormat:@"https://read.biblemesh.com/users/1/books/%d.json", ep.bookid];
                        NSURL *url = [NSURL URLWithString:URLString];
                        [AppDelegate downloadDataFromURL:url post:nil withCompletionHandler:^(NSData *data) {
                            __block NSInteger last_updated;
                            __block NSString *idref;
                            __block NSString *elementCfi;
                        //check local data against data returned
                        if (data != nil) {
                            NSError *error = nil;
                            id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
                            if (error) {
                                NSLog(@"Error parsing JSON: %@", error);
                            } else {
                                if ([jsonObject isKindOfClass:[NSArray class]]) {
                                    NSLog(@"is array");
                                } else {
                                    [jsonObject enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                                        NSLog(@"key: %@", key);
                                        if ([(NSString *) key isEqualToString:@"highlights"]) {
                                            //fix todo
                                        } else if ([(NSString *) key isEqualToString:@"latest_location"]) {
                                            
                                            NSData *data2 = [(NSString *) obj dataUsingEncoding:NSUTF8StringEncoding];
                                            NSError *error = nil;
                                            id jsonObject2 = [NSJSONSerialization JSONObjectWithData:data2 options:NSJSONReadingMutableContainers error:&error];
                                            if (error) {
                                                NSLog(@"Error parsing JSON2: %@", error);
                                            } else {
                                                //decode the progress string
                                                [jsonObject2 enumerateKeysAndObjectsUsingBlock:^(id key2, id obj2, BOOL *stop2) {
                                                    NSLog(@"key2: %@ obj2: %@", key2, obj2);
                                                    if ([(NSString*)key2 isEqualToString:@"idref"]) {
                                                        idref = obj2;
                                                    } else if ([(NSString*)key2 isEqualToString:@"elementCfi"]) {
                                                        elementCfi = obj2;
                                                    }
                                                }];
                                            }
                                        } else if ([(NSString *) key isEqualToString:@"updated_at"]) {
                                            last_updated = [(NSNumber *) obj integerValue];
                                        }
                                    }];
                                    if (last_updated > [ep lastUpdated])
                                    {
                                        //server's values are more recent
                                        NSLog(@"server more up-to-date server:%ld vs server:%lld", last_updated, [ep lastUpdated]);
                                        //update local db
                                        //last updated
                                        [ep setLastUpdated:last_updated];
                                        //highlights
                                        //progress
                                        [ep setIdref:idref];
                                        [ep setElementCfi:elementCfi];
                                        //save
                                        /*NSError *error = nil;
                                        if ([[appDelegate managedObjectContext] save:&error]) {
                                            NSLog(@"saved");
                                        } else {
                                            // Handle the error.
                                            NSLog(@"Handle the error");
                                        }*/
                                    } else {
                                        //local values are more recent
                                        //update server
                                    }
                                    
                                    RDContainer *m_container = [[RDContainer alloc] initWithDelegate:self path:ePubFile];
                                    RDPackage *m_package = m_container.firstPackage;
                                    //[self popErrorMessage];
                                    
                                    //fix catch error
                                    if (m_package == nil) {
                                        return;
                                    }
                                    
                                    EPubViewController *c = nil;
                                    if ([[ep idref] isEqualToString:@""]) {
                                        //open the epub at start
                                        c = [[EPubViewController alloc]
                                                                 initWithContainer:m_container
                                                                 package:m_package];
                                    } else {
                                        //open the epub at location
                                    
                                        //search for the spineitem with the correct idref to open at correction place
                                        if (m_package.spineItems.count > 0) {
                                            for (int i = 0; i < m_package.spineItems.count; i++) {
                                                RDSpineItem *si = [m_package.spineItems objectAtIndex:i];
                                                if ([si.idref isEqualToString:[ep idref]]) {
                                                    c = [[EPubViewController alloc]
                                                     initWithContainer:m_container
                                                     package:m_package
                                                     spineItem:si
                                                     cfi:[ep elementCfi]];
                                                    break;
                                                }
                                            }
                                        }
                                    }
                                    if (c != nil) {
                                        [self.navigationController pushViewController:c animated:YES];
                                    } else {
                                        //fix error
                                    }
                                }
                            }
                            
                            
                        } else {
                            NSLog(@"no data");
                        }
                    }];
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
                
                [dl setEPubFile:ePubFile];
                [dl setTitle:ep];
                
                [ep setDownloadstatus:1];//fix downloading
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
                
                NSURLRequest *theRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://read.biblemesh.com/epub_content/book_%d/book.epub", ep.bookid]]
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
    return [[appDelegate ePubTitlesArray] count];
}

- (void)viewDidLayoutSubviews {
	m_table.frame = self.view.bounds;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 75.0;
}

@end
