//
//  AFWebImageCache.m
//  AFTransformableImageResponseSerializer
//
//  Created by lvjg on 14-5-17.
//  Copyright (c) 2014年 lvjg. All rights reserved.
//

#import "AFWebImageCache.h"
#import <CommonCrypto/CommonDigest.h>
@import ImageIO;

#pragma mark - Helper
static NSString *AFMD5Digest(NSString *string)
{
    if(string == nil || [string length] == 0)
        return nil;
    
    const char *cStr = [string UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5( cStr, (unsigned int) strlen(cStr), result);
    return [[NSString alloc] initWithFormat:
			@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
			result[0], result[1], result[2], result[3],
			result[4], result[5], result[6], result[7],
			result[8], result[9], result[10], result[11],
			result[12], result[13], result[14], result[15]
			];
}

#pragma mark -
static UIImage *AFDecompressedImageWithCGImage(CGImageRef imageRef)
{
    const CGBitmapInfo originalBitmapInfo = CGImageGetBitmapInfo(imageRef);
    
    // See: http://stackoverflow.com/questions/23723564/which-cgimagealphainfo-should-we-use
    const uint32_t alphaInfo = (originalBitmapInfo & kCGBitmapAlphaInfoMask);
    CGBitmapInfo bitmapInfo = originalBitmapInfo;
    switch (alphaInfo)
    {
        case kCGImageAlphaNone:
            bitmapInfo &= ~kCGBitmapAlphaInfoMask;
            bitmapInfo |= kCGImageAlphaNoneSkipFirst;
            break;
        case kCGImageAlphaPremultipliedFirst:
        case kCGImageAlphaPremultipliedLast:
        case kCGImageAlphaNoneSkipFirst:
        case kCGImageAlphaNoneSkipLast:
            break;
        case kCGImageAlphaOnly:
        case kCGImageAlphaLast:
        case kCGImageAlphaFirst:
        { // Unsupported
            return [UIImage imageWithCGImage:imageRef scale:[UIScreen mainScreen].scale orientation:UIImageOrientationUp];
        }
            break;
    }
    
    const CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    const CGSize imageSize = CGSizeMake(CGImageGetWidth(imageRef), CGImageGetHeight(imageRef));
    const CGContextRef context = CGBitmapContextCreate(NULL,
                                                       imageSize.width,
                                                       imageSize.height,
                                                       CGImageGetBitsPerComponent(imageRef),
                                                       0,
                                                       colorSpace,
                                                       bitmapInfo);
    CGColorSpaceRelease(colorSpace);
    
    UIImage *image;
    const CGFloat scale = [UIScreen mainScreen].scale;
    if (context)
    {
        const CGRect imageRect = CGRectMake(0, 0, imageSize.width, imageSize.height);
        CGContextDrawImage(context, imageRect, imageRef);
        const CGImageRef decompressedImageRef = CGBitmapContextCreateImage(context);
        CGContextRelease(context);
        image = [UIImage imageWithCGImage:decompressedImageRef scale:scale orientation:UIImageOrientationUp];
        CGImageRelease(decompressedImageRef);
    }
    else
    {
        image = [UIImage imageWithCGImage:imageRef scale:scale orientation:UIImageOrientationUp];
    }
    return image;
}

static UIImage *AFDecompressedImageWithData(NSData *imageData)
{
    const CGImageSourceRef sourceRef = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
    
    // Ideally we would simply use kCGImageSourceShouldCacheImmediately but as of iOS 7.1 it locks on copyImageBlockSetJPEG which makes it dangerous.
    // CGImageRef imageRef = CGImageSourceCreateImageAtIndex(source, 0, (__bridge CFDictionaryRef)@{(id)kCGImageSourceShouldCacheImmediately: @YES});
    
    UIImage *image = nil;
    const CGImageRef imageRef = CGImageSourceCreateImageAtIndex(sourceRef, 0, NULL);
    if (imageRef)
    {
        image = AFDecompressedImageWithCGImage(imageRef);
        CGImageRelease(imageRef);
    }
    CFRelease(sourceRef);
    
    return image;
}

static BOOL AFImageHasAlpha(UIImage *image)
{
    const CGImageAlphaInfo alpha = CGImageGetAlphaInfo(image.CGImage);
    return (alpha == kCGImageAlphaFirst ||
            alpha == kCGImageAlphaLast ||
            alpha == kCGImageAlphaPremultipliedFirst ||
            alpha == kCGImageAlphaPremultipliedLast);
}



static const NSInteger kDefaultCacheMaxCacheAge = 60 * 60 * 24 * 7; // 1 week

@interface AFWebImageCache()
@property (nonatomic, strong) NSCache* memCache;
@property (nonatomic, strong) NSString *diskCachePath;
@property (nonatomic, strong) dispatch_queue_t ioQueue;
@end

@implementation AFWebImageCache
{
    NSFileManager *_fileManager;
}

+ (AFWebImageCache *)sharedImageCache
{
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{instance = self.new;});
    return instance;
}

