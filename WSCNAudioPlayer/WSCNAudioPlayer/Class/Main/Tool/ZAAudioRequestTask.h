//
//  ZAAudioRequestTask.h
//  WSCNAudioPlayer
//
//  Created by ZhangBob on 27/03/2017.
//  Copyright © 2017 wallstreetcn.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

/**
 *  ZAAudioRequestTaskDelegate
 */
@class ZAAudioRequestTask;
@protocol ZAAudioRequestTaskDelegate <NSObject>

- (void)didReceiveAudioLength:(NSUInteger)audioLength mimeType:(NSString *)mimeType withTask:(ZAAudioRequestTask *)task ;

- (void)didReceiveAudioDataWithTask:(ZAAudioRequestTask *)task;

- (void)didFinishLoadingWithTask:(ZAAudioRequestTask *)task;

- (void)didFailLoadingWithTask:(ZAAudioRequestTask *)task withError:(NSError *)error;

@end

/**
 *  这个Task的功能是从网络请求数据，并把数据保存到本地的一个临时文件。
    网络请求结束的时候，如果数据完整，则把数据缓存到指定的路径，不完整就删除。
 */

@interface ZAAudioRequestTask : NSObject

@property (nonatomic, strong, readonly) NSURL *url;
@property (nonatomic, assign, readonly) NSUInteger offset;

@property (nonatomic, assign, readonly) NSUInteger audioLength;
@property (nonatomic, assign, readonly) NSUInteger downloadOffset;

@property (nonatomic, copy, readonly) NSString *mimeType;
@property (nonatomic, assign) BOOL isFinishLoad;

@property (nonatomic, weak) id<ZAAudioRequestTaskDelegate> delegate;

- (instancetype)initWithCacheFilePath:(NSString *)cacheFilePath;

- (void)setUrl:(NSURL *)url offset:(NSUInteger)offset;

- (void)cancelTask;

- (void)continueTask;

- (void)clearData;

@end
