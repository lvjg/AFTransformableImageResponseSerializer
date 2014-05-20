//
//  AFImageCache.h
//  AFTransformableImageResponseSerializer
//
//  Created by lvjg on 14-5-17.
//  Copyright (c) 2014年 lvjg. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIImageView+AFNetworking.h>

@interface AFWebImageCache : NSObject<AFImageCache>

/**
 * The maximum length of time to keep an data in the cache, in seconds
 */
@property (assign, nonatomic) NSInteger maxCacheAge;

/**
 * The maximum size of the cache, in bytes.
 */
@property (assign, nonatomic) unsigned long long maxCacheSize;

+ (AFWebImageCache *)sharedImageCache;
- (id)initWithNamespace:(NSString *)ns;

- (void)storeImage:(UIImage *)image forKey:(NSString *)key;
- (void)storeImage:(UIImage *)image forKey:(NSString *)key toDisk:(BOOL)toDisk;

- (UIImage *)imageForKey:(NSString *)key;
- (NSOperation *)queryImageForKey:(NSString *)key done:(void (^)(UIImage *image, NSString *key))doneBlock;
- (void)removeImageForKey:(NSString *)key;

- (void)clearMemory;

- (void)cleanDisk;

- (void)clearDisk;
- (void)clearDiskOnCompletion:(void (^)())completion;

@end
