
//  DWCoreTextLabel.m
//  DWCoreTextLabel
//
//  Created by Wicky on 16/12/4.
//  Copyright © 2016年 Wicky. All rights reserved.
//

#import "DWCoreTextLabel.h"
#import <CoreText/CoreText.h>
#import "DWAsyncLayer.h"
#import "DWWebImage.h"
#import "DWCoreTextLabelCalculator.h"

#define DRAWCANCELED \
do {\
if (isCanceled()) {\
return;\
}\
} while(0);

#define DRAWCANCELEDWITHREALSE(x,y) \
do {\
if (isCanceled()) {\
CFSAFERELEASE(x)\
CFSAFERELEASE(y)\
return;\
}\
} while(0);

@interface DWCoreTextLabel ()

///绘制文本
@property (nonatomic ,strong) NSMutableAttributedString * mAStr;

///绘制图片数组
@property (nonatomic ,strong) NSMutableArray * imageArr;

///占位图字典
@property (nonatomic ,strong) NSMutableDictionary <NSString *,NSMutableArray *>* placeHolderDic;

///活跃文本数组
@property (nonatomic ,strong) NSMutableArray * activeTextArr;

///自动链接数组
@property (nonatomic ,strong) NSMutableArray * autoLinkArr;

///活跃文本范围数组
@property (nonatomic ,strong) NSMutableArray * textRangeArr;

///绘制surround图片是排除区域数组
@property (nonatomic ,strong) NSMutableArray * imageExclusion;

///绘制插入图片是保存插入位置的数组
@property (nonatomic ,strong) NSMutableArray * arrLocationImgHasAdd;

///点击状态
@property (nonatomic ,assign) BOOL textClicked;

///自动链接点击状态
@property (nonatomic ,assign) BOOL linkClicked;

///保存可变排除区域的数组
@property (nonatomic ,strong) NSMutableArray * exclusionP;

///排除区域配置字典
@property (nonatomic ,strong) NSDictionary * exclusionDic;

///具有响应事件
@property (nonatomic ,assign) BOOL hasActionToDo;

///高亮范围字典
@property (nonatomic ,strong) NSMutableDictionary * highlightDic;

///重新计算
@property (nonatomic ,assign) BOOL reCalculate;

/////绘制尺寸
//@property (nonatomic ,assign) CGRect drawFrame;

///绘制范围
@property (nonatomic ,strong) UIBezierPath * drawPath;

///首次绘制
@property (nonatomic ,assign) BOOL finishFirstDraw;

///自动链接检测结果字典
@property (nonatomic ,strong) NSMutableDictionary * autoCheckLinkDic;

///自定制链接检测结果字典
@property (nonatomic ,strong) NSMutableDictionary * customLinkDic;

///重新自动检测
@property (nonatomic ,assign) BOOL reCheck;

///绘制队列
@property (nonatomic ,strong) dispatch_queue_t syncQueue;

@end

static DWTextImageDrawMode DWTextImageDrawModeInsert = 2;

@implementation DWCoreTextLabel
@synthesize font = _font;
@synthesize textColor = _textColor;
@synthesize exclusionPaths = _exclusionPaths;
@synthesize lineSpacing = _lineSpacing;
@synthesize autoCheckConfig = _autoCheckConfig;
@synthesize phoneNoAttributes = _phoneNoAttributes;
@synthesize phoneNoHighlightAttributes = _phoneNoHighlightAttributes;
@synthesize emailAttributes = _emailAttributes;
@synthesize emailHighlightAttributes = _emailHighlightAttributes;
@synthesize URLAttributes = _URLAttributes;
@synthesize URLHighlightAttributes = _URLHighlightAttributes;
@synthesize naturalNumAttributes = _naturalNumAttributes;
@synthesize naturalNumHighlightAttributes = _naturalNumHighlightAttributes;
@synthesize customLinkAttributes = _customLinkAttributes;
@synthesize customLinkHighlightAttributes = _customLinkHighlightAttributes;

#pragma mark ---接口方法---

///以指定模式绘制图片
-(void)dw_DrawImage:(UIImage *)image atFrame:(CGRect)frame margin:(CGFloat)margin drawMode:(DWTextImageDrawMode)mode target:(id)target selector:(SEL)selector {
    NSMutableDictionary * dic = [self configImage:image atFrame:frame margin:margin drawMode:mode target:target selector:selector];
    if (!dic) {
        return;
    }
    [self.imageArr addObject:dic];
    [self handleAutoRedrawWithRecalculate:YES reCheck:NO];
}

-(void)dw_DrawImageWithUrl:(NSString *)url atFrame:(CGRect)frame margin:(CGFloat)margin drawMode:(DWTextImageDrawMode)mode target:(id)target selector:(SEL)selector {
    [self dw_DrawImageWithUrl:url placeHolder:nil atFrame:frame margin:margin drawMode:mode target:target selector:selector];
}
    
-(void)dw_DrawImageWithUrl:(NSString *)url placeHolder:(UIImage *)placeHolder atFrame:(CGRect)frame margin:(CGFloat)margin drawMode:(DWTextImageDrawMode)mode target:(id)target selector:(SEL)selector {
    if (!placeHolder) {
        placeHolder = [UIImage new];
    }
    NSMutableDictionary * dic = [self configImage:placeHolder atFrame:frame margin:margin drawMode:mode target:target selector:selector];
    if (!dic) {
        return;
    }
    [self handlePlaceHolderDic:dic withUrl:url editImage:nil];
}

///以路径绘制图片
-(void)dw_DrawImage:(UIImage *)image WithPath:(UIBezierPath *)path margin:(CGFloat)margin drawMode:(DWTextImageDrawMode)mode target:(id)target selector:(SEL)selector {
    NSMutableDictionary * dic = [self configImage:image withPath:path margin:margin drawMode:mode target:target selector:selector];
    if (!dic) {
        return;
    }
    [self.imageArr addObject:dic];
    [self handleAutoRedrawWithRecalculate:YES reCheck:NO];
}

-(void)dw_DrawImageWithUrl:(NSString *)url WithPath:(UIBezierPath *)path margin:(CGFloat)margin drawMode:(DWTextImageDrawMode)mode target:(id)target selector:(SEL)selector {
    [self dw_DrawImageWithUrl:url placeHolder:nil WithPath:path margin:margin drawMode:mode target:self selector:selector];
}
    
-(void)dw_DrawImageWithUrl:(NSString *)url placeHolder:(UIImage *)placeHolder WithPath:(UIBezierPath *)path margin:(CGFloat)margin drawMode:(DWTextImageDrawMode)mode target:(id)target selector:(SEL)selector {
    if (!placeHolder) {
        placeHolder = [UIImage new];
    }
    NSMutableDictionary * dic = [self configImage:placeHolder withPath:path margin:margin drawMode:mode target:target selector:selector];
    if (!dic) {
        return;
    }
    [self handlePlaceHolderDic:dic withUrl:url editImage:^(UIImage *image) {
        UIBezierPath * newPath = [path copy];
        [newPath applyTransform:CGAffineTransformMakeTranslation(-newPath.bounds.origin.x, -newPath.bounds.origin.y)];
        return [DWCoreTextLabel dw_ClipImage:image withPath:newPath mode:(DWImageClipModeScaleAspectFill)];
    }];
}

///在字符串指定位置插入图片
-(void)dw_InsertImage:(UIImage *)image size:(CGSize)size padding:(CGFloat)padding descent:(CGFloat)descent atLocation:(NSUInteger)location target:(id)target selector:(SEL)selector {
    NSMutableDictionary * dic = [self configImage:image size:size padding:padding descent:descent atLocation:location target:target selector:selector];
    if (!dic) {
        return;
    }
    [self.imageArr addObject:dic];
    [self handleAutoRedrawWithRecalculate:YES reCheck:YES];
}

-(void)dw_InsertImageWithUrl:(NSString *)url size:(CGSize)size padding:(CGFloat)padding descent:(CGFloat)descent atLocation:(NSUInteger)location target:(id)target selector:(SEL)selector {
    [self dw_InsertImageWithUrl:url placeHolder:nil size:size padding:padding descent:descent atLocation:location target:self selector:selector];
}
    
