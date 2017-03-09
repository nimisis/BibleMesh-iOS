//
//  Download.m
//  BibleMesh
//
//  Created by David Butler on 17/01/2017.
//  Copyright © 2017 The Readium Foundation. All rights reserved.
//

#import "Download.h"
#import "AppDelegate.h"

@implementation Download

@synthesize theConnection;
@synthesize bgTask;
@synthesize handle;
@synthesize title;
@synthesize ePubFile;
@synthesize bookcell;

- (BOOL)addSkipBackupAttributeToItemAtPath:(NSString *) filePathString
{
    NSURL* URL= [NSURL fileURLWithPath: filePathString];
    assert([[NSFileManager defaultManager] fileExistsAtPath: [URL path]]);
    
    NSError *error = nil;
    BOOL success = [URL setResourceValue: [NSNumber numberWithBool: YES]
                                  forKey: NSURLIsExcludedFromBackupKey error: &error];
    if(!success){
        NSLog(@"Error excluding %@ from backup %@", [URL lastPathComponent], error);
    }
    return success;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    bytesReceived = 0;
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
    NSLog(@"response status code: %ld", (long)[httpResponse statusCode]);
    statusCode = [httpResponse statusCode];
    if (statusCode == 200) {
        [[NSFileManager defaultManager] createFileAtPath:ePubFile contents:nil attributes:nil];
        //make sure file does not get backed up by iCloud
        [self addSkipBackupAttributeToItemAtPath:ePubFile];
        handle = [NSFileHandle fileHandleForWritingAtPath:ePubFile];
        expectedSize = [response expectedContentLength];
        [title setFsize:expectedSize];
        
        NSError *error = nil;
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        if (![[appDelegate managedObjectContext] save:&error]) {
            // Handle the error.
            NSLog(@"Handle the error");
        }
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    bytesReceived = bytesReceived + [data length];
    if (statusCode == 200) {
        [handle writeData:data];
            
        //NSLog(@"got %ld bytes for %@", bytesReceived, connection.originalRequest.URL.absoluteString);
        NSLog(@"got %ld bytes for %@", bytesReceived, ePubFile);
        
        //NSInteger expFlt = expectedSize;
        if (expectedSize == 0) {
            expectedSize = 20000000;//files are unlikely to be bigger than this...
        }
        Float32 downloadDone = 100.0f * ((float) bytesReceived / (float) expectedSize);
        //NSString * progressStr = [NSString stringWithFormat:@"Cancel %.0f%%", downloadDone];
        NSString * progressStr = [NSString stringWithFormat:@"Downloading... %.0f%%", downloadDone];
        NSLog(@"%@", progressStr);
        [[bookcell statusLabel] setText:progressStr];
        //[[bookcell statusLabel] setTextColor:[UIColor blueColor]];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"Download failed: %@", [error description]);//fix
    
    UIAlertView *alert = [[UIAlertView alloc]
                          initWithTitle:@"Download failed!"
                          message:@"Please try again later."
                          delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil];
    [alert show];
    bookcell.statusLabel.text = @"Download";
    
    [title setDownloadstatus:0];//not downloaded
    
    NSError *error2 = nil;
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    if (![[appDelegate managedObjectContext] save:&error2]) {
        // Handle the error.
        NSLog(@"Handle the error");
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSLog(@"did finish download");
    if (statusCode == 200) {
    /*    [title setDownloadstatus:0];//not downloaded
    } else {*/
        [title setDownloadstatus:2];//completed
    } else {
        [title setDownloadstatus:0];//not downloaded
    }
    NSError *error = nil;
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    if (![[appDelegate managedObjectContext] save:&error]) {
        // Handle the error.
        NSLog(@"Handle the error");
    }
    
    bookcell.statusLabel.text = @"";
    
    UIApplication *app = [UIApplication sharedApplication];
    
    if (bgTask != UIBackgroundTaskInvalid) {
        [app endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }
}
@end
