//
//  UIImageView+AFImageCache.m
//  AFTransformableImageResponseSerializer
//
//  Created by lvjg on 14-5-17.
//  Copyright (c) 2014年 lvjg. All rights reserved.
//

#import "UIImageView+AFWebImageCache.h"
#import "AFWebImageCache.h"
#import "AFTransformableImageResponseSerializer.h"
#import <objc/runtime.h>

static char operationKey;

@implementation UIImageView (AFWebImageCache)
+ (void)load
{
    [[self class] setSharedImageCache:(AFWebImageCache *)[AFWebImageCache sharedImageCache]];
}

//
- (void)af_setImageWithURL:(NSURL *)url transformImageBlock:(UIImage *(^)(UIImage *originImage))transformBlock
{
    [self af_setImageWithURL:url placeholderImage:nil transformImageBlock:transformBlock];
}

- (void)af_setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholderImage transformImageBlock:(UIImage *(^)(UIImage *originImage))transformBlock
{
    if (url) {
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];
        
        [self af_setImageWithURLRequest:request placeholderImage:placeholderImage transformImageBlock:transformBlock success:nil failure:nil];
    }
    else
    {
        self.image = placeholderImage;
    }
}

- (void)af_setImageWithURLRequest:(NSURLRequest *)urlRequest
              placeholderImage:(UIImage *)placeholderImage
           transformImageBlock:(UIImage *(^)(UIImage *originImage))transformBlock
                       success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image))success
                       failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error))failure
{
    [self cancelCurrentImageCacheLoad];
    
    self.image = placeholderImage;
    
    __weak UIImageView *weakSelf = self;
    
    AFWebImageCache *imageCache = (AFWebImageCache *)[[self class] sharedImageCache];
    
    NSString *orginKey = urlRequest.URL.absoluteString;
    NSOperation *peration = [imageCache queryImageForKey:orginKey done:^(UIImage *image, NSString *key) {
        
        if (![key isEqualToString:orginKey]) {
            return;
        }
        
        if (image) {
            
            void (^block)(void) = ^{
                
                if (success) {
                    success(nil, nil, image);
                } else {
                    weakSelf.image = image;
                }
            };
            
            if ([NSThread isMainThread]) {
                block();
            }
            else {
                dispatch_async(dispatch_get_main_queue(), block);
            }
        }
        else
        {
            AFTransformableImageResponseSerializer *serializer = [AFTransformableImageResponseSerializer serializer];
            [serializer setTransformImageCallBack:transformBlock];
            [weakSelf setImageResponseSerializer:serializer];
            
            [weakSelf setImageWithURLRequest:urlRequest placeholderImage:placeholderImage success:success failure:failure];
        }
        
    }];
    
    
    objc_setAssociatedObject(self, &operationKey, peration, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    
}


- (void)cancelCurrentImageCacheLoad {
    
    NSOperation *operation = objc_getAssociatedObject(self, &operationKey);
    if (operation) {
        [operation cancel];
        objc_setAssociatedObject(self, &operationKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    [self cancelImageRequestOperation];
}

@end
