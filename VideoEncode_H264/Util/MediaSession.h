//
//  MediaSession.h
//  VideoEncode_H264
//
//  Created by ZJ on 2018/12/5.
//  Copyright © 2018年 macdev. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MediaSessionDelegate <NSObject>
@optional

-(void)outBuffer:(CMSampleBufferRef)sampleBuffer isAudio:(BOOL)audio ;

@end



@interface MediaSession : NSObject


@property (nullable,nonatomic, strong,readonly)   AVCaptureSession            *session;
@property (nonatomic, strong,readonly)            AVCaptureVideoPreviewLayer  *previewLayer;
@property (strong, nonatomic,readonly)            AVCaptureDevice             *captureDevice;
@property (strong,nonatomic,readonly)             AVCaptureDeviceInput        *input ;
@property (nullable,strong, nonatomic,readonly)   AVCaptureVideoDataOutput    *captureVideoDataOutput;
@property (strong,nonatomic,readonly)             AVCaptureAudioDataOutput    *audioOutput ;
@property (assign,nonatomic,readonly)             BOOL                         isFrontCamera ;


@property (weak,nonatomic) NSObject<MediaSessionDelegate> * delegate ;

-(void)startSession ;
-(void)stopSession ;
-(void)changeCamera ;
-(void)changePreset:(AVCaptureSessionPreset)preset ;
-(BOOL)hasTorch ;
-(void)torchControl:(AVCaptureTorchMode)torchMode flashMode:(AVCaptureFlashMode)flashMode ;
-(void)changeCameraFocus:(CGPoint)point ;

@end

NS_ASSUME_NONNULL_END
