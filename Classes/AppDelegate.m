//
//  AppDelegate.m
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

#import "AppDelegate.h"
#import <AVFoundation/AVFoundation.h>
#import "ContainerListController.h"
#import "LoginViewController.h"
#import "GAI.h"
#import "GAIDictionaryBuilder.h"
#import "GAIFields.h"
#import "BibleMesh-swift.h" //required for new CoreData codegen
#import "EPubViewController.h"
#import "RDPackage.h"
#import "RDSpineItem.h"

@interface AppDelegate()

- (void)configureAppearance;

@end


@implementation AppDelegate

@synthesize downloadQueue;
@synthesize hostReachability;
@synthesize lvc;
@synthesize clc;
@synthesize locsArray;
@synthesize booksArray;
@synthesize highlightsArray;
@synthesize userid;
@synthesize serverTimeOffset;
@synthesize latestLocation;

- (BOOL)
	application:(UIApplication *)application
	didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    //fix
    userid = 1;
    serverTimeOffset = 0;
    
    //Google analytics
    [[GAI sharedInstance] trackerWithTrackingId:@"UA-67167622-8"];
    
    //callback for connectivity
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
    NSString *remoteHostName = @"www.biblemesh.com";//fix read.biblemesh.com
    self.hostReachability = [Reachability reachabilityWithHostName:remoteHostName];
    [self.hostReachability startNotifier];
    
    //store for thumbnail images
    downloadQueue = [[NSOperationQueue alloc] init];

    //for media elements
	[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];

    //Core data
    NSManagedObjectContext *context = [self managedObjectContext];
    if (!context) {
        NSLog(@"Handle the NSManagedContext error");
    }
    
    booksArray = [[NSMutableArray alloc] init];
    locsArray = [[NSMutableArray alloc] init];
    highlightsArray = [[NSMutableArray alloc] init];
    //latestLocation = [[Location alloc] init];
    
    //[[self latestLocation] setLastUpdated:0];
    
    //start fetch from database
    {
        
        NSFetchRequest *request2 = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity2 = [NSEntityDescription entityForName:@"Location" inManagedObjectContext:managedObjectContext];
        [request2 setEntity:entity2];
        
        NSError *error2 = nil;
        NSMutableArray *mutableFetchResults2 = [[managedObjectContext executeFetchRequest:request2 error:&error2] mutableCopy];
        if (mutableFetchResults2 == nil) {
            // Handle the error.
        }
        
        //latestLocation = [[Location alloc] init];
        /*if ([mutableFetchResults2 count] > 0) {
            [self setLatestLocation:[mutableFetchResults2 objectAtIndex:0]];
            [self setLocsArray:mutableFetchResults2];
            NSLog(@"userid %d", [[self latestLocation] userid]);
        }*/
        NSLog(@"Got %lu locations", (unsigned long)[mutableFetchResults2 count]);
        
        
        NSFetchRequest *request1 = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity1 = [NSEntityDescription entityForName:@"Highlight" inManagedObjectContext:managedObjectContext];
        [request1 setEntity:entity1];
        
        NSError *error1 = nil;
        NSMutableArray *mutableFetchResults1 = [[managedObjectContext executeFetchRequest:request1 error:&error1] mutableCopy];
        if (mutableFetchResults1 == nil) {
            // Handle the error.
        }
        
        //[self setHighlightsArray:mutableFetchResults1];
        NSLog(@"Got %lu highlights", (unsigned long)[mutableFetchResults1 count]);
        
        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Epubtitle" inManagedObjectContext:managedObjectContext];
        [request setEntity:entity];
        
        //NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"downloadDate" ascending:NO];
         //NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
         //[request setSortDescriptors:sortDescriptors];
         //[sortDescriptors release];
         //[sortDescriptor release];
        
        NSError *error;
        NSMutableArray *mutableFetchResults = [[managedObjectContext executeFetchRequest:request error:&error] mutableCopy];
        if (mutableFetchResults == nil) {
            // Handle the error.
        }
        
        [self setBooksArray:mutableFetchResults];
        NSLog(@"Got %lu Epubtitles", (unsigned long)[mutableFetchResults count]);
        for (int i = 0; i < (unsigned long)[mutableFetchResults count]; i++) {
            Epubtitle *ept = [mutableFetchResults objectAtIndex:i];
            if (ept.downloadstatus == 1) {
                NSLog(@"found a title that is mid-download");
                ept.downloadstatus = 0;
                NSError *error = nil;
                if (![[self managedObjectContext] save:&error]) {
                    // Handle the error.
                }
            }
            NSLog(@"downloadstatus %d", ept.downloadstatus);
        }
        
        /*for (int i = 0; i < (unsigned long)[mutableFetchResults count]; i++) {
            Epubtitle *ept = [mutableFetchResults objectAtIndex:i];
            if (ept.bookid == 1) {
                NSMutableDictionary *postDict = [[NSMutableDictionary alloc] init];
                NSMutableDictionary *latest_location = [[NSMutableDictionary alloc] init];
                [latest_location setValue:ept.idref forKey:@"idref"];
                [latest_location setValue:ept.elementCfi forKey:@"elementCfi"];
                [postDict setValue:latest_location forKey:@"latest_location"];
                [postDict setValue:[NSNumber numberWithLongLong:ept.lastUpdated] forKey:@"updated_at"];
                NSMutableArray *highlights = [[NSMutableArray alloc] init];
                for (int j = 0; j < (unsigned long)[mutableFetchResults1 count]; j++) {
                    Highlight *hl = [mutableFetchResults1 objectAtIndex:j];
                    if ((hl.bookid == 1) && (hl.userid == 1)) {
                        NSMutableDictionary *hld = [[NSMutableDictionary alloc] init];
                        [hld setValue:hl.cfi forKey:@"cfi"];
                        [hld setValue:[NSNumber numberWithInt:hl.color] forKey:@"color"];
                        [hld setValue:hl.note forKey:@"note"];
                        [hld setValue:[NSNumber numberWithLongLong:hl.lastUpdated] forKey:@"updated_at"];
                        [highlights addObject:hld];
                    }
                }
                [postDict setValue:highlights forKey:@"highlights"];
                NSData *jsonData = [NSJSONSerialization dataWithJSONObject:postDict options:0 error:nil];
                
                // Checking the format
                NSLog(@"%@",[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]);
            }
        }*/
    }
    
    //start window
	self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
	[self configureAppearance];
    
    clc = [[ContainerListController alloc] init];
    lvc = [[LoginViewController alloc] initWithNibName:@"LoginViewController" bundle:nil];
    self.window.rootViewController = lvc;//[[UINavigationController alloc] initWithRootViewController:lvc];
    
    [self.window makeKeyAndVisible];

	return YES;
}