- (id)init {
    return [self initWithNamespace:@"default"];
}

- (id)initWithNamespace:(NSString *)ns
{
    if ((self = [super init]))
    {
        NSString *fullNamespace = [@"AFWebImageCache." stringByAppendingString:ns];
        
        // Init default values
        _maxCacheAge = kDefaultCacheMaxCacheAge;
        
        // Init the memory cache
        self.memCache = [[NSCache alloc] init];
        _memCache.name = fullNamespace;
        
        // Create IO serial queue
        _ioQueue = dispatch_queue_create("AFWebImageCache", DISPATCH_QUEUE_SERIAL);
        
        // Init the disk cache
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        _diskCachePath = [[paths firstObject] stringByAppendingPathComponent:fullNamespace];
        
        dispatch_sync(_ioQueue, ^{
            _fileManager = [NSFileManager new];
        });
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clearMemory)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(cleanDisk)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];
        
    }
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -ImageCache
- (void)storeImage:(UIImage *)image forKey:(NSString *)key
{
    [self storeImage:image forKey:key toDisk:YES];
}

- (void)storeImage:(UIImage *)image forKey:(NSString *)key toDisk:(BOOL)toDisk
{
    if (!image || !key) {
        return;
    }
    
    [self.memCache setObject:image forKey:key cost:image.size.height * image.size.width * image.scale];
    
    if (toDisk) {
        dispatch_async(self.ioQueue, ^{
            
            // Can't use defaultManager another thread
            
            if (![_fileManager fileExistsAtPath:_diskCachePath])
            {
                [_fileManager createDirectoryAtPath:_diskCachePath withIntermediateDirectories:YES attributes:nil error:NULL];
            }
            
            [_fileManager createFileAtPath:[self defaultCachePathForKey:key] contents:AFImageHasAlpha(image) ? UIImagePNGRepresentation(image) : UIImageJPEGRepresentation(image, 1.0) attributes:nil];
            
        });
    }
}

- (UIImage *)imageForKey:(NSString *)key
{
    UIImage *image = [self imageFromMemoryCacheForKey:key];
    if (image) {
        return image;
    }
    
    // Second check the disk cache...
    UIImage *diskImage = [self imageFromDiskCacheForKey:key];
    if (diskImage) {
        CGFloat cost = diskImage.size.height * diskImage.size.width * diskImage.scale;
        [self.memCache setObject:diskImage forKey:key cost:cost];
    }
    
    return diskImage;
}

- (NSOperation *)queryImageForKey:(NSString *)key done:(void (^)(UIImage *image, NSString *key))doneBlock
{
    NSOperation *operation = [NSOperation new];
    
    if (!doneBlock) return nil;
    
    if (!key) {
        doneBlock(nil, key);
        return nil;
    }
    
    // First check the in-memory cache...
    UIImage *image = [self imageFromMemoryCacheForKey:key];
    if (image) {
        doneBlock(image, key);
        return nil;
    }
    
    dispatch_async(self.ioQueue, ^{
        if (operation.isCancelled) {
            return;
        }
        
        @autoreleasepool {
            UIImage *diskImage = [self imageFromDiskCacheForKey:key];
            if (diskImage) {
                CGFloat cost = diskImage.size.height * diskImage.size.width * diskImage.scale;
                [self.memCache setObject:diskImage forKey:key cost:cost];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                doneBlock(diskImage, key);
            });
        }
    });
    
    return operation;

}

- (void)removeImageForKey:(NSString *)key
{
    if (key == nil) {
        return;
    }
    
    [self.memCache removeObjectForKey:key];
    
    dispatch_async(self.ioQueue, ^{
        [_fileManager removeItemAtPath:[self defaultCachePathForKey:key] error:nil];
    });
}

- (void)clearMemory
{
    [self.memCache removeAllObjects];
}

- (void)clearDisk
{
    [self clearDiskOnCompletion:nil];
}

- (void)clearDiskOnCompletion:(void (^)())completion
{
    dispatch_async(self.ioQueue, ^{
        [_fileManager removeItemAtPath:self.diskCachePath error:nil];
        [_fileManager createDirectoryAtPath:self.diskCachePath
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:NULL];
        
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion();
            });
        }

    });
}