-(void)dw_InsertImageWithUrl:(NSString *)url placeHolder:(UIImage *)placeHolder size:(CGSize)size padding:(CGFloat)padding descent:(CGFloat)descent atLocation:(NSUInteger)location target:(id)target selector:(SEL)selector {
    if (!placeHolder) {
        placeHolder = [UIImage new];
    }
    NSMutableDictionary * dic = [self configImage:placeHolder size:size padding:padding descent:descent atLocation:location target:target selector:selector];
    if (!dic) {
        return;
    }
    [self handlePlaceHolderDic:dic withUrl:url editImage:nil];
}

///给指定范围添加响应事件
-(void)dw_AddTarget:(id)target selector:(SEL)selector toRange:(NSRange)range {
    if (target && selector && range.length > 0) {
        NSMutableDictionary * dic = [NSMutableDictionary dictionaryWithDictionary:@{@"target":target,@"SEL":NSStringFromSelector(selector),@"range":[NSValue valueWithRange:range]}];
        [self.textRangeArr addObject:dic];
        [self handleAutoRedrawWithRecalculate:YES reCheck:YES];
    }
}

///返回指定路径的图片
+(UIImage *)dw_ClipImage:(UIImage *)image withPath:(UIBezierPath *)path mode:(DWImageClipMode)mode {
    if (!image) {
        return nil;
    }
    CGFloat originScale = image.size.width * 1.0 / image.size.height;
    CGRect boxBounds = path.bounds;
    CGFloat width = boxBounds.size.width;
    CGFloat height = width / originScale;
    
    switch (mode) {
        case DWImageClipModeScaleAspectFit:
        {
            if (height > boxBounds.size.height) {
                height = boxBounds.size.height;
                width = height * originScale;
            }
        }
            break;
        case DWImageClipModeScaleAspectFill:
        {
            if (height < boxBounds.size.height) {
                height = boxBounds.size.height;
                width = height * originScale;
            }
        }
            break;
        default:
            if (height != boxBounds.size.height) {
                height = boxBounds.size.height;
            }
            break;
    }
    
    ///开启上下文
    UIGraphicsBeginImageContextWithOptions(boxBounds.size, NO, [UIScreen mainScreen].scale);
    CGContextRef bitmap = UIGraphicsGetCurrentContext();
    
    ///切图
    UIBezierPath * newPath = [path copy];
    if (!(newPath.bounds.origin.x * newPath.bounds.origin.y)) {
        [newPath applyTransform:CGAffineTransformMakeTranslation(-newPath.bounds.origin.x, -newPath.bounds.origin.y)];
    }
    [newPath addClip];
    
    ///移动原点至图片中心
    CGContextTranslateCTM(bitmap, boxBounds.size.width/2.0, boxBounds.size.height/2.0);
    CGContextScaleCTM(bitmap, 1.0, -1.0);
    CGContextDrawImage(bitmap, CGRectMake(-width / 2, -height / 2, width, height), image.CGImage);
    
    ///生成图片
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

+(void)dw_ClipImageWithUrl:(NSString *)url withPath:(UIBezierPath *)path mode:(DWImageClipMode)mode completion:(void(^)(UIImage * image))completion {
    [[DWWebImageManager shareManager] downloadImageWithUrl:url completion:^(UIImage *image) {
        image = [DWCoreTextLabel dw_ClipImage:image withPath:path mode:mode];
        completion(image);
    }];
}

#pragma mark ---插入图片相关---

///将所有插入图片插入字符串
-(void)handleStr:(NSMutableAttributedString *)str withInsertImageArr:(NSMutableArray *)arr arrLocationImgHasAdd:(NSMutableArray *)arrLocationImgHasAdd {
    [arrLocationImgHasAdd removeAllObjects];
    [arr enumerateObjectsUsingBlock:^(NSMutableDictionary * dic, NSUInteger idx, BOOL * _Nonnull stop) {
        handleInsertPic(self,dic,str,arrLocationImgHasAdd);
    }];
}

///将图片设置代理后插入富文本
static inline void handleInsertPic(DWCoreTextLabel * label,NSMutableDictionary * dic,NSMutableAttributedString * str,NSMutableArray * arrLocationImgHasAdd) {
    NSInteger location = [dic[@"location"] integerValue];
    CTRunDelegateCallbacks callBacks;
    memset(&callBacks, 0, sizeof(CTRunDelegateCallbacks));
    callBacks.version = kCTRunDelegateVersion1;
    callBacks.getAscent = ascentCallBacks;
    callBacks.getDescent = descentCallBacks;
    callBacks.getWidth = widthCallBacks;
    CTRunDelegateRef delegate = CTRunDelegateCreate(& callBacks, (__bridge void *)dic);
    unichar placeHolder = 0xFFFC;
    NSString * placeHolderStr = [NSString stringWithCharacters:&placeHolder length:1];
    NSMutableAttributedString * placeHolderAttrStr = [[NSMutableAttributedString alloc] initWithString:placeHolderStr];
    CFAttributedStringSetAttribute((CFMutableAttributedStringRef)placeHolderAttrStr, CFRangeMake(0, 1), kCTRunDelegateAttributeName, delegate);
    CFSAFERELEASE(delegate);
    NSInteger offset = getInsertOffset(arrLocationImgHasAdd,location);
    [str insertAttributedString:placeHolderAttrStr atIndex:location + offset];
}

///根据三种类型获取配置字典
-(NSMutableDictionary *)configImage:(UIImage *)image atFrame:(CGRect)frame margin:(CGFloat)margin drawMode:(DWTextImageDrawMode)mode target:(id)target selector:(SEL)selector {
    if (!image) {
        return nil;
    }
    if (CGRectEqualToRect(frame, CGRectZero)) {
        return nil;
    }
    CGRect drawFrame = CGRectInset(frame, margin, margin);
    UIBezierPath * drawPath = [UIBezierPath bezierPathWithRect:frame];
    UIBezierPath * activePath = getImageAcitvePath(drawPath,margin);
    NSMutableDictionary * dic = [NSMutableDictionary dictionaryWithDictionary:@{@"image":image,@"drawPath":drawPath,@"activePath":activePath,@"frame":[NSValue valueWithCGRect:drawFrame],@"margin":@(margin),@"drawMode":@(mode)}];
    if (target && selector) {
        [dic setValue:target forKey:@"target"];
        [dic setValue:NSStringFromSelector(selector) forKey:@"SEL"];
    }
    return dic;
}

-(NSMutableDictionary *)configImage:(UIImage *)image withPath:(UIBezierPath *)path margin:(CGFloat)margin drawMode:(DWTextImageDrawMode)mode target:(id)target selector:(SEL)selector {
    if (!image) {
        return nil;
    }
    if (!path) {
        return nil;
    }
    UIBezierPath * newPath = [path copy];
    [newPath applyTransform:CGAffineTransformMakeTranslation(-newPath.bounds.origin.x, -newPath.bounds.origin.y)];
    image = [DWCoreTextLabel dw_ClipImage:image withPath:newPath mode:(DWImageClipModeScaleAspectFill)];
    UIBezierPath * activePath = getImageAcitvePath(path,margin);
    
    NSMutableDictionary * dic = [NSMutableDictionary dictionaryWithDictionary:@{@"image":image,@"drawPath":path,@"activePath":activePath,@"frame":[NSValue valueWithCGRect:CGRectInset(path.bounds, margin, margin)],@"drawMode":@(mode)}];
    if (target && selector) {
        [dic setValue:target forKey:@"target"];
        [dic setValue:NSStringFromSelector(selector) forKey:@"SEL"];
    }
    return dic;
}

-(NSMutableDictionary *)configImage:(UIImage *)image size:(CGSize)size padding:(CGFloat)padding descent:(CGFloat)descent atLocation:(NSUInteger)location target:(id)target selector:(SEL)selector {
    if (!image) {
        return nil;
    }
    if (padding != 0) {
        size = CGSizeMake(size.width + padding * 2, size.height);
    }
    NSMutableDictionary * dic = [NSMutableDictionary dictionaryWithDictionary:@{@"image":image,@"size":[NSValue valueWithCGSize:size],@"padding":@(padding),@"location":@(location),@"descent":@(descent),@"drawMode":@(DWTextImageDrawModeInsert)}];
    if (target && selector) {
        [dic setValue:target forKey:@"target"];
        [dic setValue:NSStringFromSelector(selector) forKey:@"SEL"];
    }
    return dic;
}

///处理占位图的绘制及替换工作
-(void)handlePlaceHolderDic:(NSMutableDictionary *)dic withUrl:(NSString *)url editImage:(UIImage *(^)(UIImage * image))edit {
    ///将配置字典添加到占位图字典中
    NSMutableArray * placeHolderArr = self.placeHolderDic[url];
    if (!placeHolderArr) {
        placeHolderArr = [NSMutableArray array];
        self.placeHolderDic[url] = placeHolderArr;
    }
    if (![placeHolderArr containsObject:dic]) {
        [placeHolderArr addObject:dic];
    }
    
    ///绘制占位图
    [self.imageArr addObject:dic];
    [self handleAutoRedrawWithRecalculate:YES reCheck:NO];
    
    ///下载网络图片
    __weak typeof(self)weakSelf = self;
    [[DWWebImageManager shareManager] downloadImageWithUrl:url completion:^(UIImage *image) {
        ///下载完成后替换占位图配置字典中图片为网络图片并绘制
        if (image) {
            if (edit) {
                image = edit(image);
            }
            NSMutableArray * placeHolderArr = weakSelf.placeHolderDic[url];
            if (placeHolderArr) {
                [placeHolderArr enumerateObjectsUsingBlock:^(NSMutableDictionary * obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    [obj setValue:image forKey:@"image"];
                }];
                [placeHolderArr removeAllObjects];
                [weakSelf handleAutoRedrawWithRecalculate:NO reCheck:NO];
            }
        }
    }];
}

#pragma mark ---文本相关---

///处理句尾省略号
-(void)handleLastLineTruncateWithLastLineRange:(CFRange)range attributeString:(NSMutableAttributedString *)mAStr{
    NSDictionary * lastAttribute = [mAStr attributesAtIndex:mAStr.length - 1 effectiveRange:NULL];
    NSMutableParagraphStyle * newPara = [lastAttribute[NSParagraphStyleAttributeName] mutableCopy];
    newPara.lineBreakMode = NSLineBreakByTruncatingTail;
    [mAStr addAttribute:NSParagraphStyleAttributeName value:newPara range:NSMakeRange(range.location, range.length)];
}

///添加活跃文本属性方法
-(void)handleActiveTextWithStr:(NSMutableAttributedString *)str rangeSet:(NSMutableSet *)rangeSet withImage:(BOOL)withImage {
    [self.textRangeArr enumerateObjectsUsingBlock:^(NSMutableDictionary * dic  , NSUInteger idx, BOOL * _Nonnull stop) {
        NSRange range = [dic[@"range"] rangeValue];
        if (withImage) {
            range = getRangeOffset(range,self.arrLocationImgHasAdd);
        }
        [rangeSet addObject:[NSValue valueWithRange:range]];
        [str addAttribute:@"clickAttribute" value:dic range:range];
        if (self.textClicked && self.highlightDic) {
            if (NSEqualRanges([dic[@"range"] rangeValue], [self.highlightDic[@"range"] rangeValue])) {
                [str addAttributes:self.activeTextHighlightAttributes range:range];
            } else {
                if (self.activeTextAttributes) {
                    [str addAttributes:self.activeTextAttributes range:range];
                }
            }
        } else {
            if (self.activeTextAttributes) {
                [str addAttributes:self.activeTextAttributes range:range];
            }
        }
    }];
}

#pragma mark ---自动检测链接相关---
///自动检测链接方法
-(void)handleAutoCheckLinkWithStr:(NSMutableAttributedString *)str linkRange:(NSRange)linkRange rangeSet:(NSMutableSet *)rangeSet {
    [self handleAutoCheckWithLinkType:DWLinkTypeEmail str:str linkRange:linkRange rangeSet:rangeSet linkDic:self.autoCheckLinkDic attributeName:@"autoCheckLink"];
    [self handleAutoCheckWithLinkType:DWLinkTypeURL str:str linkRange:linkRange rangeSet:rangeSet linkDic:self.autoCheckLinkDic attributeName:@"autoCheckLink"];
    [self handleAutoCheckWithLinkType:DWLinkTypePhoneNo str:str linkRange:linkRange rangeSet:rangeSet linkDic:self.autoCheckLinkDic attributeName:@"autoCheckLink"];
    [self handleAutoCheckWithLinkType:DWLinkTypeNaturalNum str:str linkRange:linkRange rangeSet:rangeSet linkDic:self.autoCheckLinkDic attributeName:@"autoCheckLink"];
}

///根据类型处理自动链接
-(void)handleAutoCheckWithLinkType:(DWLinkType)linkType str:(NSMutableAttributedString *)str linkRange:(NSRange)linkRange rangeSet:(NSMutableSet *)rangeSet linkDic:(NSMutableDictionary *)linkDic attributeName:(NSString *)attributeName {
    
    NSString * pattern = @"";
    NSDictionary * tempAttributesDic = nil;
    NSDictionary * tempHighLightAttributesDic = nil;
    switch (linkType) {///根据type获取高亮属性及匹配正则
        case DWLinkTypeNaturalNum:
        {
            pattern = self.autoCheckConfig[@"naturalNum"];
            tempAttributesDic = self.naturalNumAttributes;
            tempHighLightAttributesDic = self.naturalNumHighlightAttributes;
        }
            break;
        case DWLinkTypePhoneNo:
        {
            pattern = self.autoCheckConfig[@"phoneNo"];
            tempAttributesDic = self.phoneNoAttributes;
            tempHighLightAttributesDic = self.phoneNoHighlightAttributes;
        }
            break;
        case DWLinkTypeEmail:
        {
            pattern = self.autoCheckConfig[@"email"];
            tempAttributesDic = self.emailAttributes;
            tempHighLightAttributesDic = self.emailHighlightAttributes;
        }
            break;
        case DWLinkTypeURL:
        {
            pattern = self.autoCheckConfig[@"URL"];
            tempAttributesDic = self.URLAttributes;
            tempHighLightAttributesDic = self.URLHighlightAttributes;
        }
            break;
        case DWLinkTypeCustom:
        {
            pattern = self.customLinkRegex.length?self.customLinkRegex:@"";
            tempAttributesDic = self.customLinkAttributes;
            tempHighLightAttributesDic = self.customLinkHighlightAttributes;
        }
            break;
        default:
        {
            pattern = self.autoCheckConfig[@"phoneNo"];
            tempAttributesDic = self.phoneNoAttributes;
            tempHighLightAttributesDic = self.phoneNoHighlightAttributes;
        }
            break;
    }
    if (pattern.length) {
        NSMutableArray * arrLink = nil;
        if (self.reCheck) {
            NSRegularExpression * regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
            ///获取匹配结果
            NSArray * arr = [regex matchesInString:str.string options:0 range:linkRange];
            ///处理匹配结果，排除已经匹配过的结果
            NSMutableArray * arrTemp = [NSMutableArray array];
            [arr enumerateObjectsUsingBlock:^(NSTextCheckingResult * result, NSUInteger idx, BOOL * _Nonnull stop) {
                __block BOOL contain = NO;
                NSMutableArray * replicateRangeArr = [NSMutableArray array];
                [rangeSet enumerateObjectsUsingBlock:^(NSValue * RValue, BOOL * _Nonnull stop) {
                    NSRange range = NSIntersectionRange([RValue rangeValue], result.range);
                    if (range.length > 0) {
                        contain = YES;
                        hanldeReplicateRange(result.range,RValue.rangeValue,str,pattern,replicateRangeArr);
                        *stop = YES;
                    }
                }];
                if (!contain) {
                    [arrTemp addObject:result];
                    [rangeSet addObject:[NSValue valueWithRange:result.range]];
                } else if (replicateRangeArr.count) {
                    [replicateRangeArr enumerateObjectsUsingBlock:^(NSTextCheckingResult * obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        [arrTemp addObject:obj];
                        [rangeSet addObject:[NSValue valueWithRange:obj.range]];
                    }];
                }
            }];
            [linkDic setValue:arrTemp forKey:pattern];
            arrLink = arrTemp;
        } else {
            arrLink = linkDic[pattern];
        }
        ///添加高亮属性
        NSRange highLightRange = [self.highlightDic[@"range"] rangeValue];
        [arrLink enumerateObjectsUsingBlock:^(NSTextCheckingResult * obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSRange range = obj.range;
            NSDictionary * dic = @{@"link":[str.string substringWithRange:range],@"range":[NSValue valueWithRange:range],@"linkType":@(linkType),@"target":self,@"SEL":NSStringFromSelector(@selector(autoLinkClicked:))};
            [str addAttribute:attributeName value:dic range:range];
            if (self.linkClicked && self.highlightDic) {
                if (NSEqualRanges(range, highLightRange)) {
                    [str addAttributes:tempHighLightAttributesDic range:range];
                } else {
                    if (tempAttributesDic) {
                        [str addAttributes:tempAttributesDic range:range];
                    }
                }
            } else {
                if (tempAttributesDic) {
                    [str addAttributes:tempAttributesDic range:range];
                }
            }
        }];
    }
}

///处理文本高亮状态
-(void)handleStringHighlightAttributesWithRangeSet:(NSMutableSet *)rangeSet visibleRange:(CFRange)visibleRange {
    NSRange vRange = NSMakeRange(visibleRange.location, visibleRange.length);
    [self handleAutoCheckWithLinkType:DWLinkTypeCustom str:self.mAStr linkRange:vRange rangeSet:rangeSet linkDic:self.customLinkDic attributeName:@"customLink"];
    ///处理自动检测链接
    if (self.autoCheckLink) {
        [self handleAutoCheckLinkWithStr:self.mAStr linkRange:vRange rangeSet:rangeSet];
    }
}

///处理匹配结果中重复范围
static inline void hanldeReplicateRange(NSRange targetR,NSRange exceptR,NSMutableAttributedString * str,NSString * pattern,NSMutableArray * linkArr) {
    NSArray * arr = getRangeExcept(targetR, exceptR);
    [arr enumerateObjectsUsingBlock:^(NSValue * rangeValue, NSUInteger idx, BOOL * _Nonnull stop) {
        NSRegularExpression * regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
        NSArray * results = [regex matchesInString:str.string options:0 range:rangeValue.rangeValue];
        [linkArr addObjectsFromArray:results];
    }];
}

#pragma mark ---绘制相关---

///绘制富文本
-(void)drawTheTextWithContext:(CGContextRef)context isCanceled:(BOOL(^)())isCanceled {
    dispatch_barrier_sync(self.syncQueue, ^{
        CGContextSaveGState(context);
        CGContextSetTextMatrix(context, CGAffineTransformIdentity);
        CGContextTranslateCTM(context, 0, self.bounds.size.height);
        CGContextScaleCTM(context, 1.0, -1.0);
        
        ///计算绘制尺寸限制
        CGFloat limitWidth = (self.bounds.size.width - self.textInsets.left - self.textInsets.right) > 0 ? (self.bounds.size.width - self.textInsets.left - self.textInsets.right) : 0;
        CGFloat limitHeight = (self.bounds.size.height - self.textInsets.top - self.textInsets.bottom) > 0 ? (self.bounds.size.height - self.textInsets.top - self.textInsets.bottom) : 0;
        
        ///获取排除区域
        NSArray * exclusionPaths = [self handleExclusionPaths];
        CGRect frame = CGRectMake(self.textInsets.left, self.textInsets.bottom, limitWidth, limitHeight);
        NSDictionary * exclusionConfig = getExclusionDic(exclusionPaths, frame);
        BOOL needDrawString = self.attributedText.length || self.text.length;
        
        DRAWCANCELED
        if ((self.reCalculate || !self.mAStr) && needDrawString) {
            ///获取要绘制的文本(初步处理，未处理插入图片、句尾省略号、高亮)
            self.mAStr = getMAStr(self,limitWidth,exclusionPaths);
        }
        CTFramesetterRef frameSetter4Cal = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)self.mAStr);
        CTFrameRef frame4Cal = CTFramesetterCreateFrame(frameSetter4Cal, CFRangeMake(0, 0), [UIBezierPath bezierPathWithRect:frame].CGPath, (__bridge_retained CFDictionaryRef)exclusionConfig);
        
        
        CFRange visibleRange = getRangeToDrawForVisibleString(frame4Cal);
        
        ///处理句尾省略号
        DRAWCANCELEDWITHREALSE(frameSetter4Cal, frame4Cal)
        if ((self.reCalculate || !self.mAStr) && needDrawString) {
            CFRange lastRange = getLastLineRange(frame4Cal, self.numberOfLines,visibleRange);
            [self handleLastLineTruncateWithLastLineRange:lastRange attributeString:self.mAStr];
        }
        
        DRAWCANCELEDWITHREALSE(frameSetter4Cal, frame4Cal)
        ///已添加事件、链接的集合
        NSMutableSet * rangeSet = [NSMutableSet set];
        ///添加活跃文本属性方法
        if (needDrawString) {
            [self handleActiveTextWithStr:self.mAStr rangeSet:rangeSet withImage:!self.reCalculate];
        }
        
        DRAWCANCELEDWITHREALSE(frameSetter4Cal, frame4Cal)
        ///处理文本高亮状态并获取可见绘制文本范围
        if (needDrawString) {
            [self handleStringHighlightAttributesWithRangeSet:rangeSet visibleRange:visibleRange];
        }
        
        DRAWCANCELEDWITHREALSE(frameSetter4Cal, frame4Cal)
        ///处理插入图片
        if (self.reCalculate && needDrawString) {
            NSMutableArray * arrInsert = [NSMutableArray array];
            [self.imageArr enumerateObjectsUsingBlock:^(NSDictionary * dic, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([dic[@"drawMode"] integerValue] == DWTextImageDrawModeInsert) {
                    [arrInsert addObject:dic];
                }
            }];
            
            if (arrInsert.count) {
                ///富文本插入图片占位符
                [self handleStr:self.mAStr withInsertImageArr:arrInsert arrLocationImgHasAdd:self.arrLocationImgHasAdd];
                ///插入图片后重新处理工厂及frame，添加插入图片后的字符串，消除插入图片影响
                CFSAFERELEASE(frameSetter4Cal)
                CFSAFERELEASE(frame4Cal)
                frameSetter4Cal = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)self.mAStr);
                frame4Cal = CTFramesetterCreateFrame(frameSetter4Cal, CFRangeMake(0, 0), [UIBezierPath bezierPathWithRect:frame].CGPath, (__bridge_retained CFDictionaryRef)exclusionConfig);
                visibleRange = getRangeToDrawForVisibleString(frame4Cal);
            }
        }
        
        /***************************/
        /*  至此富文本绘制配置处理完毕  */
        /***************************/
        

        DRAWCANCELED
        ///计算drawFrame及drawPath
        if (self.reCalculate) {
            self.drawPath = [self handleDrawFrameAndPathWithLimitWidth:limitWidth limitHeight:limitHeight frameSetter:frameSetter4Cal rangeToDraw:visibleRange exclusionPaths:exclusionPaths];
        }
        
        CFSAFERELEASE(frameSetter4Cal)
        CFSAFERELEASE(frame4Cal)
        
        /**********************/
        /*  至此绘制区域处理完毕  */
        /**********************/
        
        DRAWCANCELED
        ///绘制的工厂
        CTFramesetterRef frameSetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)self.mAStr);
        ///绘制范围为可见范围加1，防止末尾省略号失效（由于path为可见尺寸，故仅绘制可见范围时有的时候末尾的省略号会失效，同时不可超过字符串本身长度）
        CFRange drawRange = CFRangeMake(0, visibleRange.length < self.mAStr.length ? visibleRange.length + 1 : self.mAStr.length);
        CTFrameRef visibleFrame = CTFramesetterCreateFrame(frameSetter, drawRange, self.drawPath.CGPath, (__bridge_retained CFDictionaryRef)exclusionConfig);
        
        DRAWCANCELEDWITHREALSE(frameSetter, visibleFrame)
        if (self.reCalculate && needDrawString) {
            ///计算活跃文本及插入图片的frame
            [self handleFrameForActiveTextAndInsertImageWithCTFrame:visibleFrame];
        }
        
        /**********************/
        /*  至此点击区域处理完毕  */
        /**********************/
        
        DRAWCANCELEDWITHREALSE(frameSetter, visibleFrame)
        ///绘制图片
        [self.imageArr enumerateObjectsUsingBlock:^(NSDictionary * dic, NSUInteger idx, BOOL * _Nonnull stop) {
            UIImage * image = dic[@"image"];
            CGRect frame = convertRect([dic[@"frame"] CGRectValue],self.bounds.size.height);
            CGContextDrawImage(context, frame, image.CGImage);
        }];
        
        self.reCalculate = NO;
        self.reCheck = NO;
        self.finishFirstDraw = YES;
        ///绘制上下文
        CTFrameDraw(visibleFrame, context);
        
        /*******************/
        /*  至此绘制处理完毕  */
        /*******************/
        
        ///内存管理
        CFSAFERELEASE(visibleFrame)
        CFSAFERELEASE(frameSetter)
        CGContextRestoreGState(context);
    });
}