//connectivity callback
- (void)reachabilityChanged:(NSNotification *)note {
    Reachability* curReach = [note object];
    NSParameterAssert([curReach isKindOfClass: [Reachability class]]);
    NetworkStatus status = [curReach currentReachabilityStatus];
    if (status == NotReachable) {
        NSLog(@"NotReachable.");
    } else {
        NSLog(@"IsReachable.");
    }
}

//URL scheme
- (BOOL)
	application:(UIApplication *)application
	openURL:(NSURL *)url
	sourceApplication:(NSString *)sourceApplication
	annotation:(id)annotation
{
    if ([[url scheme] isEqualToString:@"biblemesh"]) {
        NSLog(@"handle biblemesh url scheme");
        
        NSString* reducedUrl = [NSString stringWithFormat:
                                @"%@",
                                url.pathComponents[2]];
        
        UIAlertView *urlscheme = [[UIAlertView alloc]
                              initWithTitle:@"TODO"
                                  message:[NSString stringWithFormat:@"URL scheme link clicked. Book ID: %@", reducedUrl]
                              delegate:nil
                              cancelButtonTitle:LocStr(@"GENERIC_CANCEL")
                              otherButtonTitles:nil];
        [urlscheme show];
    }
    return YES;
    
	/*if (!url.isFileURL) {
		return NO;
	}

	NSString *pathSrc = url.path;

	if (![pathSrc.lowercaseString hasSuffix:@".epub"]) {
		return NO;
	}

	NSString *fileName = pathSrc.lastPathComponent;
	NSString *docsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
		NSUserDomainMask, YES) objectAtIndex:0];
	NSString *pathDst = [docsPath stringByAppendingPathComponent:fileName];
	NSFileManager *fm = [NSFileManager defaultManager];

	if ([fm fileExistsAtPath:pathDst]) {
		return NO;
	}

	[fm copyItemAtPath:pathSrc toPath:pathDst error:nil];
	return YES;*/
}

