//
//  UIImageView+AFWebImageCache.h
//  AFTransformableImageResponseSerializer
//
//  Created by lvjg on 14-5-17.
//  Copyright (c) 2014年 lvjg. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImageView (AFWebImageCache)

- (void)af_setImageWithURL:(NSURL *)url
       transformImageBlock:(UIImage *(^)(UIImage *originImage))transformBlock;

- (void)af_setImageWithURL:(NSURL *)url
          placeholderImage:(UIImage *)placeholderImage
       transformImageBlock:(UIImage *(^)(UIImage *originImage))transformBlock;

- (void)af_setImageWithURLRequest:(NSURLRequest *)urlRequest
              placeholderImage:(UIImage *)placeholderImage
           transformImageBlock:(UIImage *(^)(UIImage *originImage))transformBlock
                       success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image))success
                       failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error))failure;
@end