- (void)cleanDisk
{
    dispatch_async(self.ioQueue, ^
                   {
                       NSURL *diskCacheURL = [NSURL fileURLWithPath:self.diskCachePath isDirectory:YES];
                       NSArray *resourceKeys = @[ NSURLIsDirectoryKey, NSURLContentAccessDateKey, NSURLTotalFileAllocatedSizeKey ];
                       
                       // This enumerator prefetches useful properties for our cache files.
                       NSDirectoryEnumerator *fileEnumerator = [_fileManager enumeratorAtURL:diskCacheURL
                                                                 includingPropertiesForKeys:resourceKeys
                                                                                    options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                               errorHandler:NULL];
                       
                       NSDate *expirationDate = [NSDate dateWithTimeIntervalSinceNow:-self.maxCacheAge];
                       NSMutableDictionary *cacheFiles = [NSMutableDictionary dictionary];
                       unsigned long long currentCacheSize = 0;
                       
                       // Enumerate all of the files in the cache directory.  This loop has two purposes:
                       //
                       //  1. Removing files that are older than the expiration date.
                       //  2. Storing file attributes for the size-based cleanup pass.
                       for (NSURL *fileURL in fileEnumerator)
                       {
                           NSDictionary *resourceValues = [fileURL resourceValuesForKeys:resourceKeys error:NULL];
                           
                           // Skip directories.
                           if ([resourceValues[NSURLIsDirectoryKey] boolValue])
                           {
                               continue;
                           }
                           
                           // Remove files that are older than the expiration date;
                           NSDate *lastAccessDate = resourceValues[NSURLContentAccessDateKey];
                           if ([[lastAccessDate laterDate:expirationDate] isEqualToDate:expirationDate])
                           {
                               [_fileManager removeItemAtURL:fileURL error:nil];
                               continue;
                           }
                           
                           // Store a reference to this file and account for its total size.
                           NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
                           currentCacheSize += [totalAllocatedSize unsignedLongLongValue];
                           [cacheFiles setObject:resourceValues forKey:fileURL];
                       }
                       
                       // If our remaining disk cache exceeds a configured maximum size, perform a second
                       // size-based cleanup pass.  We delete the oldest files first.
                       if (self.maxCacheSize > 0 && currentCacheSize > self.maxCacheSize)
                       {
                           // Target half of our maximum cache size for this cleanup pass.
                           const unsigned long long desiredCacheSize = self.maxCacheSize / 2;
                           
                           // Sort the remaining cache files by their last Access time (oldest first).
                           NSArray *sortedFiles = [cacheFiles keysSortedByValueWithOptions:NSSortConcurrent
                                                                           usingComparator:^NSComparisonResult(id obj1, id obj2)
                                                   {
                                                       return [obj1[NSURLContentAccessDateKey] compare:obj2[NSURLContentAccessDateKey]];
                                                   }];
                           
                           // Delete files until we fall below our desired cache size.
                           for (NSURL *fileURL in sortedFiles)
                           {
                               if ([_fileManager removeItemAtURL:fileURL error:nil])
                               {
                                   NSDictionary *resourceValues = cacheFiles[fileURL];
                                   NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
                                   currentCacheSize -= [totalAllocatedSize unsignedLongLongValue];
                                   
                                   if (currentCacheSize < desiredCacheSize)
                                   {
                                       break;
                                   }
                               }
                           }
                       }
                   });

}



#pragma mark - AFImageCache
- (UIImage *)cachedImageForRequest:(NSURLRequest *)request
{
    return [self imageForKey:(request.URL.absoluteString)];
}

- (void)cacheImage:(UIImage *)image
        forRequest:(NSURLRequest *)request
{
    [self storeImage:image forKey:request.URL.absoluteString];
}

#pragma mark - Private
- (UIImage *)imageFromMemoryCacheForKey:(NSString *)key
{
    return [self.memCache objectForKey:key];
}

- (UIImage *)imageFromDiskCacheForKey:(NSString *)key
{
    NSString *defaultPath = [self defaultCachePathForKey:key];
    NSData *data = [NSData dataWithContentsOfFile:defaultPath];
    if (data) {

        UIImage *image = AFDecompressedImageWithData(data);
        
        return image;
    }
    
    return nil;
}

- (NSString *)defaultCachePathForKey:(NSString *)key
{
    NSString *filename = AFMD5Digest(key);
    return [_diskCachePath stringByAppendingPathComponent:filename];
}

@end


