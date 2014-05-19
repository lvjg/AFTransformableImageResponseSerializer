//
//  MHViewController.m
//  AFTransformableImageResponseSerializerDemo
//
//  Created by lvjg on 14-5-19.
//  Copyright (c) 2014年 lvjg. All rights reserved.
//

#import "MHViewController.h"
#import "MHImageCollectionViewCell.h"
#import "UIImageView+AFWebImageCache.h"
#import "UIImage+Resize.h"
#import "UIImage+RoundedCorner.h"

@interface MHViewController ()<UICollectionViewDataSource, UICollectionViewDelegate>

@property(nonatomic, weak)UICollectionView *collectionView;
@property(nonatomic, strong)NSArray *dataSource;

@end

static NSString *identifier = @"cell";

@implementation MHViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    self.dataSource = @[@"http://jiahui.18866888.com/upload/Images/20140512/20140512164933_image.jpg",
                        @"http://jiahui.18866888.com/upload/Images/20140512/20140512164650_image.jpg",
                        @"http://jiahui.18866888.com/upload/Images/20140512/20140512163853_image.jpg",
                        @"http://jiahui.18866888.com/upload/Images/20140512/20140512163407_image.jpg",
                        @"http://jiahui.18866888.com/upload/Images/20140512/20140512145122_image.jpg",
                        @"http://jiahui.18866888.com/upload/Images/20140512/20140512124624_image.jpg",
                        @"http://jiahui.18866888.com/upload/Images/20140512/20140512163853_image.jpg",
                        @"http://jiahui.18866888.com/upload/Images/20140512/20140512164650_image.jpg",
                        @"http://jiahui.18866888.com/upload/Images/20140512/20140512164933_image.jpg",
                        @"http://jiahui.18866888.com/upload/Images/20140512/20140512205548_image.jpg",
                        @"http://jiahui.18866888.com/upload/Images/20140506/20140506120946_image.jpg",
                        @"http://jiahui.18866888.com/upload/Images/20140506/20140506123642_image.jpg"];
    
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    flowLayout.itemSize = CGSizeMake(245, 120);
    flowLayout.minimumLineSpacing = 10;
    flowLayout.minimumInteritemSpacing = 10;
    flowLayout.sectionInset = UIEdgeInsetsMake(40, 10, 10, 10);
    
    UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:flowLayout];
    collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    collectionView.backgroundColor = [UIColor whiteColor];
    [collectionView registerClass:[MHImageCollectionViewCell class] forCellWithReuseIdentifier:identifier];
    collectionView.dataSource = self;
    collectionView.delegate = self;
    [self.view addSubview:collectionView];
    self.collectionView = collectionView;

    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.dataSource.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    MHImageCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:identifier forIndexPath:indexPath];
    
    [cell.imageView af_setImageWithURL:[NSURL URLWithString:self.dataSource[indexPath.item]] transformImageBlock:^UIImage *(UIImage *originImage) {
       
        UIImage *image = [originImage croppedImage:CGRectMake(0, 0, 245, 120)];
        return [image roundedCornerImage:10.0 borderSize:0.0];
        
    }];
    
    return cell;
}

#pragma mark - ImageAdditions
+(UIImage*)imageWithImage:(UIImage*)image displayRect:(CGRect)rect byRoundingCorners:(UIRectCorner)corner cornerRadii:(CGSize)cornerRadii
{
    if (!image) {
        return nil;
    }
    
    // Begin a new image that will be the new image with the rounded corners
    // (here with the size of an UIImageView)
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0);
    
    // Add a clip before drawing anything, in the shape of an rounded rect
    
    [[UIBezierPath bezierPathWithRoundedRect:rect byRoundingCorners:corner cornerRadii:cornerRadii] addClip];
    
    // Draw your image
    [image drawInRect:rect];
    
    // Get the image, here setting the UIImageView image
    UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
    
    // Lets forget about that we were drawing
    UIGraphicsEndImageContext();
    
    return newImage;
}


@end
