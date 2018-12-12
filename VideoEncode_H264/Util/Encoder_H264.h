//
//  EncoderForH264.h
//  VideoEncode_H264
//
//  Created by ZJ on 2018/12/5.
//  Copyright © 2018年 macdev. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@protocol EncoderH264Delegate  <NSObject>

-(void)encodedBuffer:(CMSampleBufferRef)buffer info:(NSString *)info ;

@end

@interface Encoder_H264 : NSObject

@property (assign,nonatomic) CGSize  videoSize ;
@property (assign,nonatomic) NSInteger fps ;
@property (assign,nonatomic) NSInteger  bt ;
@property (weak,nonatomic) id<EncoderH264Delegate> delegate ;

-(void)configSession ;
-(void)encode:(CMSampleBufferRef)buffer info:(NSString *)info ;
-(void)releaseSession ;

@end

NS_ASSUME_NONNULL_END
