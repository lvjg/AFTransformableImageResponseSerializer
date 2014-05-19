//
//  AFTransformableImageResponseSerializer.m
//  AFTransformableImageResponseSerializer
//
//  Created by lvjg on 14-5-17.
//  Copyright (c) 2014年 lvjg. All rights reserved.
//

#import "AFTransformableImageResponseSerializer.h"

@interface AFTransformableImageResponseSerializer()

@property(nonatomic, copy)AFTransformImageBlock transformImageBlock;

@end

@implementation AFTransformableImageResponseSerializer

#pragma mark - AFURLResponseSerializer

- (id)responseObjectForResponse:(NSURLResponse *)response
                           data:(NSData *)data
                          error:(NSError *__autoreleasing *)error
{
    id responseObject = [super responseObjectForResponse:response data:data error:error];
    if (!responseObject) {
        return nil;
    }
    
    if (self.transformImageBlock) {
        
        return self.transformImageBlock(responseObject);
    }
    return responseObject;
}

- (void)setTransformImageCallBack:(AFTransformImageBlock)transformImageBlock
{
    self.transformImageBlock = transformImageBlock;
}

@end
