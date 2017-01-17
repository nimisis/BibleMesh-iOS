//
//  Download.h
//  BibleMesh
//
//  Created by David Butler on 17/01/2017.
//  Copyright © 2017 The Readium Foundation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BibleMesh-swift.h" //required for new CoreData codegen

@interface Download : NSObject

{
    NSURLConnection *theConnection;
    UIBackgroundTaskIdentifier bgTask;
    NSInteger bytesReceived;
    NSInteger expectedSize;
    NSFileHandle *handle;
    NSInteger statusCode;
    NSString *ePubFile;
    Epubtitle *title;
}

@property (nonatomic, retain) NSURLConnection *theConnection;
@property (nonatomic, retain) Epubtitle *title;
@property (nonatomic, retain) NSString *ePubFile;
@property UIBackgroundTaskIdentifier bgTask;
@property (nonatomic, retain) NSFileHandle *handle;
@end