///处理绘制path
-(UIBezierPath *)handleDrawFrameAndPathWithLimitWidth:(CGFloat)limitWidth limitHeight:(CGFloat)limitHeight  frameSetter:(CTFramesetterRef)frameSetter rangeToDraw:(CFRange)rangeToDraw exclusionPaths:(NSArray * )exclusionPaths {
    
    ///获取排除区域配置字典
    CGRect frameR = CGRectMake(self.textInsets.left, self.textInsets.bottom, limitWidth, limitHeight);
    
    if (exclusionPaths.count == 0) {
        ///若无排除区域处理对其方式方式
        CGSize suggestSize = getSuggestSize(frameSetter, rangeToDraw, limitWidth, self.numberOfLines);
        [self handleAlignmentWithFrame:&frameR suggestSize:suggestSize limitWidth:limitWidth];
    }
    
    ///创建绘制区域
    return [UIBezierPath bezierPathWithRect:frameR];
}

///处理对齐方式
-(void)handleAlignmentWithFrame:(CGRect *)frame suggestSize:(CGSize)suggestSize limitWidth:(CGFloat)limitWidth {
    if ((*frame).size.height > suggestSize.height) {///垂直对齐方式处理
        (*frame).size = suggestSize;
        CGPoint origin = (*frame).origin;
        if (self.textVerticalAlignment == DWTextVerticalAlignmentCenter) {
            origin.y = self.bounds.size.height / 2.0 - suggestSize.height / 2.0;
        }
        else if (self.textVerticalAlignment == DWTextVerticalAlignmentTop)
        {
            origin.y = self.bounds.size.height - suggestSize.height - self.textInsets.top;
        }
        (*frame).origin = origin;
    }
    if ((*frame).size.width < limitWidth) {///水平对齐方式处理
        CGPoint origin = (*frame).origin;
        if (self.textAlignment == NSTextAlignmentCenter) {
            origin.x = self.bounds.size.width / 2.0 - (*frame).size.width / 2.0;
        } else if (self.textAlignment == NSTextAlignmentRight) {
            origin.x = self.bounds.size.width - (*frame).size.width - self.textInsets.right;
        }
        (*frame).origin = origin;
    }
}

