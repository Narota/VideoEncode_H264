//
//  Writer_H264.m
//  VideoEncode_H264
//
//  Created by ZJ on 2018/12/6.
//  Copyright © 2018年 macdev. All rights reserved.
//

#import "FileWriter_H264.h"
#import <objc/runtime.h>


@interface NSObject (PropertyValue)

-(void)setPropertyWith:(NSObject *)obj;

@end


@interface FileWriter_H264 ()

@property (strong,nonatomic) AVAssetWriter * writer ;
@property (strong,nonatomic) AVAssetWriterInput * audioInput ;
@property (strong,nonatomic) AVAssetWriterInput * videoInput ;

@property (strong,nonatomic) NSString * filePath ;
@property (assign,nonatomic) CGSize  videoSize ;
@property (assign,nonatomic) BOOL  enableAudio ;
@property (assign,nonatomic) BOOL  videoBufferIsCompressed ;
@property (strong,nonatomic) FileWriterConfiguration * configuration ;

@property (assign,nonatomic) BOOL  ready ;

@end


@implementation FileWriter_H264
{
    NSURL *_fileUrl;
    dispatch_queue_t _writerQueue;
    
    NSInteger _configStatus ;
    BOOL _isStartSession ;
    CMTime _lastTime ;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _writerQueue = dispatch_queue_create("write file queue", NULL) ;
        _lastTime = kCMTimeInvalid ;
    }
    return self;
}

-(BOOL)configWriterWith:(FileWriterConfiguration *)configure
{
    self.configuration = configure ;
    [self setPropertyWith:configure];
    return [self configWriter] ;
}

-(BOOL)configWriter
{
    NSAssert(_configStatus == 0, @"Has started") ;
    
    NSAssert(self.filePath != nil, @"filePath to save is null") ;
    NSAssert(self.videoSize.width != 0 && self.videoSize.height != 0, @"size error") ;
    
    [self createWriter] ;
    [self addVideo] ;
    if (self.enableAudio) {
        [self addAudio] ;
    }
    _configStatus += 1 ;
    return YES;
}

-(BOOL)createWriter
{
    _fileUrl = [NSURL fileURLWithPath:self.filePath];
    _writer = [[AVAssetWriter alloc] initWithURL:_fileUrl fileType:AVFileTypeMPEG4 error:nil];
    return _writer != nil ;
}

-(BOOL)addVideo
{
    CMFormatDescriptionRef videoFormat = nil;
    NSDictionary *videSettings = nil ;
    CMVideoFormatDescriptionCreate(kCFAllocatorDefault,
                                   kCMVideoCodecType_H264,
                                   self.videoSize.width,
                                   self.videoSize.height,
                                   NULL,
                                   &videoFormat);
    
    if (self.videoBufferIsCompressed == NO) {
        videSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                        AVVideoCodecH264,AVVideoCodecKey,
                        [NSNumber numberWithInt:self.videoSize.width],AVVideoWidthKey,
                        [NSNumber numberWithInt:self.videoSize.height],AVVideoHeightKey,
                        nil];
    }
    
    _videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                     outputSettings:videSettings
                                                   sourceFormatHint:videoFormat];
    
    CFRelease(videoFormat) ;
    
    if ([_writer canAddInput:_videoInput]) {
        [_writer addInput:_videoInput];
        _videoInput.expectsMediaDataInRealTime = NO;
        _videoInput.performsMultiPassEncodingIfSupported = YES;
    }
    else
    {
        NSLog(@"video Writer 添加失败");
        return NO;
    }
    return YES ;
}

-(BOOL)addAudio
{
    NSDictionary *audioSettings = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kAudioFormatMPEG4AAC],AVFormatIDKey,[NSNumber numberWithInt:48000],AVSampleRateKey,[NSNumber numberWithInt:1],AVNumberOfChannelsKey,nil];
    _audioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioSettings];
    
    if ([_writer canAddInput:_audioInput]) {
        [_writer addInput:_audioInput];
        _audioInput.expectsMediaDataInRealTime = YES;
        _audioInput.performsMultiPassEncodingIfSupported = YES;
    }
    else
    {
        NSLog(@"audio Writer 添加失败");
        return NO;
    }
    return YES ;
}

