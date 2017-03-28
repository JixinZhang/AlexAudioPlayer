//
//  ZAAudioDataLoader.h
//  WSCNAudioPlayer
//
//  Created by ZhangBob on 27/03/2017.
//  Copyright © 2017 wallstreetcn.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class ZAAudioRequestTask;
//@protocol ZAAudioLoaderDelegate <NSObject>
//
//- (void)didFinishLoadingWithTask:(ZAAudioRequestTask *)task;
//- (void)didFailLoadingWithTask:(ZAAudioRequestTask *)task error:(NSError *)error;
//
//@end

@interface ZAAudioLoader : NSURLSession<AVAssetResourceLoaderDelegate>

@property (nonatomic, strong) ZAAudioRequestTask *task;
@property (nonatomic, assign) void (^ZAAudioLoaderBlock)(ZAAudioRequestTask *);

- (instancetype)initWithCacheFilePath:(NSString *)cacheFilePath;

- (NSURL *)getSchemeAudioURL:(NSURL *)url;

+ (NSString *)stringEncodingWithMd5:(NSString *)inputString;

@end