#pragma mark --- 重绘行为处理 ---
///自动重绘
-(void)handleAutoRedrawWithRecalculate:(BOOL)reCalculate reCheck:(BOOL)reCheck {
    [self handleAutoRedrawWithRecalculate:reCalculate reCheck:reCheck reDraw:YES];
}

///按需重绘
-(void)handleAutoRedrawWithRecalculate:(BOOL)reCalculate reCheck:(BOOL)reCheck reDraw:(BOOL)reDraw {
    if (self.finishFirstDraw) {
        if (!self.reCalculate && reCalculate) {//防止计算需求被抵消
            self.reCalculate = YES;
        }
        if (!self.reCheck && reCheck) {//防止链接检测需求被抵消
            self.reCheck = YES;
        }
    }
    if (reDraw) {
        [self setNeedsDisplay];
    }
}

///文本变化相关处理
-(void)handleTextChange {
    self.mAStr = nil;
    [self.imageArr removeAllObjects];
    [self.activeTextArr removeAllObjects];
    [self.autoLinkArr removeAllObjects];
    [self.textRangeArr removeAllObjects];
    [self.arrLocationImgHasAdd removeAllObjects];
    [self handleAutoRedrawWithRecalculate:YES reCheck:YES reDraw:self.autoRedraw];
}

