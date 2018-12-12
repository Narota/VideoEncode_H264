//
//  MediaSession.m
//  VideoEncode_H264
//
//  Created by ZJ on 2018/12/5.
//  Copyright © 2018年 macdev. All rights reserved.
//

#import "MediaSession.h"

@interface MediaSession ()<
AVCaptureVideoDataOutputSampleBufferDelegate,
AVCaptureAudioDataOutputSampleBufferDelegate
>

@property (nullable,nonatomic, strong)   AVCaptureSession            *session;
@property (nonatomic, strong)            AVCaptureVideoPreviewLayer  *previewLayer;
@property (strong,nonatomic)             AVCaptureDeviceInput        *input ;
@property (nullable,strong, nonatomic)   AVCaptureVideoDataOutput    *captureVideoDataOutput;
@property (strong,nonatomic)             AVCaptureAudioDataOutput    *audioOutput ;
@property (assign,nonatomic)             BOOL                         isFrontCamera ;


@end

@implementation MediaSession


#pragma mark - 初始化

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self configMedia];
    }
    return self;
}

-(void)dealloc
{
    self.session = nil ;
}

-(void)configMedia
{
    [self configSession] ;
    [self configVideoOutput];
    [self configAudioOut] ;
}

-(void)configSession
{
    if (_session) {
        [_session stopRunning];
        _session = nil ;
    }
    self.session = [[AVCaptureSession alloc] init];
    
    NSError *error = nil;
    if (self.input == nil) {
        AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo] error:&error];
        self.input = input ;
    }
    
    if ([self isDisableCaptureDeviceInput:self.input]) return ;
    
    if ([self.session canAddInput:self.input]) {
        [self.session addInput:self.input];
    }
    
    if (self.previewLayer == nil) {
        self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    }else{
        self.previewLayer.session = self.session ;
    }
}

-(void)configVideoOutput
{
    if ([self isDisableCaptureDeviceInput:self.input]) return ;
    
    if (self.captureVideoDataOutput) {
        [self.session removeOutput:self.captureVideoDataOutput];
        self.captureVideoDataOutput = nil ;
    }
    dispatch_queue_t queue = dispatch_queue_create("myEncoderH264Queue", NULL);
    _captureVideoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [_captureVideoDataOutput setSampleBufferDelegate:self queue:queue];
    NSDictionary *settings = [[NSDictionary alloc] initWithObjectsAndKeys:
                              [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],
                              kCVPixelBufferPixelFormatTypeKey,
                              nil]; // X264_CSP_NV12
    _captureVideoDataOutput.videoSettings = settings;
    _captureVideoDataOutput.alwaysDiscardsLateVideoFrames = YES;
    if ([self.session canAddOutput:_captureVideoDataOutput]) {
        [self.session addOutput:_captureVideoDataOutput];
    }
    AVCaptureConnection * connection = [_captureVideoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    connection.videoOrientation = AVCaptureVideoOrientationPortrait ;
}

-(void)configAudioOut
{
    NSError *error = nil;
    // 配置采集输出，即我们取得音频的接口
    AVCaptureDeviceInput *microphone = [AVCaptureDeviceInput  deviceInputWithDevice:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio]  error:&error];
    
    if (!microphone) {
        NSLog(@"ERROR: input audio: %@", error);
        return;
    }
    
    if ([self.session canAddInput:microphone]) {
        [self.session addInput:microphone];
    }
    
    AVCaptureAudioDataOutput *audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    dispatch_queue_t audioQueue = dispatch_queue_create("Audio Capture Queue", DISPATCH_QUEUE_SERIAL);
    [audioOutput setSampleBufferDelegate:self queue:audioQueue];
    self.audioOutput = audioOutput ;
    if ([self.session canAddOutput:audioOutput]) {
        [self.session addOutput:audioOutput];
    }
}

-(void)startSession
{
    [self audioSessionCategrory:AVAudioSessionCategoryRecord];
    [self.session startRunning];
}

-(void)stopSession
{
    if (self.session) {
        [self.session stopRunning] ;
    }
    [self audioSessionCategrory:AVAudioSessionCategorySoloAmbient] ;
}

-(void)changePreset:(AVCaptureSessionPreset)preset
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self.session beginConfiguration];
        self.session.sessionPreset = preset;
        [self.session commitConfiguration];
    });
}

#pragma mark - 聚焦

-(void)changeCameraFocus:(CGPoint)point
{
    CGPoint cameraPoint= [self.previewLayer captureDevicePointOfInterestForPoint:point];
    [self changeDevice:self.captureDevice session:self.session focusTo:cameraPoint] ;
}

