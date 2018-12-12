//
//  ViewController.m
//  VideoEncode_H264
//
//  Created by ZJ on 2018/12/5.
//  Copyright © 2018年 macdev. All rights reserved.
//

#import "ViewController.h"
#import "MediaSession.h"
#import "Encoder_H264.h"
#import "FileWriter_H264.h"

@interface ViewController ()<MediaSessionDelegate,EncoderH264Delegate>

@property (strong,nonatomic) MediaSession * session ;
@property (strong,nonatomic) Encoder_H264 * encoder ;
@property (strong,nonatomic) FileWriter_H264 * writer_H264 ;
@property (strong,nonatomic) FileWriter_H264 * writer_oriH264 ;

@property (assign,nonatomic) BOOL  cwriter ;
@property (assign,nonatomic) BOOL  owriter ;

@property (strong,nonatomic) AVSampleBufferDisplayLayer * videoLayer ;

@property (assign,nonatomic) CGSize  videoSize ;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.videoSize = CGSizeMake(1080, 1920) ;
    NSString *filePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] ;
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:filePath error:nil] ;
    for (NSString *file in files) {
        NSString * nfile = [filePath stringByAppendingPathComponent:file];
        [[NSFileManager defaultManager] removeItemAtPath:nfile error:nil];
    }
    
    _session = [[MediaSession alloc] init];
    _session.delegate = self ;
    AVCaptureVideoPreviewLayer *previewLayer = _session.previewLayer ;
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    CGRect bounds = CGRectMake(30,30,300, 300) ;
    previewLayer.bounds=bounds;
    previewLayer.position=CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
    previewLayer.backgroundColor = [UIColor blackColor].CGColor ;
    [self.view.layer insertSublayer:previewLayer atIndex:0];
    
    _encoder = [[Encoder_H264 alloc] init];
    _encoder.videoSize = self.videoSize ;
    _encoder.delegate = self ;
    [_encoder configSession];
    
    _videoLayer = [[AVSampleBufferDisplayLayer alloc] init];
    _videoLayer.frame = CGRectMake(30, 400, 300, 300) ;
    _videoLayer.backgroundColor = [UIColor blackColor].CGColor ;
    [self.view.layer addSublayer:_videoLayer];
    
    self.cwriter = YES ;
    self.owriter = YES ;
}

-(void)dealloc
{
    [_encoder releaseSession] ;
    _encoder = nil ;
}

- (IBAction)starClicked:(id)sender {
    [self startMedia] ;
}
- (IBAction)stopClicked:(id)sender {
    [self stopMedia] ;
}

-(void)startMedia
{
    if (self.cwriter) {
        self.writer_H264 = [self newFile:@"c"] ;
    }
    if (self.owriter) {
        self.writer_oriH264 = [self newFile:@"o"] ;
    }
    
    [_session startSession];
}

-(void)stopMedia
{
    [_session stopSession];
    
    if (self.cwriter) {
        [self finishFile:self.writer_H264];
    }
    if (self.owriter) {
        [self finishFile:self.writer_oriH264];
    }
}

-(FileWriter_H264 *)newFile:(NSString *)type
{
    FileWriter_H264 *fileWriter = [[FileWriter_H264 alloc] init];
    NSString *filePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] ;
    NSDateFormatter *format = [[NSDateFormatter alloc] init] ;
    format.dateFormat = @"HHmmSS" ;
    NSString *name = [format stringFromDate:[NSDate date]] ;
    filePath = [filePath stringByAppendingFormat:@"/%@_%@.mp4",name,type];
    [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    
    FileWriterConfiguration *configure = [FileWriterConfiguration new] ;
    configure.filePath = filePath ;
    configure.videoSize = self.videoSize ;
    configure.videoBufferIsCompressed = [type isEqualToString:@"c"] ;
    configure.enableAudio = NO ;
    [fileWriter configWriterWith:configure] ;
    
    return fileWriter ;
}
-(void)finishFile:(FileWriter_H264 *)fileWriter
{
    [fileWriter finishSession:^(NSString * _Nonnull filePath) {
        NSLog(@"filePath:%@",filePath) ;
    }];
}

#pragma mark - MediaSessionDelegate

-(void)outBuffer:(CMSampleBufferRef)sampleBuffer isAudio:(BOOL)audio
{
    NSLog(@"out buffer") ;
    if (audio) {
//        [self.writer_H264 writeAudioBuffer:sampleBuffer];
//        [self.writer_oriH264 writeAudioBuffer:sampleBuffer];
    }else{
        if (self.owriter) {
            if (self.writer_oriH264.isReady) {
                NSLog(@"write code buffer") ;
                [self.writer_oriH264 writeVideoBuffer:sampleBuffer];
            }else{
                NSLog(@"start session") ;
                [self.writer_oriH264 startSessionWithBuffer:sampleBuffer];
            }
        }
        if (self.cwriter) {
            [_encoder encode:sampleBuffer info:@""];
        }
    }
}

#pragma mark - EncoderH264Delegate

-(void)encodedBuffer:(CMSampleBufferRef)buffer info:(NSString *)info
{
    if (self.writer_H264.isReady) {
        NSLog(@"write code buffer") ;
        [self.writer_H264 writeVideoBuffer:buffer];
    }else{
        NSLog(@"start session") ;
        [self.writer_H264 startSessionWithBuffer:buffer];
    }
    if (_videoLayer.readyForMoreMediaData) {
        [_videoLayer enqueueSampleBuffer:buffer];
    }
}


@end