-(BOOL)isReady
{
    return _ready && _writer.status == AVAssetWriterStatusWriting ;
}

-(void)startSessionWithBuffer:(CMSampleBufferRef)buffer
{
    if (_isStartSession) {
        NSLog(@"session has been started") ;
        return ;
    }
    _isStartSession = YES ;
    if (_writer.status != AVAssetWriterStatusUnknown || ![_writer startWriting])
    {
        NSLog(@"开启失败");
        return ;
    }
    
    CMTime time = CMSampleBufferGetPresentationTimeStamp(buffer) ;
    [self startSessionWith:time];
    [self writeVideoBuffer:buffer];
}

-(void)startSessionWith:(CMTime)time
{
    _configStatus += 1 ;
    [_writer startSessionAtSourceTime:time];
    _ready = _configStatus == 2 ;
}

-(void)finishSession:(void (^)(NSString *filePath))block
{
    __weak typeof(self) weakSelf = self ;
    if (_writer.status == AVAssetWriterStatusWriting) {
        [_writer finishWritingWithCompletionHandler:^{
            if (block) {
                block(weakSelf.filePath) ;
            }
        }];
    }else{
        if (block) {
            block(nil) ;
        }
    }
}

-(void)writeVideoBuffer:(CMSampleBufferRef)buffer
{
    if (_ready == NO ) {
        NSLog(@"not ready") ;
        return ;
    }

    if (buffer == NULL) {
        NSLog(@"buffer NULL") ;
        return ;
    }
    
    CFRetain(buffer) ;
    dispatch_async(_writerQueue, ^{
        NSLog(@"buffer start") ;
        if (self.writer.status == AVAssetWriterStatusWriting && self.videoInput.readyForMoreMediaData) {
            CMTime currentTime = CMSampleBufferGetPresentationTimeStamp(buffer) ;
            if (CMTimeCompare(self->_lastTime, kCMTimeInvalid) == 0) {
                self->_lastTime = currentTime ;
            }else
            if (CMTimeCompare(self->_lastTime, currentTime) != -1 ) {
                return ;
            }
            
            BOOL suc = [self.videoInput appendSampleBuffer:buffer];
            NSLog(@"buffer write:%@",suc?@"suc":@"fail") ;
            self->_lastTime = currentTime ;
        }else{
            NSLog(@"lost buffer");
        }
        CFRelease(buffer) ;
    });
}

-(void)writeAudioBuffer:(CMSampleBufferRef)buffer
{
    NSAssert(self.enableAudio, @"audio not enable");
    
    if (_ready == NO ) {
        NSLog(@"not ready") ;
        return ;
    }
    if (buffer == NULL) {
        NSLog(@"buffer NULL") ;
        return ;
    }
    CFRetain(buffer) ;
    dispatch_async(_writerQueue, ^{
        if (self.writer.status == AVAssetWriterStatusWriting && self.audioInput.readyForMoreMediaData) {
            [self.audioInput appendSampleBuffer:buffer];
        }else{
            NSLog(@"lost buffer");
        }
        CFRelease(buffer) ;
    }) ;
}

@end

@implementation FileWriterConfiguration

@end


@implementation NSObject (PropertyValue)

-(void)setPropertyWith:(NSObject *)obj
{
    unsigned int count ;
    objc_property_t *proptyList = class_copyPropertyList([obj class], &count) ;
    for (int i = 0 ; i < count; i++) {
        objc_property_t property = proptyList[i] ;
        NSString *name = @(property_getName(property)) ;
        id value = [obj valueForKey:name];
        [self setValue:value forKey:name];
    }
    free(proptyList) ;
}

@end

