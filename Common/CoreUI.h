//
//  CoreUI.h
//  QLCARFiles
//
//  Created by Alexandre Colucci.
//  Copyright © 2018 blog.timac.org. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>


// MARK: - kCoreThemeIdiom

typedef NS_ENUM(NSInteger, kCoreThemeIdiom)
{
	kCoreThemeIdiomUniversal = 0,
	kCoreThemeIdiomPhone,
	kCoreThemeIdiomPad,
	kCoreThemeIdiomTV,
	kCoreThemeIdiomCar,
	kCoreThemeIdiomWatch,
	kCoreThemeIdiomMarketing,
	
	kCoreThemeIdiomMax
};

static const char* const kCoreThemeIdiomNames[kCoreThemeIdiomMax] = { "", "phone", "pad", "tv", "car", "watch", "marketing" };


// MARK: - kCoreThemeFeatureSetMetalFamily

typedef NS_ENUM(NSInteger, kCoreThemeFeatureSetMetalFamily)
{
    kCoreThemeFeatureSetMetalFamilyDefault  = 0,
    kCoreThemeFeatureSetMetalFamily1v2,
    kCoreThemeFeatureSetMetalFamily2v2,
    kCoreThemeFeatureSetMetalFamily3v1,
    kCoreThemeFeatureSetMetalFamily3v2,
    kCoreThemeFeatureSetMetalFamily4v1,
    kCoreThemeFeatureSetMetalFamily5v1,
	
    kCoreThemeFeatureSetMetalFamilyMax
};

static const char* const kCoreThemeFeatureSetMetalFamilyNames[kCoreThemeFeatureSetMetalFamilyMax] = { "", "MTL1,2", "MTL2,2", "MTL3,1", "MTL3,2", "MTL4,1", "MTL5,1" };


// MARK: - kCoreThemeMemoryClass

typedef NS_ENUM(NSInteger, kCoreThemeMemoryClass)
{
    kCoreThemeMemoryClassLow = 0,
    kCoreThemeMemoryClass1GB,
    kCoreThemeMemoryClass2GB,
    kCoreThemeMemoryClass4GB,
    kCoreThemeMemoryClass3GB,
    kCoreThemeMemoryClass6GB,
	
    kCoreThemeMemoryClassMax
};

static const char* const kCoreThemeMemoryClassNames[kCoreThemeMemoryClassMax] = { "", "1GB", "2GB", "4GB", "3GB", "6GB" };


// MARK: - kCoreThemeUISizeClass

typedef NS_ENUM(NSInteger, kCoreThemeUISizeClass)
{
	kCoreThemeUISizeClassUnspecified = 0,
	kCoreThemeUISizeClassCompact,
	kCoreThemeUISizeClassRegular,
	
	kCoreThemeUISizeClassMax
};

static const char* const kCoreThemeUISizeClassNames[kCoreThemeUISizeClassMax] = { "", "compact", "regular" };


// MARK: - kCoreThemeDisplayGamut

typedef NS_ENUM(NSInteger, kCoreThemeDisplayGamut)
{
    kCoreThemeDisplayGamutSRGB = 0,
    kCoreThemeDisplayGamutP3,
	
    kCoreThemeDisplayGamutMax
};

static const char* const kCoreThemeDisplayGamutNames[kCoreThemeDisplayGamutMax] = { "sRGB", "P3" };


// MARK: - CUICommonAssetStorage

@interface CUICommonAssetStorage : NSObject

- (const char *)versionString;

@end


// MARK: - CUIStructuredThemeStore

@interface CUIStructuredThemeStore : NSObject

@property (readonly) CUICommonAssetStorage *themeStore;

@end


// MARK: - CUINamedLookup

@interface CUINamedLookup : NSObject

@property(readonly) NSString *name;
@property(readonly) NSString *renditionName;

@property(readonly) kCoreThemeIdiom idiom;
@property(readonly) uint64_t subtype;
@property(readonly) kCoreThemeUISizeClass sizeClassHorizontal;
@property(readonly) kCoreThemeUISizeClass sizeClassVertical;
@property(readonly) kCoreThemeFeatureSetMetalFamily graphicsClass;
@property(readonly) kCoreThemeMemoryClass memoryClass;
@property(readonly) kCoreThemeDisplayGamut displayGamut;
@property(readonly) NSString *appearance;

