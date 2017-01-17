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
    if (statusCode == 404) {
        //NSLog(@"404");
        //[handle truncateFileAtOffset:0];//deletes file?
    } else {
        [[NSFileManager defaultManager] createFileAtPath:ePubFile contents:nil attributes:nil];
        //make sure file does not get backed up by iCloud
        [self addSkipBackupAttributeToItemAtPath:ePubFile];
        handle = [NSFileHandle fileHandleForWritingAtPath:ePubFile];
        expectedSize = [response expectedContentLength];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    bytesReceived = bytesReceived + [data length];
    if (statusCode == 404) {
        
    } else {
        [handle writeData:data];
            
        //NSLog(@"got %ld bytes for %@", bytesReceived, connection.originalRequest.URL.absoluteString);
        NSLog(@"got %ld bytes for %@", bytesReceived, ePubFile);
        
        //NSInteger expFlt = expectedSize;
        if (expectedSize == 0) {
            expectedSize = 20000000;//files are unlikely to be bigger than this...
        }
        Float32 downloadDone = 100.0f * ((float) bytesReceived / (float) expectedSize);
        NSString * progressStr = [NSString stringWithFormat:@"Cancel %.0f%%", downloadDone];
        NSLog(@"%@", progressStr);
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
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSLog(@"did finish download");
    if (statusCode == 404) {
        [title setDownloadstatus:0];//not downloaded
    } else {
        [title setDownloadstatus:2];//completed
    }
    NSError *error = nil;
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    if (![[appDelegate managedObjectContext] save:&error]) {
        // Handle the error.
        NSLog(@"Handle the error");
    }
    
    UIApplication *app = [UIApplication sharedApplication];
    
    if (bgTask != UIBackgroundTaskInvalid) {
        [app endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }
}
@end
