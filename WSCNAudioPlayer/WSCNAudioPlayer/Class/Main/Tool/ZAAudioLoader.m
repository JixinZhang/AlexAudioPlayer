//
//  ZAAudioLoader.m
//  WSCNAudioPlayer
//
//  Created by ZhangBob on 27/03/2017.
//  Copyright © 2017 wallstreetcn.com. All rights reserved.
//

#import "ZAAudioLoader.h"
#import "ZAAudioRequestTask.h"
#import "CommonCrypto/CommonDigest.h"
#import <MobileCoreServices/MobileCoreServices.h>

@interface ZAAudioLoader()<ZAAudioRequestTaskDelegate>
@property (nonatomic, strong) NSMutableArray *pendingRequests;
@property (nonatomic, copy) NSString *audioPath;
@end

@implementation ZAAudioLoader

- (instancetype)initWithCacheFilePath:(NSString *)cacheFilePath {
    self = [super init];
    if (self) {
        _pendingRequests = [NSMutableArray array];
        _audioPath = cacheFilePath;
    }
    return self;
}

#pragma mark - AVAssetResourceLoaderDelegate

/**
 *  必须返回Yes，如果返回NO，则resourceLoader将会加载出现故障的数据
 *  这里会出现很多个loadingRequest请求， 需要为每一次请求作出处理
 *  @param resourceLoader 资源管理器
 *  @param loadingRequest 每一小块数据的请求
 */
- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest {
    [self.pendingRequests addObject:loadingRequest];
    [self dealWithLoadingRequest:loadingRequest];
    return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    [self.pendingRequests removeObject:loadingRequest];
}

- (void)processPendingRequests {
    NSMutableArray *requestsCompleted = [NSMutableArray array];  //请求完成的数组
    //每次下载一块数据都是一次请求，把这些请求放到数组，遍历数组
    for (AVAssetResourceLoadingRequest *loadingRequest in self.pendingRequests) {
        [self fillInContentInformation:loadingRequest.contentInformationRequest]; //对每次请求加上长度，文件类型等信息
        BOOL didRespondCompletely = [self respondWithDataForRequest:loadingRequest.dataRequest]; //判断此次请求的数据是否处理完全
        if (didRespondCompletely) {
            [requestsCompleted addObject:loadingRequest];  //如果完整，把此次请求放进 请求完成的数组
            [loadingRequest finishLoading];
        }
    }
    [self.pendingRequests removeObjectsInArray:requestsCompleted];   //在所有请求的数组中移除已经完成的
}

#pragma mark - ZAAudioRequestTaskDelegate

- (void)didReceiveAudioLength:(NSUInteger)audioLength mimeType:(NSString *)mimeType withTask:(ZAAudioRequestTask *)task {
    NSLog(@"\n didReceiveAudioLength");
}

- (void)didReceiveAudioDataWithTask:(ZAAudioRequestTask *)task {
    [self processPendingRequests];
    NSLog(@"\n didReceiveAudioDataWithTask");
}

- (void)didFinishLoadingWithTask:(ZAAudioRequestTask *)task {
    NSLog(@"\n didFinishLoadingWithTask");
}

- (void)didFailLoadingWithTask:(ZAAudioRequestTask *)task withError:(NSError *)error {
    NSLog(@"\n didFailLoadingWithTask");
}

#pragma mark other


- (void)fillInContentInformation:(AVAssetResourceLoadingContentInformationRequest *)contentInformationRequest {
    NSString *mimeType = self.task.mimeType;
    CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(mimeType), NULL);
    contentInformationRequest.byteRangeAccessSupported = YES;
    contentInformationRequest.contentType = CFBridgingRelease(contentType);
    contentInformationRequest.contentLength = self.task.audioLength;
}

- (NSURL *)getSchemeAudioURL:(NSURL *)url {
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
    components.scheme = @"streaming";
    return [components URL];
}

/**
 *  判断此次请求的数据是否处理完全
 
 @param dataRequest dataRequest
 @return YES：处理完成；NO：尚未处理完成
 */
- (BOOL)respondWithDataForRequest:(AVAssetResourceLoadingDataRequest *)dataRequest {
    long long startOffset = dataRequest.requestedOffset;
    
    if (dataRequest.currentOffset != 0) {
        startOffset = dataRequest.currentOffset;
    }
    if ((self.task.offset +self.task.downloadOffset) < startOffset) {
        //NSLog(@"NO DATA FOR REQUEST");
        return NO;
    }
    if (startOffset < self.task.offset) {
        return NO;
    }
    NSData *filedata = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:_audioPath] options:NSDataReadingMappedIfSafe error:nil];
    // This is the total data we have from startOffset to whatever has been downloaded so far
    NSUInteger unreadBytes = self.task.downloadOffset - ((NSInteger)startOffset - self.task.offset);
    
    // Respond with whatever is available if we can't satisfy the request fully yet
    NSUInteger numberOfBytesToRespondWith = MIN((NSUInteger)dataRequest.requestedLength, unreadBytes);
    [dataRequest respondWithData:[filedata subdataWithRange:NSMakeRange((NSUInteger)startOffset- self.task.offset, (NSUInteger)numberOfBytesToRespondWith)]];
    long long endOffset = startOffset + dataRequest.requestedLength;
    BOOL didRespondFully = (self.task.offset + self.task.downloadOffset) >= endOffset;
    return didRespondFully;
}

- (void)dealWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    NSURL *interceptedURL = [loadingRequest.request URL];
    NSRange range = NSMakeRange((NSUInteger)loadingRequest.dataRequest.currentOffset, NSUIntegerMax);
    
    if (self.task.downloadOffset > 0) {
        [self processPendingRequests];
    }
    
    if (!self.task) {
        self.task = [[ZAAudioRequestTask alloc] initWithCacheFilePath:_audioPath];
        self.task.delegate = self;
        [self.task setUrl:interceptedURL offset:0];
    } else {
        // 如果新的rang的起始位置比当前缓存的位置还大300k，则重新按照range请求数据
        if (self.task.offset + self.task.downloadOffset + 1024 * 300 < range.location ||
            // 如果往回拖也重新请求
            range.location < self.task.offset) {
            [self.task setUrl:interceptedURL offset:range.location];
        }
    }
}

+ (NSString *)stringEncodingWithMd5:(NSString *)inputString {
    const char *string = [inputString UTF8String];
    int length = (int)strlen(string);
    unsigned char bytes[CC_MD5_DIGEST_LENGTH];
    CC_MD5(string, length, bytes);
    NSMutableString *result = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH];
    for (int i = 0; i<CC_MD5_DIGEST_LENGTH; i++) {
        [result appendFormat:@"%02x",bytes[i]];
    }
    return result;
}


@end