///处理图片环绕数组，绘制前调用
-(void)handleImageExclusion {
    [self.imageExclusion removeAllObjects];
    [self.imageArr enumerateObjectsUsingBlock:^(NSDictionary * dic, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([dic[@"drawMode"] integerValue] == DWTextImageDrawModeSurround) {
            UIBezierPath * newPath = [dic[@"drawPath"] copy];
            [self.imageExclusion addObject:newPath];
        }
    }];
}

///获取排除区域数组
-(NSArray *)handleExclusionPaths {
    ///处理图片排除区域
    [self handleImageExclusion];
    ///获取全部排除区域
    NSMutableArray * exclusion = [NSMutableArray array];
    
    ///此处排除区域需要对textInset的偏移量进行校正
    [self.exclusionP enumerateObjectsUsingBlock:^(UIBezierPath * obj, NSUInteger idx, BOOL * _Nonnull stop) {
        translatePath(obj, self.textInsets.bottom - self.textInsets.top);
        [exclusion addObject:obj];
    }];
    
    [self.imageExclusion enumerateObjectsUsingBlock:^(UIBezierPath * obj, NSUInteger idx, BOOL * _Nonnull stop) {
        translatePath(obj, self.textInsets.bottom - self.textInsets.top);
        [exclusion addObject:obj];
    }];
    return exclusion;
}

#pragma mark --- 点击事件相关 ---
///将所有插入图片和活跃文本字典中的frame补全，重绘前调用
-(void)handleFrameForActiveTextAndInsertImageWithCTFrame:(CTFrameRef)frame {
    [self.activeTextArr removeAllObjects];
    [self.autoLinkArr removeAllObjects];
    [self enumerateCTRunInFrame:frame handler:^(CTLineRef line, CTRunRef run,CGPoint origin,BOOL * stop) {
        CGRect deleteBounds = getCTRunBounds(frame,line,origin,run);
        if (CGRectEqualToRect(deleteBounds,CGRectNull)) {///无活动范围跳过
            return ;
        }
        deleteBounds = convertRect(deleteBounds,self.bounds.size.height);
        
        NSDictionary * attributes = (NSDictionary *)CTRunGetAttributes(run);
        CTRunDelegateRef delegate = (__bridge CTRunDelegateRef)[attributes valueForKey:(id)kCTRunDelegateAttributeName];
        
        if (delegate == nil) {///检测图片，不是图片检测文字
            NSMutableDictionary * dic = attributes[@"clickAttribute"];
            if (!dic) {///不是活动文字检测自动链接及定制链接
                if (self.customLinkRegex.length) {
                    dic = attributes[@"customLink"];
                }
                
                if (!dic && self.autoCheckLink) {
                    dic = attributes[@"autoCheckLink"];
                }
                if (!dic) {
                    return;
                }
                handleFrame(self.autoLinkArr,dic,deleteBounds);
                return;
            }
            handleFrame(self.activeTextArr,dic,deleteBounds);
            return;
        }
        NSMutableDictionary * dic = CTRunDelegateGetRefCon(delegate);
        if (![dic isKindOfClass:[NSMutableDictionary class]]) {
            return;
        }
        UIImage * image = dic[@"image"];
        if (!image) {///检测图片，不是图片跳过
            return;
        }
        
        dic[@"drawPath"] = [UIBezierPath bezierPathWithRect:deleteBounds];
        CGFloat padding = [dic[@"padding"] floatValue];
        if (padding != 0) {
            deleteBounds = CGRectInset(deleteBounds, padding, 0);
        }
        if (!CGRectEqualToRect(deleteBounds, CGRectZero)) {
            dic[@"frame"] = [NSValue valueWithCGRect:deleteBounds];
            dic[@"activePath"] = [UIBezierPath bezierPathWithRect:deleteBounds];
        }
    }];
}

///遍历CTRun
-(void)enumerateCTRunInFrame:(CTFrameRef)frame handler:(void(^)(CTLineRef line,CTRunRef run,CGPoint origin,BOOL * stop))handler {
    NSArray * arrLines = (NSArray *)CTFrameGetLines(frame);
    NSInteger count = [arrLines count];
    CGPoint points[count];
    CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), points);
    BOOL stop = NO;
    for (int i = 0; i < count; i ++) {
        CTLineRef line = (__bridge CTLineRef)arrLines[i];
        NSArray * arrRuns = (NSArray *)CTLineGetGlyphRuns(line);
        for (int j = 0; j < arrRuns.count; j ++) {
            CTRunRef run = (__bridge CTRunRef)arrRuns[j];
            handler(line,run,points[i],&stop);
            if (stop) {
                break;
            }
        }
    }
}

