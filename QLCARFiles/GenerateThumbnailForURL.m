//
//  GenerateThumbnailForURL.m
//  QLCARFiles
//
//  Created by Alexandre Colucci.
//  Copyright © 2018 blog.timac.org. All rights reserved.
//

#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#include <AppKit/AppKit.h>

#import "CoreUI.h"
#import "CarUtilities.h"
#import "ImageUtilities.h"

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize);
void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail);

double AspectRatioForSize(CGSize inSize)
{
	double outAspectRatio = 0.0;
	if(inSize.height > 0)
	{
		outAspectRatio = inSize.width / inSize.height;
	}
	
	return outAspectRatio;
}

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize)
{
	// Count the number of assets
	__block NSUInteger numberOfAssets = 0;
	__block NSImage *bestImageFound = nil;
	__block CGSize bestImageSize = CGSizeZero;
	
	BOOL canExtractCAR = ProcessCarFileAtPath([(__bridge NSURL *)url path], nil, ^(NSString *inOutputFolder, CarNamedLookupDict carNamedLookupDict)
	{
		if(carNamedLookupDict != nil)
		{
			NSString *fileName = carNamedLookupDict[kCarInfoDict_FilenameKey];
			if([fileName hasPrefix:@"ZZZZExplicitlyPackedAsset-"] ||
					[fileName hasPrefix:@"ZZZZPackedAsset-"] ||
					[fileName hasPrefix:@"ZZZZFlattenedImage-"] ||
					[fileName hasPrefix:@"ZZZZRadiosityImage-"])
			{
				// Ignore assets like:
				// "ZZZZExplicitlyPackedAsset-%d.%d.%d-gamut%d"
				// "ZZZZPackedAsset-%d.%d.%d-gamut%d"
				// "ZZZZFlattenedImage-%d.%d.%d"
				// "ZZZZRadiosityImage-%d.%d.%d"
				return;
			}
			
			numberOfAssets++;
			
			
			CGImageRef cgImage = (__bridge CGImageRef)(carNamedLookupDict[kCarInfoDict_CGImageKey]);
			
			// Prefer an image with a larger width and an aspect ratio not too excessive
			CGSize imageSize = CGSizeMake(CGImageGetWidth(cgImage), CGImageGetHeight(cgImage));
			double imageAspectRatio = AspectRatioForSize(imageSize);
			if((CGImageGetWidth(cgImage) > bestImageSize.width) && (fabs(1.0 - imageAspectRatio) <= 1.0))
			{
				// Ignore images that are too white or too transparent
				if(!IsCGImageTooWhiteOrTransparent(cgImage))
				{
					NSImage *theImage = GetRenderedNSImageFromCGImage(cgImage, maxSize);
					if(theImage != nil && theImage.size.width > 0 && theImage.size.height > 0)
					{
						bestImageFound = theImage;
						bestImageSize = imageSize;
					}
				}
			}
		}
	});
	
	if(canExtractCAR)
	{
		NSString *thumbnailDescription = [NSString stringWithFormat:@"%ld assets", numberOfAssets];
		NSRect maxRect = NSMakeRect(0, 0, maxSize.width, maxSize.height);
		
		CGContextRef cgContext = QLThumbnailRequestCreateContext(thumbnail, maxSize, false, NULL);
		if(cgContext)
		{
			NSGraphicsContext* context = [NSGraphicsContext graphicsContextWithCGContext:cgContext flipped:NO];
			if(context)
			{
				// Set the current context
				[NSGraphicsContext saveGraphicsState];
				[NSGraphicsContext setCurrentContext:context];
				
				// Set a white background
				[[NSColor whiteColor] set];
				NSRectFill(maxRect);
				
				// Draw the best image found
				if(bestImageFound != nil)
				{
					// Center the image
					NSRect imageCenteredRect = NSMakeRect((maxSize.width - bestImageFound.size.width) * 0.5, (maxSize.height - bestImageFound.size.height) * 0.5, bestImageFound.size.width, bestImageFound.size.height);
					[bestImageFound drawInRect:imageCenteredRect fromRect:NSMakeRect(0, 0, bestImageFound.size.width, bestImageFound.size.height) operation:NSCompositingOperationSourceOver fraction:0.33];
				}
				
				// Prepare the NSAttributedString
				NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
				[paragraphStyle setAlignment:NSTextAlignmentCenter];
				paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;

				NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:thumbnailDescription];
				[attributedString addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, [thumbnailDescription length])];
				[attributedString addAttribute:NSForegroundColorAttributeName value:[NSColor blackColor] range:NSMakeRange(0, [thumbnailDescription length])];
				
				// Find the best font to draw the text
				int fontSize = 24;
				NSRect stringCalculatedRect = NSZeroRect;
				while(fontSize > 4)
				{
					[attributedString addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:fontSize] range:NSMakeRange(0, [thumbnailDescription length])];
					
					// Measure the attribute string
					stringCalculatedRect = [attributedString boundingRectWithSize:CGSizeMake(maxRect.size.width, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading context:nil];
					if(stringCalculatedRect.size.height < maxRect.size.height)
						break;
					
					fontSize--;
				}
				
				// Draw text
				NSRect renderStringRect = NSMakeRect((maxRect.size.width - stringCalculatedRect.size.width) * 0.5, (maxRect.size.height - stringCalculatedRect.size.height) * 0.05, stringCalculatedRect.size.width, stringCalculatedRect.size.height);
				[attributedString drawInRect:renderStringRect];
				
				// Sets the context back to what it was
				[NSGraphicsContext restoreGraphicsState];
			}
			
			CFRelease(cgContext);
		}
		
		QLThumbnailRequestFlushContext(thumbnail, cgContext);
	}

	return noErr;
}

void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail)
{
    // Not implemented
}
