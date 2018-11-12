//
//  CarUtilities.m
//  QLCARFiles
//
//  Created by Alexandre Colucci.
//  Copyright © 2018 blog.timac.org. All rights reserved.
//

#import "CarUtilities.h"
#import "CoreUI.h"
#import "ImageUtilities.h"

//
// Keys used by the CarNamedLookupDict dictionary
//
NSString * const kCarInfoDict_FilenameKey = @"kCarInfoDict_FilenameKey";
NSString * const kCarInfoDict_DisplayNameKey = @"kCarInfoDict_DisplayNameKey";
NSString * const kCarInfoDict_DescriptionKey = @"kCarInfoDict_DescriptionKey";
NSString * const kCarInfoDict_IsMultisizeImageKey = @"kCarInfoDict_IsMultisizeImageKey";
NSString * const kCarInfoDict_CGImageKey = @"kCarInfoDict_CGImageKey";
NSString * const kCarInfoDict_UTITypeKey = @"kCarInfoDict_UTITypeKey";
NSString * const kCarInfoDict_DataKey = @"kCarInfoDict_DataKey";

//
// Find the best filename for a CUINamedLookup
//
NSString *GetFileNameForNamedLookup(CUINamedLookup * inNamedLookup)
{
	NSMutableString *fileName = [[inNamedLookup name] mutableCopy];
	
	//
	// appearance
	//
	NSString *appearance = inNamedLookup.appearance;
	if([appearance length] > 0)
	{
		if([appearance hasPrefix:@"NSAppearanceName"])
		{
			appearance = [appearance substringFromIndex:[@"NSAppearanceName" length]];
		}
		
		if([appearance hasSuffix:@"System"])
		{
			appearance = [appearance substringToIndex:[appearance length] - [@"System" length]];
		}
		
		if([appearance length] > 0)
		{
			[fileName appendFormat:@"~%@", appearance];
		}
	}
	
	//
	// graphicsClass
	//
	if(inNamedLookup.graphicsClass >= kCoreThemeFeatureSetMetalFamilyDefault && inNamedLookup.graphicsClass < kCoreThemeFeatureSetMetalFamilyMax)
	{
		NSString *coreThemeFeatureSetMetalFamilySuffix = [NSString stringWithUTF8String:kCoreThemeFeatureSetMetalFamilyNames[inNamedLookup.graphicsClass]];
		if([coreThemeFeatureSetMetalFamilySuffix length] > 0)
		{
			[fileName appendFormat:@"~%@", coreThemeFeatureSetMetalFamilySuffix];
		}
	}
	
	//
	// memoryClass
	//
	if(inNamedLookup.memoryClass >= kCoreThemeMemoryClassLow && inNamedLookup.memoryClass < kCoreThemeMemoryClassMax)
	{
		NSString *coreThemeMemoryClassSuffix = [NSString stringWithUTF8String:kCoreThemeMemoryClassNames[inNamedLookup.memoryClass]];
		if([coreThemeMemoryClassSuffix length] > 0)
		{
			[fileName appendFormat:@"~%@", coreThemeMemoryClassSuffix];
		}
	}
	
	//
	// idiom
	//
	if(inNamedLookup.idiom >= kCoreThemeIdiomUniversal && inNamedLookup.idiom < kCoreThemeIdiomMax)
	{
		NSString *coreThemeIdiomSuffix = [NSString stringWithUTF8String:kCoreThemeIdiomNames[inNamedLookup.idiom]];
		if([coreThemeIdiomSuffix length] > 0)
		{
			[fileName appendFormat:@"~%@", coreThemeIdiomSuffix];
		}
	}
	
	//
	// subtype
	//
	if(inNamedLookup.subtype > 0)
	{
		NSString *subTypeSuffix = [NSString stringWithFormat:@"%llu", inNamedLookup.subtype];
		if([subTypeSuffix length] > 0)
		{
			[fileName appendFormat:@"~%@", subTypeSuffix];
		}
	}
	
	//
	// sizeClassHorizontal and sizeClassVertical
	//
	if ((inNamedLookup.sizeClassHorizontal > kCoreThemeUISizeClassUnspecified) || (inNamedLookup.sizeClassVertical > kCoreThemeUISizeClassUnspecified))
	{
		NSString *horizontalString = @"unknown";
		NSString *verticalString = @"unknown";
		
		if(inNamedLookup.sizeClassHorizontal < kCoreThemeUISizeClassMax)
		{
			horizontalString = [NSString stringWithUTF8String:kCoreThemeUISizeClassNames[inNamedLookup.sizeClassHorizontal]];
		}
		
		if(inNamedLookup.sizeClassVertical < kCoreThemeUISizeClassMax)
		{
			verticalString = [NSString stringWithUTF8String:kCoreThemeUISizeClassNames[inNamedLookup.sizeClassVertical]];
		}
		
		[fileName appendFormat:@"%@", [NSString stringWithFormat:@"~%@x%@", horizontalString, verticalString]];
	}
	
	//
	// displayGamut
	//
	if(inNamedLookup.displayGamut > kCoreThemeDisplayGamutSRGB)
	{
		if(inNamedLookup.displayGamut < kCoreThemeDisplayGamutMax)
		{
			NSString *coreThemeDisplayGamutSuffix = [NSString stringWithUTF8String:kCoreThemeDisplayGamutNames[inNamedLookup.displayGamut]];
			if([coreThemeDisplayGamutSuffix length] > 0)
			{
				[fileName appendFormat:@"~%@", coreThemeDisplayGamutSuffix];
			}
		}
		else
		{
			[fileName appendFormat:@"%@", [NSString stringWithFormat:@"~UnknownGamut"]];
		}
	}
	
	return fileName;
}