///补全frame
static inline void handleFrame(NSMutableArray * arr,NSDictionary *dic,CGRect deleteBounds) {
    NSValue * boundsValue = [NSValue valueWithCGRect:deleteBounds];
    NSMutableDictionary * dicWithFrame = [NSMutableDictionary dictionaryWithDictionary:dic];
    dicWithFrame[@"frame"] = boundsValue;
    [arr addObject:dicWithFrame];
}

///自动链接事件
-(void)autoLinkClicked:(NSDictionary *)userInfo {
    if (self.delegate && [self.delegate respondsToSelector:@selector(coreTextLabel:didSelectLink:range:linkType:)]) {
        [self.delegate coreTextLabel:self didSelectLink:userInfo[@"link"] range:[userInfo[@"range"] rangeValue] linkType:[userInfo[@"linkType"] integerValue]];
    }
}

///处理点击事件
-(void)handleClickWithDic:(NSDictionary *)dic {
    self.hasActionToDo = NO;
    self.highlightDic = nil;
    id target = dic[@"target"];
    SEL selector = NSSelectorFromString(dic[@"SEL"]);
    NSMethodSignature  *signature = [[target class] instanceMethodSignatureForSelector:selector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = target;
    invocation.selector = selector;
    if ([target isEqual:self]) {
        [invocation setArgument:&dic atIndex:2];
    }
    [invocation invoke];
}

///处理点击高亮
-(void)handleHighlightClickWithDic:(NSMutableDictionary *)dic isLink:(BOOL)link {
    self.highlightDic = dic;
    if (!link && self.activeTextHighlightAttributes) {
        self.textClicked = YES;
        [self setNeedsDisplay];
        return;
    }
    if (link && (self.customLinkRegex.length || self.autoCheckLink)) {
        self.linkClicked = YES;
        [self setNeedsDisplay];
    }
}

///处理具有响应事件状态
-(NSMutableDictionary *)handleHasActionStatusWithPoint:(CGPoint)point {
    self.hasActionToDo = NO;
    NSMutableDictionary * dic = getImageDic(self.imageArr, point);
    if (dic) {
        self.hasActionToDo = YES;
        return nil;
    }
    dic = getActiveTextDic(self.activeTextArr, point);
    if (dic) {
        self.hasActionToDo = YES;
        return dic;
    }
    dic = getAutoLinkDic(self.autoLinkArr, point);
    if (dic) {
        self.hasActionToDo = YES;
        return dic;
    }
    return nil;
}

#pragma mark --- 获取点击行为 ---
-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    CGPoint point = [[touches anyObject] locationInView:self];
    
    NSMutableDictionary * dic = [self handleHasActionStatusWithPoint:point];
    BOOL autoLink = [dic[@"link"] length];
    if (dic) {
        [self handleHighlightClickWithDic:dic isLink:autoLink];
        return;
    }
    [super touchesBegan:touches withEvent:event];
}

-(void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.hasActionToDo) {
        CGPoint point = [[touches anyObject] locationInView:self];
        NSMutableDictionary * dic = [self handleHasActionStatusWithPoint:point];
        if (!self.hasActionToDo || ![self.highlightDic isEqualToDictionary:dic]) {
            if (self.textClicked) {
                self.textClicked = NO;
                self.highlightDic = nil;
                [self setNeedsDisplay];
            } else if (self.linkClicked) {
                self.linkClicked = NO;
                self.highlightDic = nil;
                [self setNeedsDisplay];
            }
        }
        return;
    }
    [super touchesMoved:touches withEvent:event];
}

-(void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.hasActionToDo) {
        CGPoint point = [[touches anyObject] locationInView:self];
        NSMutableDictionary * dic = getImageDic(self.imageArr,point);
        if (dic) {
            [self handleClickWithDic:dic];
            return;
        }
        dic = self.highlightDic;
        if (dic) {
            if (self.textClicked) {
                self.textClicked = NO;
                [self setNeedsDisplay];
            } else if (self.linkClicked) {
                self.linkClicked = NO;
                [self setNeedsDisplay];
            }
            [self handleClickWithDic:dic];
            return;
        }
    }
    [super touchesEnded:touches withEvent:event];
}

#pragma mark ---CTRun 代理---
static CGFloat ascentCallBacks(void * ref) {
    NSDictionary * dic = (__bridge NSDictionary *)ref;
    CGSize size = [dic[@"size"] CGSizeValue];
    CGFloat descent = [dic[@"descent"] floatValue];
    return size.height - descent;
}

static CGFloat descentCallBacks(void * ref) {
    NSDictionary * dic = (__bridge NSDictionary *)ref;
    CGFloat descent = [dic[@"descent"] floatValue];
    return descent;
}

static CGFloat widthCallBacks(void * ref) {
    NSDictionary * dic = (__bridge NSDictionary *)ref;
    CGSize size = [dic[@"size"] CGSizeValue];
    return size.width;
}

#pragma mark ---method override---

+(Class)layerClass {
    return [DWAsyncLayer class];
}

-(instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _lineSpacing = - 65536;
        _lineBreakMode = NSLineBreakByCharWrapping;
        _reCalculate = YES;
        _reCheck = YES;
        self.backgroundColor = [UIColor clearColor];
        DWAsyncLayer * layer = (DWAsyncLayer *)self.layer;
        layer.contentsScale = [UIScreen mainScreen].scale;
        __weak typeof(self)weakSelf = self;
        layer.displayBlock = ^(CGContextRef context,BOOL(^isCanceled)()){
            [weakSelf drawTheTextWithContext:context isCanceled:isCanceled];
        };
    }
    return self;
}

-(void)setNeedsDisplay {
    [super setNeedsDisplay];
    [self.layer setNeedsDisplay];
}

-(void)sizeToFit {
    CGRect frame = self.frame;
    frame.size = [self sizeThatFits:CGSizeMake(self.bounds.size.width, 10000)];
    self.frame = frame;
}

