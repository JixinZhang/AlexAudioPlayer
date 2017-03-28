//
//  MusicTool.m
//  CloudMusic
//
//  Created by LiDan on 15/12/14.
//  Copyright © 2015年 com.lidan. All rights reserved.
//

#import "MusicTool.h"

@implementation MusicTool

singleton_implementation(MusicTool)

-(NSArray *)musicList
{
    if (!_musicList)
    {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"songsOnline" ofType:@"plist"];
        _musicList = [MusicModel objectArrayWithFile:path];
    }
    return _musicList;
}


-(void)prepareToPlayWithMusic:(MusicModel *)music {
    [self.avPlayer pause];
    [self.player pause];
    if ([music.fileName hasPrefix:@"http"]) {
        NSURL *musicUrl = [NSURL URLWithString:music.fileName];
        
        NSString *document = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject;
        NSString *fileName = [ZAAudioLoader stringEncodingWithMd5:music.fileName];
        
        NSString *cacheFilePath = [[document stringByAppendingPathComponent:fileName] stringByAppendingPathExtension:[musicUrl pathExtension]];

        BOOL isCacheFileExist = [[NSFileManager defaultManager] fileExistsAtPath:cacheFilePath];
        if (isCacheFileExist) {
            //准备播放音乐
            self.audioAsset = [AVURLAsset URLAssetWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"file:/\/\/%@",cacheFilePath]] options:nil];
            self.avplayerItem = [AVPlayerItem playerItemWithAsset:self.audioAsset];
            if (!self.avPlayer) {
                self.avPlayer = [AVPlayer playerWithPlayerItem:self.avplayerItem];
            } else {
                [self.avPlayer replaceCurrentItemWithPlayerItem:self.avplayerItem];
            }
            return;
        }
        self.audioLoader = [[ZAAudioLoader alloc] initWithCacheFilePath:cacheFilePath];
        NSURL *playUrl = [self.audioLoader getSchemeAudioURL:musicUrl];
        self.audioURLAsset = [AVURLAsset URLAssetWithURL:playUrl options:nil];
        [self.audioURLAsset.resourceLoader setDelegate:self.audioLoader queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
        self.avplayerItem = [AVPlayerItem playerItemWithAsset:self.audioURLAsset];
        if (!self.avPlayer) {
            self.avPlayer = [AVPlayer playerWithPlayerItem:self.avplayerItem];
        } else {
            [self.avPlayer replaceCurrentItemWithPlayerItem:self.avplayerItem];
        }
        self.avPlayer.volume = 0.5;
        [self.avplayerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
        [self.avplayerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
        [self.avplayerItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
//        [self.avplayerItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];

    } else {
        NSURL *musicUrl = [[NSBundle mainBundle] URLForResource:music.fileName withExtension:nil];
        
        self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:musicUrl error:nil];
        self.player.delegate = self;
        
        //准备播放音乐
        [self.player prepareToPlay];
    }
}

-(void)playMusic
{
    [self.player play];
    [self.avPlayer play];
    self.playing = YES;
}


-(void)pauseMusic
{
    [self.player pause];
    [self.avPlayer pause];
    self.playing = NO;
}

-(void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    if (flag)
    {
        NSNotification *notification =[NSNotification notificationWithName:@"SendFinishMusicInfo" object:nil userInfo:nil];
        [[NSNotificationCenter defaultCenter] postNotification:notification];
    }
}


//监听回调
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    AVPlayerItem *playerItem = (AVPlayerItem *)object;
    
    if ([keyPath isEqualToString:@"status"]) {
        if ([playerItem status] == AVPlayerStatusReadyToPlay) {
            [self monitoringPlayback:playerItem];// 给播放器添加计时器
            
        } else if ([playerItem status] == AVPlayerStatusFailed || [playerItem status] == AVPlayerStatusUnknown) {
            [self.avPlayer pause];
        }
        
    } else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {  //监听播放器的下载进度
        
        [self calculateDownloadProgress:playerItem];
        
    } else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) { //监听播放器在缓冲数据的状态
        if (playerItem.isPlaybackBufferEmpty) {
//            self.state = TBPlayerStateBuffering;
            [self bufferingSomeSecond];
        }
    }
}
// 监听播放进度
- (void)monitoringPlayback:(AVPlayerItem *)playerItem {
    [self.avPlayer play];
    __weak typeof(self) weakSelf = self;
    [weakSelf.avPlayer addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:NULL usingBlock:^(CMTime time) {
        CGFloat currentSecond = playerItem.currentTime.value/playerItem.currentTime.timescale;// 计算当前在第几秒
        CGFloat totalSecond = playerItem.duration.value/playerItem.duration.timescale;
        NSLog(@"currentSecond = %.4f \n totalSecond = %.4f",currentSecond ,totalSecond);
    }];
}

- (void)bufferingSomeSecond
{
    // playbackBufferEmpty会反复进入，因此在bufferingOneSecond延时播放执行完之前再调用bufferingSomeSecond都忽略
    static BOOL isBuffering = NO;
    if (isBuffering) {
        return;
    }
    isBuffering = YES;
    
    // 需要先暂停一小会之后再播放，否则网络状况不好的时候时间在走，声音播放不出来
    [self.player pause];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // 如果此时用户已经暂停了，则不再需要开启播放了
        [self.player play];
        // 如果执行了play还是没有播放则说明还没有缓存好，则再次缓存一段时间
//        isBuffering = NO;
//        if (!self.avplayerItem.isPlaybackLikelyToKeepUp) {
//            [self bufferingSomeSecond];
//        }
    });
}

- (void)calculateDownloadProgress:(AVPlayerItem *)playerItem
{
    NSArray *loadedTimeRanges = [playerItem loadedTimeRanges];
    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];// 获取缓冲区域
    float startSeconds = CMTimeGetSeconds(timeRange.start);
    float durationSeconds = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval timeInterval = startSeconds + durationSeconds;// 计算缓冲总进度
    CMTime duration = playerItem.duration;
    CGFloat totalDuration = CMTimeGetSeconds(duration);
    self.loadedProgress = timeInterval / totalDuration;
    NSLog(@"loadProgress = %.3f",self.loadedProgress);
}

- (void)setLoadedProgress:(CGFloat)loadedProgress
{
    if (_loadedProgress == loadedProgress) {
        return;
    }
    
    _loadedProgress = loadedProgress;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"TBPlayerLoadProgressChangedNotification" object:nil];
}

@end
