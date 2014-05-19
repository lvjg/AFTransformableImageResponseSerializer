//
//  AFTransformableImageResponseSerializer.h
//  AFTransformableImageResponseSerializer
//
//  Created by lvjg on 14-5-17.
//  Copyright (c) 2014年 lvjg. All rights reserved.
//

#import "AFURLResponseSerialization.h"

typedef UIImage *(^AFTransformImageBlock)(UIImage *originImage);

@interface AFTransformableImageResponseSerializer : AFImageResponseSerializer

- (void)setTransformImageCallBack:(AFTransformImageBlock)transformImageBlock;



@end