-(CGSize)sizeThatFits:(CGSize)size {
    ///计算绘制尺寸限制
    CGFloat limitWidth = (size.width - self.textInsets.left - self.textInsets.right) > 0 ? (size.width - self.textInsets.left - self.textInsets.right) : 0;
    CGFloat limitHeight = (size.height - self.textInsets.top - self.textInsets.bottom) > 0 ? (size.height - self.textInsets.top - self.textInsets.bottom) : 0;
    
    ///获取排除区域
    NSArray * exclusionPaths = [self handleExclusionPaths];
    CGRect frame = CGRectMake(self.textInsets.left, self.textInsets.bottom, limitWidth, limitHeight);
    NSDictionary * exclusionConfig = getExclusionDic(exclusionPaths, frame);
    BOOL needDrawString = self.attributedText.length || self.text.length;
    
    NSMutableAttributedString * mAStr = nil;
    if (needDrawString) {
        ///获取要绘制的文本(初步处理，未处理插入图片、句尾省略号、高亮)
        mAStr = getMAStr(self,limitWidth,exclusionPaths);
    }
    CTFramesetterRef frameSetter4Cal = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)mAStr);
    CTFrameRef frame4Cal = CTFramesetterCreateFrame(frameSetter4Cal, CFRangeMake(0, 0), [UIBezierPath bezierPathWithRect:frame].CGPath, (__bridge_retained CFDictionaryRef)exclusionConfig);
    
    
    CFRange visibleRange = getRangeToDrawForVisibleString(frame4Cal);
    
    
    ///处理句尾省略号
    if (needDrawString) {
        CFRange lastRange = getLastLineRange(frame4Cal, self.numberOfLines,visibleRange);
        [self handleLastLineTruncateWithLastLineRange:lastRange attributeString:mAStr];
    }
    
    ///处理插入图片
    if (needDrawString) {
        NSMutableArray * arrInsert = [NSMutableArray array];
        [self.imageArr enumerateObjectsUsingBlock:^(NSDictionary * dic, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([dic[@"drawMode"] integerValue] == DWTextImageDrawModeInsert) {
                [arrInsert addObject:dic];
            }
        }];
        
        if (arrInsert.count) {
            ///富文本插入图片占位符
            [self handleStr:mAStr withInsertImageArr:arrInsert arrLocationImgHasAdd:[NSMutableArray array]];
            ///插入图片后重新处理工厂及frame，添加插入图片后的字符串，消除插入图片影响
            CFSAFERELEASE(frameSetter4Cal)
            CFSAFERELEASE(frame4Cal)
            frameSetter4Cal = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)mAStr);
            frame4Cal = CTFramesetterCreateFrame(frameSetter4Cal, CFRangeMake(0, 0), [UIBezierPath bezierPathWithRect:frame].CGPath, (__bridge_retained CFDictionaryRef)exclusionConfig);
            visibleRange = getRangeToDrawForVisibleString(frame4Cal);
        }
    }
    
    if (exclusionPaths.count == 0) {///如果没有排除区域则使用系统计算函数
        CGSize restrictSize = CGSizeMake(limitWidth, MAXFLOAT);
        if (self.numberOfLines == 1) {
            restrictSize = CGSizeMake(MAXFLOAT, MAXFLOAT);
        }
        CGSize suggestSize = CTFramesetterSuggestFrameSizeWithConstraints(frameSetter4Cal, visibleRange, nil, restrictSize, nil);
        CFSAFERELEASE(frameSetter4Cal);
        CFSAFERELEASE(frame4Cal);
        return CGSizeMake(suggestSize.width + self.textInsets.left + self.textInsets.right, suggestSize.height + self.textInsets.top + self.textInsets.bottom);
    }
    
    ///计算drawFrame及drawPath
    UIBezierPath * drawP = [self handleDrawFrameAndPathWithLimitWidth:limitWidth limitHeight:limitHeight frameSetter:frameSetter4Cal rangeToDraw:visibleRange exclusionPaths:exclusionPaths];
    
    CFSAFERELEASE(frameSetter4Cal)
    CFSAFERELEASE(frame4Cal)
    
    ///绘制的工厂
    CTFramesetterRef frameSetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)mAStr);
    ///绘制范围为可见范围加1，防止末尾省略号失效（由于path为可见尺寸，故仅绘制可见范围时有的时候末尾的省略号会失效，同时不可超过字符串本身长度）
    CFRange drawRange = CFRangeMake(0, visibleRange.length < mAStr.length ? visibleRange.length + 1 : mAStr.length);
    CTFrameRef visibleFrame = CTFramesetterCreateFrame(frameSetter, drawRange, drawP.CGPath, (__bridge_retained CFDictionaryRef)exclusionConfig);
    
    NSArray * arrLines = (NSArray *)CTFrameGetLines(visibleFrame);
    CTLineRef lastLine = (__bridge_retained CTLineRef)arrLines.lastObject;
    CGPoint points[arrLines.count];
    CTFrameGetLineOrigins(visibleFrame, CFRangeMake(0, 0), points);
    CGPoint origin = points[arrLines.count - 1];
    CTRunRef run = (__bridge_retained CTRunRef)((NSArray *)CTLineGetGlyphRuns(lastLine)).lastObject;
    CGRect desFrame = convertRect(getCTRunBounds(visibleFrame, lastLine, origin, run), size.height);
    
    return CGSizeMake(size.width, ceil(desFrame.origin.y + desFrame.size.height + self.textInsets.bottom + self.textInsets.top));
}

-(void)setFrame:(CGRect)frame {
    if (!CGRectEqualToRect(self.frame, frame)) {
        [super setFrame:frame];
        [self handleAutoRedrawWithRecalculate:YES reCheck:NO reDraw:self.autoRedraw];
    }
}

#pragma mark ---setter、getter---
-(void)setText:(NSString *)text {
    if (![_text isEqualToString:text]) {
        _text = text;
        [self handleTextChange];
    }
}

-(void)setTextAlignment:(NSTextAlignment)textAlignment {
    if ((self.exclusionPaths.count == 0) && (_textAlignment != textAlignment)) {
        _textAlignment = textAlignment;
        [self handleAutoRedrawWithRecalculate:YES reCheck:NO reDraw:self.autoRedraw];
    }
}

-(void)setTextVerticalAlignment:(DWTextVerticalAlignment)textVerticalAlignment {
    if ((self.exclusionPaths.count == 0) && (_textVerticalAlignment != textVerticalAlignment)) {
        _textVerticalAlignment = textVerticalAlignment;
        [self handleAutoRedrawWithRecalculate:YES reCheck:NO reDraw:self.autoRedraw];
    }
}

-(UIFont *)font {
    if (!_font) {
        _font = [UIFont systemFontOfSize:17];
    }
    return _font;
}

-(void)setFont:(UIFont *)font {
    _font = font;
    [self handleAutoRedrawWithRecalculate:YES reCheck:NO reDraw:self.autoRedraw];
}

-(void)setTextInsets:(UIEdgeInsets)textInsets {
    if (!UIEdgeInsetsEqualToEdgeInsets(_textInsets, textInsets)) {
        _textInsets = textInsets;
        [self handleAutoRedrawWithRecalculate:YES reCheck:NO reDraw:self.autoRedraw];
    }
}

-(void)setAttributedText:(NSAttributedString *)attributedText {
    if (![_attributedText isEqualToAttributedString:attributedText]) {
        _attributedText = attributedText;
        [self handleTextChange];
    }
}

-(void)setTextColor:(UIColor *)textColor {
    if (!CGColorEqualToColor(_textColor.CGColor,textColor.CGColor)) {
        _textColor = textColor;
        [self handleAutoRedrawWithRecalculate:YES reCheck:NO reDraw:self.autoRedraw];
    }
}

-(UIColor *)textColor {
    if (!_textColor) {
        _textColor = [UIColor blackColor];
    }
    return _textColor;
}

-(void)setLineSpacing:(CGFloat)lineSpacing {
    if (_lineSpacing != lineSpacing) {
        _lineSpacing = lineSpacing;
        [self handleAutoRedrawWithRecalculate:YES reCheck:NO reDraw:self.autoRedraw];
    }
}

-(CGFloat)lineSpacing {
    if (_lineSpacing == -65536) {
        return 5.5;
    }
    return _lineSpacing;
}

-(NSArray<UIBezierPath *> *)exclusionPaths {
    if (!_exclusionPaths) {
        _exclusionPaths = [NSArray array];
    }
    return _exclusionPaths;
}

-(void)setExclusionPaths:(NSArray<UIBezierPath *> *)exclusionPaths {
    _exclusionPaths = exclusionPaths;
    [self handleAutoRedrawWithRecalculate:YES reCheck:NO reDraw:self.autoRedraw];
}

-(void)setNumberOfLines:(NSUInteger)numberOfLines {
    if (_numberOfLines != numberOfLines) {
        _numberOfLines = numberOfLines;
        [self handleAutoRedrawWithRecalculate:YES reCheck:NO reDraw:self.autoRedraw];
    }
}

-(void)setLineBreakMode:(NSLineBreakMode)lineBreakMode {
    if (_lineBreakMode != lineBreakMode) {
        _lineBreakMode = lineBreakMode;
        [self handleAutoRedrawWithRecalculate:YES reCheck:YES reDraw:self.autoRedraw];
    }
}

-(void)setAutoCheckLink:(BOOL)autoCheckLink {
    if (_autoCheckLink != autoCheckLink) {
        _autoCheckLink = autoCheckLink;
        self.reCalculate = YES;
        self.reCheck = YES;
        [self setNeedsDisplay];
    }
}

-(void)setAutoCheckConfig:(NSMutableDictionary *)autoCheckConfig {
    _autoCheckConfig = autoCheckConfig;
    if (self.autoCheckLink) {
        [self handleAutoRedrawWithRecalculate:YES reCheck:YES reDraw:self.autoRedraw];
    }
}

-(NSMutableDictionary *)autoCheckConfig {
    return self.autoCheckLink?(_autoCheckConfig?_autoCheckConfig:[NSMutableDictionary dictionaryWithDictionary:@{@"phoneNo":@"(1[34578]\\d{9}|(0[\\d]{2,3}-)?([2-9][\\d]{6,7})(-[\\d]{1,4})?)",@"email":@"[A-Za-z\\d]+([-_.][A-Za-z\\d]+)*@([A-Za-z\\d]+[-.])*([A-Za-z\\d]+[.])+[A-Za-z\\d]{2,5}",@"URL":@"((http|ftp|https)://)?((([a-zA-Z0-9]+[a-zA-Z0-9_-]*\\.)+[a-zA-Z]{2,6})|(([0-9]{1,3}\\.){3}[0-9]{1,3}(:[0-9]{1,4})?))((/[a-zA-Z\\d_]+)*(\\?([a-zA-Z\\d_]+=[a-zA-Z\\d\\u4E00-\\u9FA5\\s\\+%#_-]+&)*([a-zA-Z\\d_]+=[a-zA-Z\\d\\u4E00-\\u9FA5\\s\\+%#_-]+))?)?",@"naturalNum":@"\\d+(\\.\\d+)?"}]):nil;
}