@end


// MARK: - CUICatalog

@interface CUICatalog : NSObject

- (id)initWithURL:(NSURL *)url error:(NSError **)error;
- (void)enumerateNamedLookupsUsingBlock:(void (^)(CUINamedLookup *namedLookup))block;

- (CUIStructuredThemeStore *)_themeStore;

@end


// MARK: - CUINamedImage

@interface CUINamedImage : CUINamedLookup

@property(readonly) CGSize size;
@property(readonly) CGFloat scale;

-(CGImageRef)image;

@end


// MARK: - CUINamedData

@interface CUINamedData : CUINamedLookup

@property (readonly, copy, nonatomic) NSString * utiType;
@property (readonly, copy, nonatomic) NSData * data;

@end


// MARK: - CUINamedLayerStack

@interface CUINamedLayerStack : CUINamedLookup

@property (retain, nonatomic) NSArray * layers;
@property (readonly, nonatomic) CGSize size;
@property (readonly, nonatomic) CGImageRef flattenedImage;
@property (readonly, nonatomic) CGImageRef radiosityImage;

@end


// MARK: - CUINamedImageAtlas

@interface CUINamedImageAtlas : CUINamedLookup

@property (readonly, nonatomic) CGImageRef image;
@property (readonly, nonatomic) NSArray * images;
@property (readonly, nonatomic) double scale;
@property (readonly, nonatomic) NSArray * imageNames;
@property (readonly, nonatomic) BOOL completeTextureExtrusion;

@end


// MARK: - CUINamedExternalLink

@interface CUINamedExternalLink : CUINamedLookup

@property (readonly, nonatomic) NSString * assetPackIdentifier;

@end


// MARK: - CUINamedTexture

@interface CUINamedTexture : CUINamedLookup

@property (readonly, nonatomic) CGSize size;
@property (readonly, nonatomic) double scale;
@property (readonly, nonatomic) int exifOrientation;
@property (readonly, nonatomic) BOOL isOpaque;
@property (readonly, nonatomic) BOOL isAlphaCropped;

@end


// MARK: - CUINamedColor

@interface CUINamedColor : CUINamedLookup

@property (readonly, nonatomic) CGColorRef cgColor;
@property (readonly, nonatomic) NSString *systemColorName;

@end


// MARK: - CUINamedModel

@interface CUINamedModel : CUINamedLookup
@end


// MARK: - CUINamedRecognitionImage

@interface CUINamedRecognitionImage : CUINamedLookup

@property (readonly, nonatomic) CGImageRef image;
@property (readonly, nonatomic) CGSize physicalSizeInMeters;

@end


// MARK: - CUINamedRecognitionGroup

@interface CUINamedRecognitionGroup : CUINamedLookup

- (id)namedRecognitionItemList;
- (id)namedRecognitionImageImageList;
- (id)namedRecognitionObjectObjectList;

@end


// MARK: - CUINamedRecognitionObject

@interface CUINamedRecognitionObject : CUINamedLookup

@property (readonly, nonatomic) int64_t version;
@property (readonly, nonatomic) NSData * objectData;

@end


// MARK: - CUINamedVectorImage

@interface CUINamedVectorImage : CUINamedLookup

@property (readonly, nonatomic) CGPDFDocumentRef pdfDocument;
@property (readonly, nonatomic) double scale;
@property (readonly, nonatomic) int64_t layoutDirection;

@end


// MARK: - CUINamedMultisizeImage

@interface CUINamedMultisizeImage : CUINamedImage

@property (nonatomic, assign) CGSize nextSizeSmaller;

@end


// MARK: - CUINamedMultisizeImageSet

@interface CUINamedMultisizeImageSet : CUINamedLookup

@property (readonly, nonatomic) NSArray * sizeIndexes;

@end


// MARK: - CUINamedLayerImage

@interface CUINamedLayerImage : CUINamedImage

@property (nonatomic, assign) CGRect frame;
@property (nonatomic, assign) double opacity;
@property (nonatomic, assign) int blendMode;
@property (nonatomic, assign) BOOL fixedFrame;

@end
