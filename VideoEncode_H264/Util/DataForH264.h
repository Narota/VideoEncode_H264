//
//  DataForH264.h
//  VideoEncode_H264
//
//  Created by ZJ on 2018/12/26.
//  Copyright © 2018年 macdev. All rights reserved.
//

#import <Foundation/Foundation.h>
@import CoreMedia ;

NS_ASSUME_NONNULL_BEGIN

@interface DataForH264 : NSObject

-(NSData *)createDataWith:(CMSampleBufferRef)sample ;
-(CMSampleBufferRef)createSampleBufferWith:(NSData *)data ;


@end

NS_ASSUME_NONNULL_END
