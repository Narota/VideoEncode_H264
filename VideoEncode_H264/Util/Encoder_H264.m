//
//  EncoderForH264.m
//  VideoEncode_H264
//
//  Created by ZJ on 2018/12/5.
//  Copyright © 2018年 macdev. All rights reserved.
//

#import "Encoder_H264.h"
#import <AVFoundation/AVFoundation.h>

@interface Encoder_H264 ()

@property (strong,nonatomic) NSMutableArray * muArrInfos ;

@end


@implementation Encoder_H264

{
    VTCompressionSessionRef _session;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _muArrInfos = [NSMutableArray array] ;
        _videoSize = CGSizeMake(1920, 1080) ;
        _fps = 30 ;
        _bt = 1024 * 1024 * 8 ;
    }
    return self;
}

-(void)configSession
{
    CGSize outputSize = self.videoSize ;
    
    OSStatus status = VTCompressionSessionCreate(kCFAllocatorDefault,
                                                 outputSize.width ,
                                                 outputSize.height,
                                                 kCMVideoCodecType_H264,
                                                 NULL, NULL, NULL,
                                                 didCompressBuffer,
                                                 (__bridge void *)(self), &_session);
    
    VTCompressionSessionRef session = _session ;

    if (status != noErr) {NSLog(@"encoder fail") ; return ;} ;
    
        int fps = (int) self.fps ;
        int bt = (int) self.bt;
        // 设置编码码率(比特率)，如果不设置，默认将会以很低的码率编码，导致编码出来的视频很模糊
        status  = VTSessionSetProperty(session, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(bt)); // bps
        status += VTSessionSetProperty(session, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)@[@(bt*2/8), @1]); // Bps
        NSLog(@"set bitrate   return: %d", (int)status);
        
        CFNumberRef ref = CFNumberCreate(NULL, kCFNumberSInt32Type, &fps);
        VTSessionSetProperty(session, kVTCompressionPropertyKey_ExpectedFrameRate, ref);
        CFRelease(ref);
        
        VTSessionSetProperty(session, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        VTSessionSetProperty(session, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
        
        status = VTCompressionSessionPrepareToEncodeFrames(session);
        NSLog(@"encoder success") ;
}

-(void)encode:(CMSampleBufferRef)buffer info:(NSString *)info
{
    NSAssert(_session != NULL, @"no session") ;
    
    if (info == nil) {
        info = @"" ;
    }

    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(buffer) ;
    CMTime time = CMSampleBufferGetPresentationTimeStamp(buffer) ;
    
    NSArray *arr = @[[NSValue valueWithCMTime:time],info] ;
    [self.muArrInfos addObject:arr] ;
    CFArrayRef arrayRef = (__bridge CFArrayRef)(arr) ;
    
    VTEncodeInfoFlags flags;
    OSStatus status = VTCompressionSessionEncodeFrame(_session,
                                                      imageBuffer,
                                                      time,
                                                      kCMTimeInvalid,
                                                      NULL,
                                                      (void *)arrayRef,
                                                      &flags) ;
    if (status != noErr) NSLog(@"encode buffer fail");
}

-(void)releaseSession
{
    if(_session)
    {
        VTCompressionSessionCompleteFrames(_session, kCMTimeInvalid);
        VTCompressionSessionInvalidate(_session);
        CFRelease(_session);
    }
    _session = NULL ;
}

void didCompressBuffer(void *outputCallbackRefCon,
                     void *sourceFrameRefCon,
                     OSStatus status,
                     VTEncodeInfoFlags infoFlags,
                     CMSampleBufferRef sampleBuffer )
{
    CFArrayRef arrayRef = sourceFrameRefCon ;
    NSArray *arr = (__bridge NSArray *)(arrayRef) ;
    
//    CMTime time =  [[arr objectAtIndex:0] CMTimeValue] ;
    NSString *info = [arr objectAtIndex:1] ;
//    OSStatus stus = CMSampleBufferSetOutputPresentationTimeStamp(sampleBuffer, time) ;
//    NSLog(@"write timestamp :%d %lld %d ",(int)stus,time.value,time.timescale);
    
    Encoder_H264 *encoder = (__bridge Encoder_H264 *)outputCallbackRefCon;
    [encoder.muArrInfos removeObject:arr];
    NSLog(@"infos count:%ld",encoder.muArrInfos.count) ;
    if (encoder.delegate &&
        [encoder.delegate conformsToProtocol:@protocol(EncoderH264Delegate)] &&
        [encoder.delegate respondsToSelector:@selector(encodedBuffer:info:)]
        )
    {
        [encoder.delegate encodedBuffer:sampleBuffer info:info] ;
    }
}


@end