- (void)configureAppearance {
	UIColor *color = [UIColor colorWithRed:39/255.0 green:136/255.0 blue:156/255.0 alpha:1];

	if ([self.window respondsToSelector:@selector(setTintColor:)]) {
		self.window.tintColor = color;
	}
	else {
		[[UINavigationBar appearance] setTintColor:color];
		[[UIToolbar appearance] setTintColor:color];
	}
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    NSError *error = nil;
    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            /*
             Replace this implementation with code to handle the error appropriately.
             
             abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
             */
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

#pragma mark -
#pragma mark Core Data stack

/**
 Returns the managed object context for the application.
 If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
 */
- (NSManagedObjectContext *) managedObjectContext {
    
    if (managedObjectContext != nil) {
        return managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        managedObjectContext = [[NSManagedObjectContext alloc] init];
        [managedObjectContext setPersistentStoreCoordinator: coordinator];
    }
    return managedObjectContext;
}


/**
 Returns the managed object model for the application.
 If the model doesn't already exist, it is created by merging all of the models found in the application bundle.
 */
- (NSManagedObjectModel *)managedObjectModel {
    
    if (managedObjectModel != nil) {
        return managedObjectModel;
    }
    managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];// retain];
    return managedObjectModel;
}


/**
 Returns the persistent store coordinator for the application.
 If the coordinator doesn't already exist, it is created and the application's store added to it.
 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    
    if (persistentStoreCoordinator != nil) {
        return persistentStoreCoordinator;
    }
    
    NSURL *storeUrl = [NSURL fileURLWithPath: [[self applicationDocumentsDirectory] stringByAppendingPathComponent: @"Direct.sqlite"]];
    
    NSError *error = nil;
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeUrl options:nil error:&error]) {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
         
         Typical reasons for an error here include:
         * The persistent store is not accessible
         * The schema for the persistent store is incompatible with current managed object model
         Check the error message to determine what the actual problem was.
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return persistentStoreCoordinator;
}

/**
 Returns the path to the application's Documents directory.
 */
- (NSString *)applicationDocumentsDirectory {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}

+(void)downloadDataFromURL:(NSURL *)url patch:(NSString *)patch withCompletionHandler:(void (^)(NSData *))completionHandler {
    // Instantiate a session configuration object.
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    
    // Instantiate a session object.
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    
    // Create a data task object to perform the data downloading.
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    if (patch != nil) {
        NSData *requestData = [patch dataUsingEncoding:NSUTF8StringEncoding];
        [request setHTTPBody:requestData];
        [request setHTTPMethod:@"PATCH"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[requestData length]] forHTTPHeaderField:@"Content-Length"];
    }
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        if (error != nil) {
            // If any error occurs then just display its description on the console.
            NSLog(@"%@", [error localizedDescription]);
        } else {
            // If no error occurs, check the HTTP status code.
            NSInteger HTTPStatusCode = [(NSHTTPURLResponse *)response statusCode];
            
            // If it's other than 200, then show it on the console.
            if (HTTPStatusCode != 200) {
                NSLog(@"HTTP status code = %ld", (long)HTTPStatusCode);
            }
        }
        
        // Call the completion handler with the returned data on the main thread.
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            completionHandler(data);
        }];
    }];
    
    [task resume];
}