-(void)setCustomLinkRegex:(NSString *)customLinkRegex {
    if (![_customLinkRegex isEqualToString:customLinkRegex]) {
        _customLinkRegex = customLinkRegex;
        [self handleAutoRedrawWithRecalculate:YES reCheck:YES reDraw:self.autoRedraw];
    }
}

#pragma mark ---链接属性setter、getter---
-(void)setActiveTextAttributes:(NSDictionary *)activeTextAttributes {
    _activeTextAttributes = activeTextAttributes;
    [self handleAutoRedrawWithRecalculate:NO reCheck:NO reDraw:self.autoRedraw];
}

-(void)setActiveTextHighlightAttributes:(NSDictionary *)activeTextHighlightAttributes {
    _activeTextHighlightAttributes = activeTextHighlightAttributes;
    [self handleAutoRedrawWithRecalculate:NO reCheck:NO reDraw:self.autoRedraw];
}

-(void)setNaturalNumAttributes:(NSDictionary *)naturalNumAttributes {
    _naturalNumAttributes = naturalNumAttributes;
    if (self.autoCheckLink) {
        [self handleAutoRedrawWithRecalculate:NO reCheck:NO reDraw:self.autoRedraw];
    }
}

-(NSDictionary *)naturalNumAttributes {
    return self.autoCheckLink?(_naturalNumAttributes?_naturalNumAttributes:DWDefaultAttributes):nil;
}

-(void)setNaturalNumHighlightAttributes:(NSDictionary *)naturalNumHighlightAttributes {
    _naturalNumHighlightAttributes = naturalNumHighlightAttributes;
    if (self.autoCheckLink) {
        [self handleAutoRedrawWithRecalculate:NO reCheck:NO reDraw:self.autoRedraw];
    }
}

-(NSDictionary *)naturalNumHighlightAttributes {
    return self.autoCheckLink?(_naturalNumHighlightAttributes?_naturalNumHighlightAttributes:DWDefaultHighlightAttributes):nil;
}

-(void)setPhoneNoAttributes:(NSDictionary *)phoneNoAttributes {
    _phoneNoAttributes = phoneNoAttributes;
    if (self.autoCheckLink) {
        [self handleAutoRedrawWithRecalculate:NO reCheck:NO reDraw:self.autoRedraw];
    }
}

-(NSDictionary *)phoneNoAttributes {
    return self.autoCheckLink?(_phoneNoAttributes?_phoneNoAttributes:DWDefaultAttributes):nil;
}

-(void)setPhoneNoHighlightAttributes:(NSDictionary *)phoneNoHighlightAttributes {
    _phoneNoHighlightAttributes = phoneNoHighlightAttributes;
    if (self.autoCheckLink) {
        [self handleAutoRedrawWithRecalculate:NO reCheck:NO reDraw:self.autoRedraw];
    }
}

-(NSDictionary *)phoneNoHighlightAttributes {
    return self.autoCheckLink?(_phoneNoHighlightAttributes?_phoneNoHighlightAttributes:DWDefaultHighlightAttributes):nil;
}

-(void)setURLAttributes:(NSDictionary *)URLAttributes {
    _URLAttributes = URLAttributes;
    if (self.autoCheckLink) {
        [self handleAutoRedrawWithRecalculate:NO reCheck:NO reDraw:self.autoRedraw];
    }
}

-(NSDictionary *)URLAttributes {
    return self.autoCheckLink?(_URLAttributes?_URLAttributes:DWDefaultAttributes):nil;
}

-(void)setURLHighlightAttributes:(NSDictionary *)URLHighlightAttributes {
    _URLHighlightAttributes = URLHighlightAttributes;
    if (self.autoCheckLink) {
        [self handleAutoRedrawWithRecalculate:NO reCheck:NO reDraw:self.autoRedraw];
    }
}

-(NSDictionary *)URLHighlightAttributes {
    return self.autoCheckLink?(_URLHighlightAttributes?_URLHighlightAttributes:DWDefaultHighlightAttributes):nil;
}


-(void)setEmailAttributes:(NSDictionary *)emailAttributes {
    _emailAttributes = emailAttributes;
    if (self.autoCheckLink) {
        [self handleAutoRedrawWithRecalculate:NO reCheck:NO reDraw:self.autoRedraw];
    }
}

-(NSDictionary *)emailAttributes {
    return self.autoCheckLink?(_emailAttributes?_emailAttributes:DWDefaultAttributes):nil;
}

-(void)setEmailHighlightAttributes:(NSDictionary *)emailHighlightAttributes {
    _emailHighlightAttributes = emailHighlightAttributes;
    if (self.autoCheckLink) {
        [self handleAutoRedrawWithRecalculate:NO reCheck:NO reDraw:self.autoRedraw];
    }
}

-(NSDictionary *)emailHighlightAttributes {
    return self.autoCheckLink?(_emailHighlightAttributes?_emailHighlightAttributes:DWDefaultHighlightAttributes):nil;
}

-(void)setCustomLinkAttributes:(NSDictionary *)customLinkAttributes {
    _customLinkAttributes = customLinkAttributes;
    [self handleAutoRedrawWithRecalculate:NO reCheck:NO reDraw:self.autoRedraw];
}

-(NSDictionary *)customLinkAttributes {
    return (self.customLinkRegex.length > 0)?(_customLinkAttributes?_customLinkAttributes:DWDefaultAttributes):nil;
}

-(void)setCustomLinkHighlightAttributes:(NSDictionary *)customLinkHighlightAttributes {
    _customLinkHighlightAttributes = customLinkHighlightAttributes;
    [self handleAutoRedrawWithRecalculate:NO reCheck:NO reDraw:self.autoRedraw];
}

-(NSDictionary *)customLinkHighlightAttributes {
    return (self.customLinkRegex.length > 0)?(_customLinkHighlightAttributes?_customLinkHighlightAttributes:DWDefaultHighlightAttributes):nil;
}

-(dispatch_queue_t)syncQueue {
    if (!_syncQueue) {
        _syncQueue = dispatch_queue_create("com.syncQueue.DWCoreTextLabel", DISPATCH_QUEUE_CONCURRENT);
    }
    return _syncQueue;
}

#pragma mark ---中间容器属性setter、getter---
-(NSMutableArray *)imageArr
{
    if (!_imageArr) {
        _imageArr = [NSMutableArray array];
    }
    return _imageArr;
}
    
-(NSMutableDictionary<NSString *,NSMutableArray *> *)placeHolderDic {
    if (!_placeHolderDic) {
        _placeHolderDic = [NSMutableDictionary dictionary];
    }
    return _placeHolderDic;
}

-(NSMutableArray *)imageExclusion
{
    if (!_imageExclusion) {
        _imageExclusion = [NSMutableArray array];
    }
    return _imageExclusion;
}

-(NSMutableArray *)arrLocationImgHasAdd
{
    if (!_arrLocationImgHasAdd) {
        _arrLocationImgHasAdd = [NSMutableArray array];
    }
    return _arrLocationImgHasAdd;
}

-(NSMutableArray *)textRangeArr
{
    if (!_textRangeArr) {
        _textRangeArr = [NSMutableArray array];
    }
    return _textRangeArr;
}

-(NSMutableArray *)activeTextArr
{
    if (!_activeTextArr) {
        _activeTextArr = [NSMutableArray array];
    }
    return _activeTextArr;
}

-(NSMutableArray *)autoLinkArr
{
    if (!_autoLinkArr) {
        _autoLinkArr = [NSMutableArray array];
    }
    return _autoLinkArr;
}

-(NSMutableArray *)exclusionP
{
    return [[NSMutableArray alloc] initWithArray:self.exclusionPaths copyItems:YES];
}


-(NSMutableDictionary *)autoCheckLinkDic
{
    if (!_autoCheckLinkDic) {
        _autoCheckLinkDic = [NSMutableDictionary dictionary];
    }
    return _autoCheckLinkDic;
}

-(NSMutableDictionary *)customLinkDic
{
    if (!_customLinkDic) {
        _customLinkDic = [NSMutableDictionary dictionary];
    }
    return _customLinkDic;
}

@end
