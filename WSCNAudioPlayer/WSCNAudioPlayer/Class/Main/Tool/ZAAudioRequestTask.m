//
//  ZAAudioRequestTask.m
//  WSCNAudioPlayer
//
//  Created by ZhangBob on 27/03/2017.
//  Copyright © 2017 wallstreetcn.com. All rights reserved.
//

#import "ZAAudioRequestTask.h"
#import "ZAAudioDataLoader.h"
#import "MusicTool.h"

@interface ZAAudioRequestTask()<NSURLSessionDataDelegate, AVAssetResourceLoaderDelegate>

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, assign) NSUInteger offset;

@property (nonatomic, assign) NSUInteger audioLength;
@property (nonatomic, assign) NSUInteger downloadOffset;

@property (nonatomic, copy) NSString *mimeType;

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableArray *taskArr;

@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, copy) NSString *tempPath;

@property (nonatomic, assign) BOOL once;

@end

@implementation ZAAudioRequestTask

- (instancetype)initWithCacheFilePath:(NSString *)cacheFilePath {
    self = [super init];
    if (self) {
        self.taskArr = [NSMutableArray array];
        self.tempPath = cacheFilePath;
        if ([[NSFileManager defaultManager] fileExistsAtPath:self.tempPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:self.tempPath error:nil];
            [[NSFileManager defaultManager] createFileAtPath:self.tempPath contents:nil attributes:nil];
        } else {
            [[NSFileManager defaultManager] createFileAtPath:self.tempPath contents:nil attributes:nil];
        }
    }
    return self;
}

- (void)setUrl:(NSURL *)url offset:(NSUInteger)offset {
    _url = url;
    _offset = offset;
    
    //如果建立第二次请求，先移除原来文件，再创建新的
    if (self.taskArr.count) {
        [[NSFileManager defaultManager] removeItemAtPath:self.tempPath error:nil];
        [[NSFileManager defaultManager] createFileAtPath:self.tempPath contents:nil attributes:nil];
    }
    
    _downloadOffset = 0;
    
    NSURLComponents *actualUrlComponents = [[NSURLComponents alloc] initWithURL:url
                                                  resolvingAgainstBaseURL:NO];
    actualUrlComponents.scheme = @"http";
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[actualUrlComponents URL]
                                                           cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                       timeoutInterval:20.0];
    if (offset > 0 && self.audioLength > 0) {
        [request addValue:[NSString stringWithFormat:@"bytes=%ld-%ld",(unsigned long)offset, (unsigned long)self.audioLength - 1] forHTTPHeaderField:@"Range"];
    }
    
    if (request == nil) {
        return;
    }
    
    self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                          delegate:self
                                                     delegateQueue:[[NSOperationQueue alloc] init]];
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request];
    [task resume];
}

#pragma mark - URLSessionTask

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    _isFinishLoad = NO;
    
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    NSDictionary *dic = [httpResponse allHeaderFields];
    NSString *content = [dic valueForKey:@"Content-Range"];
    NSArray *array = [content componentsSeparatedByString:@"/"];
    NSString *length = array.lastObject;
    
    NSUInteger audioLength;
    if ([length integerValue] == 0) {
        audioLength = (NSUInteger)httpResponse.expectedContentLength;
    } else {
        audioLength = [length integerValue];
    }
    
    self.audioLength = audioLength;
    self.mimeType = @"audio/mp3";
    if ([self.delegate respondsToSelector:@selector(didReceiveAudioLength:mimeType:withTask:)]) {
        [self.delegate didReceiveAudioLength:self.audioLength mimeType:self.mimeType withTask:self];
    }
    [self.taskArr addObject:session];
    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:_tempPath];
    completionHandler(NSURLSessionResponseAllow);
};

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [self.fileHandle seekToEndOfFile];
    
    [self.fileHandle writeData:data];
    
    _downloadOffset += data.length;
    
    if ([self.delegate respondsToSelector:@selector(didReceiveAudioDataWithTask:)]) {
        [self.delegate didReceiveAudioDataWithTask:self];
    }

}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        if (error.code == -1001 && !_once) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self continueTask];
            });
        }
        if ([self.delegate respondsToSelector:@selector(didFailLoadingWithTask:withError:)]) {
            [self.delegate didFailLoadingWithTask:self withError:error];
        }
    } else {
        if (self.taskArr.count < 2) {
            _isFinishLoad = YES;
            NSURLComponents *actualUrlComponents = [[NSURLComponents alloc] initWithURL:_url
                                                                resolvingAgainstBaseURL:NO];
            actualUrlComponents.scheme = @"http";
            
            NSString *movePath = [[MusicTool sharedMusicTool] getAudioCachePathWithURLString:[[actualUrlComponents URL] absoluteString]];
            BOOL isSuccess = [[NSFileManager defaultManager] copyItemAtPath:self.tempPath toPath:movePath error:nil];
            if (isSuccess) {
                NSLog(@"rename success");
                if ([[NSFileManager defaultManager] fileExistsAtPath:self.tempPath]) {
                    [[NSFileManager defaultManager] removeItemAtPath:self.tempPath error:nil];
                }
            } else {
                NSLog(@"rename fail");
            }
            NSLog(@"move path = %@",movePath);
        }
        if ([self.delegate respondsToSelector:@selector(didFinishLoadingWithTask:)]) {
            [self.delegate didFinishLoadingWithTask:self];
        }
    }
}

- (void)continueTask {
    _once = YES;
    NSURLComponents *actualUrlComponents = [[NSURLComponents alloc] initWithURL:self.url
                                                        resolvingAgainstBaseURL:NO];
    actualUrlComponents.scheme = @"http";
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[actualUrlComponents URL]
                                                           cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                       timeoutInterval:20.0];
    [request addValue:[NSString stringWithFormat:@"bytes=%ld-%ld",(unsigned long)self.downloadOffset, (unsigned long)self.audioLength - 1] forHTTPHeaderField:@"Range"];
    
    if (request == nil) {
        return;
    }
    
    self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                 delegate:self
                                            delegateQueue:[[NSOperationQueue alloc] init]];
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request];
    [task resume];
}

- (void)clearData {
    [self.session getTasksWithCompletionHandler:^(NSArray<NSURLSessionDataTask *> * _Nonnull dataTasks, NSArray<NSURLSessionUploadTask *> * _Nonnull uploadTasks, NSArray<NSURLSessionDownloadTask *> * _Nonnull downloadTasks) {
        for (NSURLSessionDataTask *task in dataTasks) {
            [task cancel];
        }
    }];
}

@end