//
// Function to process a car file
//
BOOL ProcessCarFileAtPath(NSString *inCarPath, NSString *inOutputFolder, CarNamedLookupBlock namedLookupsCallback)
{
	//
	// Create the CUICatalog
	//
	NSError *error = nil;
	CUICatalog *catalog = [[CUICatalog alloc] initWithURL:[NSURL fileURLWithPath:inCarPath] error:&error];
	if(catalog == nil)
	{
		if(error != nil)
		{
			NSLog(@"Could not load %@ due to the error: %@", inCarPath, error);
		}
		
		return NO;
	}
	
	//
	// Ensure this is a supported car file. car files of pro applications are not supported
	//
	CUICommonAssetStorage *themeStore = [[catalog _themeStore] themeStore];
	const char *versionString = [themeStore versionString];
	if(versionString != NULL)
	{
		NSString *version = [NSString stringWithCString:versionString encoding:NSUTF8StringEncoding];
		if(![version hasPrefix:@"IBCocoaTouchImageCatalogTool-"] && ![version hasPrefix:@"ibtoold-"])
		{
			// Unsupported car file
			return NO;
		}
	}
	
	// List of CUINamedMultisizeImageSet to force use the image size when we later find the corresponding CUINamedImage
	__block NSMutableArray<NSString *> * multisizeImageNames = [[NSMutableArray alloc] init];
	
	//
	// Enumerate the CUINamedLookup in the car file
	//
	[catalog enumerateNamedLookupsUsingBlock:^(CUINamedLookup *namedLookup)
	{
		@autoreleasepool
		{
			NSMutableDictionary<NSString *, id> *carNamedLookupDict = [[NSMutableDictionary alloc] init];
			
			//
			// Default filename
			//
			NSString *renditionName = [namedLookup renditionName];
			if([renditionName isEqualToString:@"CoreStructuredImage"])
			{
				renditionName = [namedLookup name];
			}
			
			if([renditionName length] > 0)
			{
				carNamedLookupDict[kCarInfoDict_FilenameKey] = renditionName;
			}
			
			//
			// For multisize images like application icons, we always want to display the image size in the filename
			//
			if([multisizeImageNames containsObject:[namedLookup name]])
			{
				carNamedLookupDict[kCarInfoDict_IsMultisizeImageKey] = @YES;
			}
			
			//
			// Namespaces
			//
			NSString *destinationFolder = inOutputFolder;
			NSString *assetName = [namedLookup name];
			NSArray* pathComponents = [assetName pathComponents];
			if (pathComponents.count > 1)
			{
				for(NSUInteger pathComponentIndex = 0 ; pathComponentIndex < ([pathComponents count] - 1) ; pathComponentIndex++)
				{
					NSString *pathComponent = pathComponents[pathComponentIndex];
					destinationFolder = [destinationFolder stringByAppendingPathComponent:pathComponent];
				}
				
				[[NSFileManager defaultManager] createDirectoryAtPath:destinationFolder withIntermediateDirectories:YES attributes:nil error:nil];
			}
			
			BOOL ignoreAsset = NO;
			
			//
			// Handle each type of CUINamedLookup subclasses
			//
			if ([namedLookup isKindOfClass:[CUINamedImage class]])
			{
				CUINamedImage *asset = (CUINamedImage *)namedLookup;
				CGImageRef cgImage = asset.image;
				if(cgImage != NULL)
				{
					carNamedLookupDict[kCarInfoDict_CGImageKey] = (__bridge id)(cgImage);
				}
				
				NSString *fileName = GetFileNameForNamedLookup(asset);
				if([fileName containsString:@"/"])
				{
					// If the asset's name contains a '/',
					// we should use the renditionName
					fileName = renditionName;
				}
				else
				{
					// Image specific filename information
					NSString *scale = asset.scale > 1.0 ? [NSString stringWithFormat:@"@%dx", (int)floor(asset.scale)] : @"";
					if([scale length] > 0)
					{
						fileName = [NSString stringWithFormat:@"%@%@", fileName, scale];
					}
					
					fileName = [NSString stringWithFormat:@"%@.png", fileName];
				}
				
				carNamedLookupDict[kCarInfoDict_FilenameKey] = fileName;
			}
			else if([namedLookup isKindOfClass:[CUINamedData class]])
			{
				CUINamedData *asset = (CUINamedData *)namedLookup;
				
				// Update fileName
				NSString *fileName = renditionName;
				NSString *utiType = [asset utiType];
				if([utiType length] > 0)
				{
					NSString *preferredExtension = CFBridgingRelease(UTTypeCopyPreferredTagWithClass((__bridge CFStringRef _Nonnull)(utiType), kUTTagClassFilenameExtension));
					if([preferredExtension length] > 0)
					{
						fileName = [[fileName stringByDeletingPathExtension] stringByAppendingPathExtension:preferredExtension];
					}
				}
				else
				{
					NSString *pathExtension = [fileName pathExtension];
					if([pathExtension length] > 0)
					{
						utiType = CFBridgingRelease(UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef _Nonnull)(pathExtension), nil));
					}
				}
				
				if([fileName length] > 0)
				{
					carNamedLookupDict[kCarInfoDict_FilenameKey] = fileName;
				}
				
				if([utiType length] > 0)
				{
					carNamedLookupDict[kCarInfoDict_UTITypeKey] = utiType;
				}
			
				if(asset.data != NULL)
				{
					carNamedLookupDict[kCarInfoDict_DataKey] = asset.data;
				}
			}
			else if([namedLookup isKindOfClass:[CUINamedLayerStack class]])
			{
				CUINamedLayerStack *asset = (CUINamedLayerStack *)namedLookup;
				
				CGImageRef cgImage = asset.flattenedImage;
				if(cgImage != NULL)
				{
					carNamedLookupDict[kCarInfoDict_CGImageKey] = (__bridge id)(cgImage);
				}
			}
			else if([namedLookup isKindOfClass:[CUINamedImageAtlas class]])
			{
				// Each atlas image appears as a CUINamedImage.
				// CUINamedImageAtlas doesn't seem to contain any image itself.
				// You can find some example of .spriteatlas
				// in the sample code DemoBots.
				
				CUINamedImageAtlas *asset = (CUINamedImageAtlas *)namedLookup;
				CGImageRef cgImage = asset.image;
				if(cgImage != NULL)
				{
					carNamedLookupDict[kCarInfoDict_CGImageKey] = (__bridge id)(cgImage);
				}
			}
			else if([namedLookup isKindOfClass:[CUINamedExternalLink class]])
			{
				// Never seen
				// CUINamedExternalLink *asset = (CUINamedExternalLink *)namedLookup;
				
				NSLog(@"CUINamedExternalLink is not supported!");
				ignoreAsset = YES;
			}
			else if([namedLookup isKindOfClass:[CUINamedTexture class]])
			{
				// Never seen
				// CUINamedTexture *asset = (CUINamedTexture *)namedLookup;
				
				NSLog(@"CUINamedTexture is not supported!");
				ignoreAsset = YES;
			}
			else if([namedLookup isKindOfClass:[CUINamedModel class]])
			{
				// Never seen
				// CUINamedModel *asset = (CUINamedModel *)namedLookup;
				
				NSLog(@"CUINamedModel is not supported!");
				ignoreAsset = YES;
			}
			else if([namedLookup isKindOfClass:[CUINamedRecognitionImage class]])
			{
				// Never seen
				// CUINamedRecognitionImage *asset = (CUINamedRecognitionImage *)namedLookup;
				
				NSLog(@"CUINamedRecognitionImage is not supported!");
				ignoreAsset = YES;
			}
			else if([namedLookup isKindOfClass:[CUINamedRecognitionGroup class]])
			{
				// Never seen
				// CUINamedRecognitionGroup *asset = (CUINamedRecognitionGroup *)namedLookup;
				
				NSLog(@"CUINamedRecognitionGroup is not supported!");
				ignoreAsset = YES;
			}
			else if([namedLookup isKindOfClass:[CUINamedRecognitionObject class]])
			{
				// Never seen
				// CUINamedRecognitionObject *asset = (CUINamedRecognitionObject *)namedLookup;
				
				NSLog(@"CUINamedRecognitionObject is not supported!");
				ignoreAsset = YES;
			}
			else if([namedLookup isKindOfClass:[CUINamedVectorImage class]])
			{
				// Never seen
				// CUINamedVectorImage *asset = (CUINamedVectorImage *)namedLookup;
				
				NSLog(@"CUINamedVectorImage is not supported!");
				ignoreAsset = YES;
			}
			else if([namedLookup isKindOfClass:[CUINamedMultisizeImage class]])
			{
				// Never seen
				// CUINamedMultisizeImage *asset = (CUINamedMultisizeImage *)namedLookup;
				
				NSLog(@"CUINamedMultisizeImage is not supported!");
				ignoreAsset = YES;
			}
			else if([namedLookup isKindOfClass:[CUINamedMultisizeImageSet class]])
			{
				// This is used for icons for example when you provide multiple size.
				// The images appear as CUINamedImage and we handle duplicated name,
				// so we don't need to handle this class.
				//
				// CUINamedMultisizeImageSet *asset = (CUINamedMultisizeImageSet *)namedLookup;
				// NSArray *sizeIndexes = asset.sizeIndexes;
				
				[multisizeImageNames addObject:[namedLookup name]];
				
				// Ignore CUINamedMultisizeImageSet
				ignoreAsset = YES;
			}
			else if([namedLookup isKindOfClass:[CUINamedLayerImage class]])
			{
				// Never seen
				// CUINamedLayerImage *asset = (CUINamedLayerImage *)namedLookup;
				
				NSLog(@"CUINamedLayerImage is not supported!");
				ignoreAsset = YES;
			}
			else if([namedLookup isKindOfClass:[CUINamedColor class]])
			{
				CUINamedColor *asset = (CUINamedColor *)namedLookup;
				CGColorRef cgColor = asset.cgColor;
				if(cgColor != NULL)
				{
					NSString *fileName = GetFileNameForNamedLookup(asset);
					if([fileName containsString:@"/"])
					{
						// If the asset's name contains a '/',
						// we should use the renditionName
						fileName = renditionName;
					}
					else
					{
						fileName = [NSString stringWithFormat:@"%@.png", fileName];
					}
					
					carNamedLookupDict[kCarInfoDict_FilenameKey] = fileName;
					
					// For the QuickLook plugin where we don't want to display the .png extension
					carNamedLookupDict[kCarInfoDict_DisplayNameKey] = [fileName stringByDeletingPathExtension];
					
					// In the description of the QuickLook plugin, we want to display the color
					NSString *colorDescription = nil;
					size_t numberOfComponents = CGColorGetNumberOfComponents(cgColor);
					if(numberOfComponents > 0)
					{
						colorDescription = @"#";
						const CGFloat* components = CGColorGetComponents(cgColor);
						for(size_t componentIndex = 0 ; componentIndex < numberOfComponents ; componentIndex++)
						{
							colorDescription = [colorDescription stringByAppendingFormat:@"%02X", (int)(components[componentIndex] * 255)];
						}
					}
					
					if([colorDescription length] > 0)
					{
						carNamedLookupDict[kCarInfoDict_DescriptionKey] = colorDescription;
					}
					else
					{
						carNamedLookupDict[kCarInfoDict_DescriptionKey] = @"";
					}
					
					
					// Create an image filled with the color
					CGImageRef imageRef = CreateImageWithColor(cgColor, CGSizeMake(PREVIEW_MAX_WIDTH, PREVIEW_MAX_HEIGHT));
					if(imageRef != NULL)
					{
						carNamedLookupDict[kCarInfoDict_CGImageKey] = (__bridge_transfer id)(imageRef);
					}
				}
			}
			else
			{
				NSLog(@"%@ is not supported!", NSStringFromClass([namedLookup class]));
				ignoreAsset = YES;
			}
			
			if(!ignoreAsset)
			{
				namedLookupsCallback(destinationFolder, carNamedLookupDict);
			}
		}
	}];
	
	return YES;
}
