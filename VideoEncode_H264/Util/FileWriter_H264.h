//
//  Writer_H264.h
//  VideoEncode_H264
//
//  Created by ZJ on 2018/12/6.
//  Copyright © 2018年 macdev. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FileWriterConfiguration : NSObject

@property (strong,nonatomic) NSString * filePath ;
@property (assign,nonatomic) CGSize  videoSize ;
@property (assign,nonatomic) BOOL  enableAudio ;
@property (assign,nonatomic) BOOL  videoBufferIsCompressed ;

@end

@interface FileWriter_H264 : NSObject

@property (nonatomic , assign, readonly)BOOL isReady;
@property (strong,nonatomic,readonly) FileWriterConfiguration * configuration ;


-(BOOL)configWriterWith:(FileWriterConfiguration *)configure ;
-(void)startSessionWithBuffer:(CMSampleBufferRef)buffer ;
-(void)finishSession:(void (^)(NSString *filePath))block ;


-(void)writeVideoBuffer:(CMSampleBufferRef)buffer ;

/**
 写入音频数据
 */
-(void)writeAudioBuffer:(CMSampleBufferRef)buffer ;


@end

NS_ASSUME_NONNULL_END