- (void) getLibrary:(BOOL)launchcontainer
{
    NSString *URLString = @"https://read.biblemesh.com/epub_content/epub_library.json";
    NSURL *url = [NSURL URLWithString:URLString];
    [AppDelegate downloadDataFromURL:url patch:nil withCompletionHandler:^(NSData *data) {
        
        NSLog(@"returned");
        
        NSError *error = nil;
        id jsonq = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
        NSArray *jsonArray = NULL;
        if ([jsonq isKindOfClass:[NSArray class]]) {
            jsonArray =(NSArray *)jsonq;
        } else if ([jsonq isKindOfClass:[NSDictionary class]]) {
            NSLog(@"%@", jsonq);//fix cause logout if we get {error = "Please login"}
        } else {
            NSLog(@"something else");
        }
        if (!jsonArray) {
            NSLog(@"Error parsing JSON: %@", error);
        } else {
            //fix!
            //delete current local store for this user?
            NSFetchRequest *request = [[NSFetchRequest alloc] init];
            NSEntityDescription *entity = [NSEntityDescription entityForName:@"Location" inManagedObjectContext:managedObjectContext];
            [request setEntity:entity];
            
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userid == %d", userid];
            [request setPredicate:predicate];
            NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"bookid" ascending:YES];
            NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
            [request setSortDescriptors:sortDescriptors];
            
            NSError *error = nil;
            NSMutableArray *mutableFetchResults = [[managedObjectContext executeFetchRequest:request error:&error] mutableCopy];
            if (mutableFetchResults == nil) {
                // Handle the error.
            }
            
            //[self setEpubtitlesArray:mutableFetchResults];
            NSLog(@"Got %lu Locations", (unsigned long)[mutableFetchResults count]);
            /*for(Location *title in mutableFetchResults) {
             if (title.locationToEpub == nil) {
             NSLog(@"nil loc to Epub");
             } else {
             NSLog(@"bookid %d", title.locationToEpub.bookid);
             }
             }*/
            
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
            int localIndex = 0;
            for(NSDictionary* item in jsonArray) {
                
                NSLog(@"Item: %@", item);
                //if ([ite isKindOfClass:[NSDictionary class]]) {
                    __block NSInteger bookid;
                    __block NSDate *updatedAt;
                    __block NSString *author;
                    //__block NSString *coverHref;
                    __block NSString *rootUrl;
                    __block NSString *title;
                    [item enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop) {
                        if ([(NSString *) key  isEqual: @"id"]) {
                            bookid = [obj integerValue];
                        } else if ([(NSString *) key  isEqual: @"author"]) {
                            author = obj;
                        } else if ([(NSString *) key  isEqual: @"coverHref"]) {
                            //fix not used coverHref = obj;
                        } else if ([(NSString *) key  isEqual: @"rootUrl"]) {
                            rootUrl = obj;
                        } else if ([(NSString *) key  isEqual: @"title"]) {
                            title = obj;
                        } else if ([(NSString *) key  isEqual: @"updated_at"]) {
                            updatedAt = [dateFormatter dateFromString:obj];
                        }
                    }];
                    Location *lep = nil;
                    if (localIndex < [mutableFetchResults count]) {
                        lep = [mutableFetchResults objectAtIndex:localIndex];
                    }
                    while ((lep != nil) && ([lep bookid] < bookid)) {
                        //delete all epub titles until we get a match
                        [managedObjectContext deleteObject:lep];
                        //fix delete all associated highlights too.
                        if ([managedObjectContext save:&error]) {
                            NSLog(@"saved");
                        } else {
                            // Handle the error.
                            NSLog(@"Handle the error");
                        }
                        [mutableFetchResults removeObjectAtIndex:localIndex];
                        if (localIndex < [mutableFetchResults count]) {
                            lep = nil;
                        } else {
                            lep = [mutableFetchResults objectAtIndex:localIndex];
                        }
                    }
                    Boolean insertnew = false;
                    if (lep != nil) {
                        if ([lep bookid] == bookid) {
                            //test for dates
                            //if server is newer, update with new server values
                            /*NSLog(@"comparing %ld %lld", (long) [updatedAt timeIntervalSince1970], [lep lastUpdated]);
                             if ([updatedAt timeIntervalSince1970] > [lep lastUpdated]) {
                             [lep setAuthor:author];
                             [lep setTitle:title];
                             [lep setLastUpdated:[updatedAt timeIntervalSince1970]];
                             [lep setCoverHref:coverHref];
                             [lep setRootUrl:rootUrl];
                             if ([[appDelegate managedObjectContext] save:&error]) {
                             NSLog(@"saved");
                             } else {
                             // Handle the error.
                             NSLog(@"Handle the error");
                             }
                             } else {
                             //do nothing as local version is up-to-date
                             }*/
                            localIndex++;
                        } else {
                            //new book
                            insertnew = true;
                        }
                    } else {
                        insertnew = true;
                    }
                    if (insertnew) {
                        //insert new location
                        Location *lo = (Location *)[NSEntityDescription insertNewObjectForEntityForName:@"Location" inManagedObjectContext:managedObjectContext];
                        [lo setBookid:[[NSNumber numberWithInt:bookid] intValue]];
                        [lo setUserid:[[NSNumber numberWithInt:userid] intValue]];
                        //search through epubs for this book id;
                        lo.locationToEpub = nil;
                        for (Epubtitle* ep in booksArray) {
                            if ([ep bookid] == bookid) {
                                lo.locationToEpub = ep;
                                break;
                            }
                        }
                        if (lo.locationToEpub == nil) {
                            Epubtitle *ep = (Epubtitle *)[NSEntityDescription insertNewObjectForEntityForName:@"Epubtitle" inManagedObjectContext:managedObjectContext];
                            //[ep setUserid:[[NSNumber numberWithInt:userid] intValue]];
                            [ep setBookid:[[NSNumber numberWithInt:bookid] intValue]];
                            [ep setAuthor:author];
                            [ep setTitle:title];
                            //[ep setLastUpdated:[updatedAt timeIntervalSince1970]];
                            //fix not used [ep setCoverHref:coverHref];
                            [ep setRootUrl:rootUrl];
                            lo.locationToEpub = ep;
                        }
                        if ([managedObjectContext save:&error]) {
                            NSLog(@"saved");
                            [mutableFetchResults insertObject:lo atIndex:localIndex];
                            localIndex++;
                        } else {
                            // Handle the error.
                            NSLog(@"Handle the error");
                        }
                    }
                //}
            }
            
            Location *lep = nil;
            while (localIndex < [mutableFetchResults count]) {
                lep = [mutableFetchResults objectAtIndex:localIndex];
                //delete all epub titles until we get a match
                [managedObjectContext deleteObject:lep];
                //fix delete all associated highlights too.
                if ([managedObjectContext save:&error]) {
                    NSLog(@"saved");
                } else {
                    // Handle the error.
                    NSLog(@"Handle the error");
                }
                [mutableFetchResults removeObjectAtIndex:localIndex];
            }
            
            [self setLocsArray:mutableFetchResults];
            
            for (int i = 0; i < [locsArray count]; i++) {
                Location *loc = [locsArray objectAtIndex:i];
                if ([[loc locationToEpub] downloadstatus] == 1) {
                    NSLog(@"found a title that is mid-download");
                    [[loc locationToEpub] setDownloadstatus:0];
                    NSError *error = nil;
                    if (![managedObjectContext save:&error]) {
                        // Handle the error.
                    }
                }
                //NSLog(@"downloadstatus %d", ept.downloadstatus);
            }
            //while ((lep != nil) && ([lep bookid] < bookid)) {
        }
        //show library view
        if (launchcontainer) {
            self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:clc];
        } else {
            //refresh clc
            [[clc m_table] reloadData];
        }
    }];
}

