//
//  MusicTool.h
//  CloudMusic
//
//  Created by LiDan on 15/12/14.
//  Copyright © 2015年 com.lidan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MusicModel.h"
#import "CloudMusic.pch"
#import <AVFoundation/AVFoundation.h>
#import "Singleton.h"
#import "ZAAudioDataLoader.h"

@interface MusicTool : NSObject<AVAudioPlayerDelegate>
singleton_interface(MusicTool)

@property (nonatomic,strong) NSArray *musicList;
@property (nonatomic,assign) NSInteger playingIndex;
@property (nonatomic,strong) AVAudioPlayer* player;
@property (nonatomic,assign,getter=isPlaying) BOOL playing;

@property (nonatomic, strong) AVURLAsset     *audioURLAsset;
@property (nonatomic, strong) AVAsset        *audioAsset;

@property (nonatomic, strong) AVPlayer *avPlayer;
@property (nonatomic, strong) AVPlayerItem *avplayerItem;
@property (nonatomic, strong) ZAAudioLoader *audioLoader;

@property (nonatomic, assign) CGFloat loadedProgress;   //缓冲进度
@property (nonatomic, assign) CGFloat currentSecond;    //当前播放时长
@property (nonatomic, assign) CGFloat duration;         //播放总时长

@property (nonatomic, assign) BOOL isAvPlayer;          //是否是avplayer

/** 音乐播放前的准备工作*/
-(void)prepareToPlayWithMusic:(MusicModel *)music;

/**
 *  播放
 */
-(void)playMusic;


/**
 *  暂停
 */
-(void)pauseMusic;

- (NSString *)getAudioCachePathWithURLString:(NSString *)urlString;

- (NSString *)getAudioTempPathWithURLString:(NSString *)urlString;

@end