-(void)changeDevice:(AVCaptureDevice *)device session:(AVCaptureSession *)session  focusTo:(CGPoint)cameraPoint
{
    // cameraPoint 触摸屏幕的坐标点需要转换成0-1，设置聚焦点
    if (cameraPoint.x < 0 || cameraPoint.x > 1 || cameraPoint.y < 0 || cameraPoint.x > 1) {
        NSLog(@"聚焦点错误") ;
        return ;
    }
    
    NSError * error ;
    [device lockForConfiguration:&error];
    if (error) {
        NSLog(@"聚焦失败");
    }else{
        [session beginConfiguration];
        device.subjectAreaChangeMonitoringEnabled = YES ;
        
        /*****必须先设定聚焦位置，在设定聚焦方式******/
        //聚焦点的位置
        if ([device isFocusPointOfInterestSupported]) {
            [device setFocusPointOfInterest:cameraPoint];
        }
        
        // 聚焦模式
        if ([device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
            [device setFocusMode:AVCaptureFocusModeAutoFocus];
        }else{
            NSLog(@"聚焦模式修改失败");
        }
        
        //曝光点的位置
        if ([device isExposurePointOfInterestSupported]) {
            [device setExposurePointOfInterest:cameraPoint];
        }
        
        //曝光模式
        //        if ([self.captureDevice isExposureModeSupported:AVCaptureExposureModeAutoExpose]) {
        //            [self.captureDevice setExposureMode:AVCaptureExposureModeAutoExpose];
        //        }else{
        //            NSLog(@"曝光模式修改失败");
        //        }
        [device unlockForConfiguration];
        [session commitConfiguration];
    }
}

#pragma mark - Torch

-(void)torchControl:(AVCaptureTorchMode)torchMode flashMode:(AVCaptureFlashMode)flashMode
{
    [self.captureDevice lockForConfiguration:nil] ;
    if ([self.captureDevice hasTorch]) {
        self.captureDevice.torchMode = torchMode ;
    }
    if ([self.captureDevice isFlashModeSupported:flashMode]) {
        self.captureDevice.flashMode = flashMode ;
    }
    [self.captureDevice unlockForConfiguration];
}

-(BOOL)hasTorch
{
    return [self.captureDevice hasTorch] ;
}

#pragma mark - 切换摄像头

- (void)changeCamera{
    NSUInteger cameraCount = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count];
    if (cameraCount > 1) {
        NSError *error;
        //给摄像头的切换添加翻转动画
        
        AVCaptureDevice *newCamera = nil;
        AVCaptureDeviceInput *newInput = nil;
        //拿到另外一个摄像头位置
        AVCaptureDevicePosition position = [[self.input device] position];
        if (position == AVCaptureDevicePositionFront){
            newCamera = [self cameraWithPosition:AVCaptureDevicePositionBack];
            [self changCameraAnimation:kCATransitionFromLeft] ;
            self.isFrontCamera = NO ;
        }
        else {
            newCamera = [self cameraWithPosition:AVCaptureDevicePositionFront];
            [self changCameraAnimation:kCATransitionFromRight] ;
            self.isFrontCamera = YES ;
        }
        //生成新的输入
        newInput = [AVCaptureDeviceInput deviceInputWithDevice:newCamera error:nil];
        if (newInput != nil) {
            [self.session beginConfiguration] ;
            [self.session removeInput:self.input];
            self.input = newInput;
            [self.session addInput:self.input];
            [self.session commitConfiguration];
        } else if (error) {
            NSLog(@"toggle carema failed, error = %@", error);
        }
    }
}

-(void)changCameraAnimation:(CATransitionSubtype)subtype
{
    CATransition *animation = [CATransition animation];
    animation.duration = .5f;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.type = @"oglFlip";
    animation.subtype = subtype ;
    [self.previewLayer addAnimation:animation forKey:nil];
}

- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for ( AVCaptureDevice *device in devices )
        if ( device.position == position ){
            return device;
        }
    return nil;
}

#pragma mark - utils

-(BOOL)isDisableCaptureDeviceInput:(AVCaptureDeviceInput *)input
{
    BOOL enable = input != nil ;
    NSAssert(enable, @"device input disable");
    return !enable ;
}

-(void)audioSessionCategrory:(NSString *)category
{
    NSError *audioerror = nil;
    [[AVAudioSession sharedInstance] setCategory:category error:&audioerror];
    if(!audioerror) {
        [[AVAudioSession sharedInstance] setActive:YES error:&audioerror];
        if(audioerror) {
            NSLog(@"Error while activating AudioSession : %@", audioerror);
        }
    } else {
        NSLog(@"Error while setting category of AudioSession : %@", audioerror);
    }
}

-(AVCaptureDevice *)captureDevice
{
    return self.input.device ;
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    BOOL isAudio = [captureOutput isKindOfClass:[AVCaptureAudioDataOutput class]] ;
    if (self.delegate &&
        [self.delegate conformsToProtocol:@protocol(MediaSessionDelegate)] &&
        [self.delegate respondsToSelector:@selector(outBuffer:isAudio:)]
        )
    {
        [self.delegate outBuffer:sampleBuffer isAudio:isAudio] ;
    }
}


@end