- (void) getServerTime {
    NSString *URLString = @"https://read.biblemesh.com/usersetup.json";
    NSURL *url = [NSURL URLWithString:URLString];
    [AppDelegate downloadDataFromURL:url patch:nil withCompletionHandler:^(NSData *userdata) {
        
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
                    [self setServerTimeOffset:(serverTime - [unixtime longLongValue])];
                } else if ([(NSString *) key isEqualToString:@"userInfo"]) {
                    NSDictionary *dic = (NSDictionary *)obj;
                    NSLog(@"userID is %ld", [[dic valueForKey:@"id"] integerValue]);
                    if (userid != [[dic valueForKey:@"id"] integerValue]) {
                        NSLog(@"userid mismatch!");
                    }
                    //fix
                    /*[self setUserid: [[dic valueForKey:@"id"] integerValue]];
                    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                    [defaults setInteger:[[dic valueForKey:@"id"] integerValue] forKey:@"userid"];
                    [defaults synchronize];*/
                } else if ([(NSString *) key isEqualToString:@"gaCode"]) {//fix todo
                } else if ([(NSString *) key isEqualToString:@"error"]) {//fix todo
                } else {
                    NSLog(@"other usersetup value");
                }
            }];
        }
        
    }];
}

- (void) refreshData:(NSString*)ePubFile {
    
    //Location *ep = [self latestLocation];
    NSError *error = nil;
    /*NSFetchRequest *request1 = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity1 = [NSEntityDescription entityForName:@"Location" inManagedObjectContext:[self managedObjectContext]];
    [request1 setEntity:entity1];
    
    NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"userid == %d && bookid == %d", [self userid], [ep bookid]];
    //[request setEntity:[NSEntityDescription entityForName:@"DVD" inManagedObjectContext:moc]];
    [request1 setPredicate:predicate1];
    //NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"cfi" ascending:YES];
    //NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
    //[request setSortDescriptors:sortDescriptors];
    
    NSError *error = nil;
    NSMutableArray *mutableFetchResults1 = [[[self managedObjectContext] executeFetchRequest:request1 error:&error] mutableCopy];
    if (mutableFetchResults1 == nil) {
        // Handle the error.
        return;
    }
    
    if ([mutableFetchResults1 count] == 0) {
        Location *eloc = (Location *)[NSEntityDescription insertNewObjectForEntityForName:@"Location" inManagedObjectContext:[self managedObjectContext]];
        [eloc setUserid:[self userid]];
        [eloc setBookid:[ep bookid]];
        [eloc setIdref:@""];
        NSError *error = nil;
        if (![[self managedObjectContext] save:&error]) {
            // Handle the error.
        }
        [self setLatestLocation:eloc];
    } else {
        [self setLatestLocation:[mutableFetchResults1 objectAtIndex:0]];
    }
    NSLog(@"Have %lu latestlocation", (unsigned long)[mutableFetchResults1 count]);
    */
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Highlight" inManagedObjectContext:[self managedObjectContext]];
    [request setEntity:entity];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userid == %d && bookid == %d", [self userid], [[self latestLocation] bookid]];
    //[request setEntity:[NSEntityDescription entityForName:@"DVD" inManagedObjectContext:moc]];
    [request setPredicate:predicate];
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"cfi" ascending:YES];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
    [request setSortDescriptors:sortDescriptors];
    
    //NSError *error = nil;
    NSMutableArray *mutableFetchResults = [[[self managedObjectContext] executeFetchRequest:request error:&error] mutableCopy];
    if (mutableFetchResults == nil) {
        // Handle the error.
        return;
    }
    
    [self setHighlightsArray:mutableFetchResults];
    NSLog(@"Have %lu highlights", (unsigned long)[mutableFetchResults count]);
    
    //fix
    /*NetworkStatus netStatus = [[appDelegate hostReachability] currentReachabilityStatus];
     if (netStatus == NotReachable) {
     NSLog(@"no internet");
     } else*/
    {
        NSString *URLString = [NSString stringWithFormat:@"https://read.biblemesh.com/users/%ld/books/%d.json", (long)[self userid], [[self latestLocation] bookid]];
        NSURL *url = [NSURL URLWithString:URLString];
        [AppDelegate downloadDataFromURL:url patch:nil withCompletionHandler:^(NSData *data) {
            __block NSInteger last_updated;
            __block NSString *idref;
            __block NSString *elementCfi;
            //check local data against data returned
            if ((data == nil) || ([data length] == 0)) {
                NSLog(@"no data");
                //return;
            } else {
                NSError *error = nil;
                id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
                if (error) {
                    NSLog(@"Error parsing JSON: %@", error);
                    return;
                }
                if ([jsonObject isKindOfClass:[NSArray class]]) {
                    NSLog(@"is array");
                    return;
                }
                NSMutableArray *serverHighlights = [[NSMutableArray alloc] init];
                [jsonObject enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                    NSLog(@"key: %@", key);
                    if ([(NSString *) key isEqualToString:@"highlights"]) {
                        if ([obj isKindOfClass:[NSArray class]]) {
                            NSLog(@"is array2");
                            NSArray *ar = (NSArray *) obj;
                            for (int i = 0; i < [ar count]; i++) {
                                NSDictionary *dic = (NSDictionary *)[ar objectAtIndex:i];
                                
                                [serverHighlights addObject:dic];
                                /*NSData *data3 = [(NSString *) [ar objectAtIndex:i] dataUsingEncoding:NSUTF8StringEncoding];
                                 NSError *error = nil;
                                 id jsonObject3 = [NSJSONSerialization JSONObjectWithData:data3 options:NSJSONReadingMutableContainers error:&error];
                                 if (error) {
                                 NSLog(@"Error parsing JSON3: %@", error);
                                 } else*/ {
                                     //decode the progress string
                                     /*Highlight *shl = [[Highlight alloc] init];
                                      [shl setUserid:(int) userid];
                                      [shl setBookid:ep.bookid];
                                      [dic enumerateKeysAndObjectsUsingBlock:^(id key3, id obj3, BOOL *stop3) {
                                      NSLog(@"key3: %@ obj3: %@", key3, obj3);
                                      if ([(NSString*)key3 isEqualToString:@"cfi"]) {
                                      [shl setCfi:obj3];
                                      } else if ([(NSString*)key3 isEqualToString:@"color"]) {
                                      [shl setColor:(int) [(NSNumber *) obj3 integerValue]];
                                      } else if ([(NSString*)key3 isEqualToString:@"updated_at"]) {
                                      [shl setLastUpdated:[(NSNumber *) obj3 integerValue]];
                                      } else if ([(NSString*)key3 isEqualToString:@"note"]) {
                                      [shl setNote:obj3];
                                      }
                                      }];
                                      [serverHighlights addObject:shl];*/
                                 }
                            }
                        } else {
                            NSLog(@"unexpected");
                        }
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
                                    if ([obj2 isKindOfClass:[NSString class]]) {
                                        elementCfi = obj2;
                                    } else {
                                        elementCfi = NULL;
                                    }
                                }
                            }];
                        }
                    } else if ([(NSString *) key isEqualToString:@"updated_at"]) {
                        last_updated = [(NSNumber *) obj longLongValue];
                    }
                }];
                
                
                /* pseudo code
                 for each server highlight, look for matching in local,
                 if match found
                 compare lastupdated value
                 if server value is newer (i.e. bigger)
                 update local
                 if server value is older (i.e. smaller)
                 ignore
                 if highlight is in queue to update the server (unlikely)
                 ignore
                 else
                 update server (should never happen as !)
                 if same
                 ignore (no change)
                 else
                 add highlight to local
                 
                 for each local highlight not matched above
                 if highlight is in queue to update the server
                 ignore
                 else
                 delete (must have been deleted somewhere else)
                */
                
                {
                    //highlights
                    //remove all highlights from highlights array with this userid and bookid
                    
                    NSMutableArray *oldhighlightsArray = [[self highlightsArray] copy];
                    [highlightsArray removeAllObjects];
                    
                    NSMutableArray *validHighlights = [[NSMutableArray alloc] initWithCapacity:oldhighlightsArray.count];
                    //for (Highlight *oldhl in oldhighlightsArray) {
                    for (int i = 0; i < oldhighlightsArray.count; i++) {
                        [validHighlights addObject:[NSNumber numberWithBool:NO]];
                    }
                    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"Highlight" inManagedObjectContext:[self managedObjectContext]];
                    
                    for (int i = 0; i < [serverHighlights count]; i++) {
                        NSDictionary *dic = [serverHighlights objectAtIndex:i];
                        
                        
                        Highlight *temphl = [[Highlight alloc] initWithEntity:entityDescription insertIntoManagedObjectContext:nil];
                        
                        [dic enumerateKeysAndObjectsUsingBlock:^(id key3, id obj3, BOOL *stop3) {
                            NSLog(@"key3: %@ obj3: %@", key3, obj3);
                            if ([(NSString*)key3 isEqualToString:@"spineIdRef"]) {
                                [temphl setIdref:obj3];
                                //[temphl setIdref:@"daveown"];
                            } else if ([(NSString*)key3 isEqualToString:@"cfi"]) {
                                [temphl setCfi:obj3];
                            } else if ([(NSString*)key3 isEqualToString:@"color"]) {
                                [temphl setColor:(int) [(NSNumber *) obj3 integerValue]];
                            } else if ([(NSString*)key3 isEqualToString:@"updated_at"]) {
                                [temphl setLastUpdated:[(NSNumber *) obj3 longLongValue]];
                            } else if ([(NSString*)key3 isEqualToString:@"note"]) {
                                [temphl setNote:obj3];
                            }
                        }];
                        Boolean foundmatch = false;
                        NSInteger index = 0;
                        for (Highlight *oldhl in oldhighlightsArray) {
                            if ([temphl.cfi isEqualToString:oldhl.cfi] && [temphl.idref isEqualToString:oldhl.idref]) {
                                foundmatch = true;
                                [validHighlights setObject:[NSNumber numberWithBool:YES] atIndexedSubscript:index];
                                if (temphl.lastUpdated > oldhl.lastUpdated) {
                                    [oldhl setLastUpdated:[temphl lastUpdated]];
                                    [oldhl setColor:[temphl color]];
                                    [oldhl setNote:[temphl note]];
                                    NSError *error = nil;
                                    if ([[self managedObjectContext] save:&error]) {
                                        NSLog(@"saved");
                                        [[self highlightsArray] addObject:oldhl];
                                    } else {
                                        // Handle the error.
                                        NSLog(@"Handle the error");
                                    }
                                } else if (temphl.lastUpdated < oldhl.lastUpdated) {
                                    //ignore
                                    [[self highlightsArray] addObject:oldhl];
                                } else {
                                    [[self highlightsArray] addObject:oldhl];
                                }
                                break;
                            }
                            index++;
                        }
                        if (!foundmatch) {
                            Highlight *hl = (Highlight *)[NSEntityDescription insertNewObjectForEntityForName:@"Highlight" inManagedObjectContext:[self managedObjectContext]];
                            [hl setCfi:[temphl cfi]];
                            [hl setIdref:[temphl idref]];
                            [hl setLastUpdated:[temphl lastUpdated]];
                            [hl setColor:[temphl color]];
                            [hl setNote:[temphl note]];
                            [hl setUserid:[self userid]];
                            [hl setBookid:[[self latestLocation] bookid]];
                            
                            NSError *error = nil;
                            if ([[self managedObjectContext] save:&error]) {
                                NSLog(@"saved");
                                [[self highlightsArray] addObject:hl];
                            } else {
                                // Handle the error.
                                NSLog(@"Handle the error");
                            }
                        }
                    }
                    //remove unmatched
                    for (int i = 0; i < validHighlights.count; i++) {
                        if ([[validHighlights objectAtIndex:i] isEqual:[NSNumber numberWithBool:YES]]) {
                            NSLog(@"skip");
                        } else {
                            Highlight *t = [oldhighlightsArray objectAtIndex:i];
                            
                            NSManagedObject *hlToDelete = t;
                            [[self managedObjectContext] deleteObject:hlToDelete];
                            
                            // Commit the change.
                            NSError *error;
                            if (![[self managedObjectContext] save:&error]) {
                                // Handle the error.
                            }
                        }
                    }
                    
                    
                    /*NSLog(@"num highlights a %ld", [[self highlightsArray] count]);
                    for (int i = 0; i < [[self highlightsArray] count]; i++) {
                        NSManagedObject *hl = [[self highlightsArray] objectAtIndex:i];
                        NSLog(@"user %d book %d", [(Highlight *)hl userid], [(Highlight *)hl bookid]);
                        if (([(Highlight *)hl userid] == [self userid]) && ([(Highlight *)hl bookid] == [[self latestLocation] bookid])) {
                            [[self managedObjectContext] deleteObject:hl];
                            NSError *error = nil;
                            if (![[self managedObjectContext] save:&error]) {
                                // Handle the error.
                            }
                            [[self highlightsArray] removeObjectAtIndex:i];
                            i--;
                        } else {
                            
                        }
                    }
                    NSLog(@"num highlights b %ld", [[self highlightsArray] count]);
                    
                    //re-populate the highlights array with data from server
                    for (int i = 0; i < [serverHighlights count]; i++) {
                        NSDictionary *dic = [serverHighlights objectAtIndex:i];
                        
                        Highlight *hl = (Highlight *)[NSEntityDescription insertNewObjectForEntityForName:@"Highlight" inManagedObjectContext:[self managedObjectContext]];
                        [hl setUserid:[self userid]];
                        [hl setBookid:[[self latestLocation] bookid]];
                        [dic enumerateKeysAndObjectsUsingBlock:^(id key3, id obj3, BOOL *stop3) {
                            NSLog(@"key3: %@ obj3: %@", key3, obj3);
                            if ([(NSString*)key3 isEqualToString:@"spineIdRef"]) {
                                [hl setIdref:obj3];
                            } else if ([(NSString*)key3 isEqualToString:@"cfi"]) {
                                [hl setCfi:obj3];
                            } else if ([(NSString*)key3 isEqualToString:@"color"]) {
                                [hl setColor:(int) [(NSNumber *) obj3 integerValue]];
                            } else if ([(NSString*)key3 isEqualToString:@"updated_at"]) {
                                [hl setLastUpdated:[(NSNumber *) obj3 longLongValue]];
                            } else if ([(NSString*)key3 isEqualToString:@"note"]) {
                                [hl setNote:obj3];
                            }
                        }];
                        
                        NSError *error = nil;
                        if ([[self managedObjectContext] save:&error]) {
                            NSLog(@"saved");
                            [[self highlightsArray] addObject:hl];
                        } else {
                            // Handle the error.
                            NSLog(@"Handle the error");
                        }
                    }*/
                }
                
                if (last_updated > [[self latestLocation] lastUpdated])
                {
                    //server's values are more recent
                    NSLog(@"server more up-to-date server:%ld vs server:%lld", last_updated, [[self latestLocation] lastUpdated]);
                    //last updated
                    [[self latestLocation] setLastUpdated:last_updated];
                    //progress
                    [[self latestLocation] setIdref:idref];
                    [[self latestLocation] setElementCfi:elementCfi];
                    
                    //save
                    NSError *error = nil;
                    if ([[self managedObjectContext] save:&error]) {
                        NSLog(@"saved");
                    } else {
                        // Handle the error.
                        NSLog(@"Handle the error");
                    }
                } else {
                    //local values are more recent
                    //fix update server?
                }
            }
            if (clc == nil) {
                NSLog(@"clc is null!");
            } else {
                RDContainer *m_container = [[RDContainer alloc] initWithDelegate:clc path:ePubFile];
                RDPackage *m_package = m_container.firstPackage;
                //[self popErrorMessage];
                
                //fix catch error
                if (m_package == nil) {
                    return;
                }
                
                EPubViewController *c = nil;
                if (([[self latestLocation] idref] == nil) ||
                    ([[[self latestLocation] idref] isEqualToString:@""])) {
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
                            if ([[si idref] isEqualToString:[[self latestLocation] idref]]) {
                                c = [[EPubViewController alloc]
                                     initWithContainer:m_container
                                     package:m_package
                                     spineItem:si
                                     cfi:[[self latestLocation] elementCfi]];
                                break;
                            }
                        }
                    }
                }
                if (c != nil) {
                    //[c setLoc:[self latestLocation]];
                    [clc.navigationController pushViewController:c animated:YES];
                } else {
                    //fix error
                }
            }
            
            
        }];
    }
}

@end
