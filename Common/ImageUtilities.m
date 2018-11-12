//
//  ImageUtilities.m
//  QLCARFiles
//
//  Created by Alexandre Colucci.
//  Copyright © 2018 blog.timac.org. All rights reserved.
//

#import "ImageUtilities.h"

//
// Creates a bitmap graphics context for a specific size
//
CGContextRef CreateBitmapContext(CGSize inSize)
{
	CGFloat bitmapBytesPerRow = inSize.width * 4;
	CGFloat bitmapByteCount = (bitmapBytesPerRow * inSize.height);
	
	void *bitmapData = calloc(bitmapByteCount, 1);
	if(bitmapData == NULL)
	{
		return NULL;
	}
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(bitmapData, inSize.width, inSize.height, 8, bitmapBytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast);
	if(context == NULL)
	{
		CGColorSpaceRelease(colorSpace);
		free(bitmapData);
		return NULL;
	}
	else
	{
		CGColorSpaceRelease(colorSpace);
		return context;
	}
}

//
// Creates a CGImageRef filled with a color
//
CGImageRef CreateImageWithColor(CGColorRef inColorRef, CGSize inSize)
{
    CGRect rect = CGRectMake(0.0, 0.0, inSize.width, inSize.height);
	CGContextRef context = CreateBitmapContext(inSize);
	CGContextSetFillColorWithColor(context, inColorRef);
	CGContextFillRect(context, rect);
	CGImageRef cgImage = CGBitmapContextCreateImage(context);
	CGContextDrawImage(context, rect, cgImage);
	CGContextRelease(context);
	
	return cgImage;
}

//
// Creates a NSImage from a CGImageRef
//
NSImage *GetRenderedNSImageFromCGImage(CGImageRef inCGImageRef, CGSize inMaxSize)
{
	NSImage *outImage = nil;
	
	if (inCGImageRef != NULL)
	{
		NSSize imageSize;
		imageSize.width = CGImageGetWidth(inCGImageRef);
		imageSize.height = CGImageGetHeight(inCGImageRef);
		
		// Scale the image down if necessary
		if(imageSize.width > inMaxSize.width || imageSize.height > inMaxSize.height)
		{
			double aspectRatio = (double)CGImageGetWidth(inCGImageRef) / (double)CGImageGetHeight(inCGImageRef);
			if(aspectRatio > 1.0)
			{
				imageSize.width = inMaxSize.width;
				imageSize.height = ceil(imageSize.width / aspectRatio);
			}
			else
			{
				imageSize.height = inMaxSize.height;
				imageSize.width = ceil(imageSize.height * aspectRatio);
			}
			
			size_t bitsPerComponent = CGImageGetBitsPerComponent(inCGImageRef);
			CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
			CGContextRef context = CGBitmapContextCreate(nil, imageSize.width, imageSize.height, bitsPerComponent, 0, colorSpace, kCGImageAlphaPremultipliedLast);
			if(context != NULL)
			{
				CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
				CGContextDrawImage(context, CGRectMake(0, 0, imageSize.width, imageSize.height), inCGImageRef);
				CGImageRef scaledImage = CGBitmapContextCreateImage(context);
				if(scaledImage != NULL)
				{
					outImage = [[NSImage alloc] initWithCGImage:scaledImage size:NSZeroSize];
					CGImageRelease(scaledImage);
				}
				
				CGContextRelease(context);
			}
			
			CGColorSpaceRelease(colorSpace);
		}
		else
		{
			outImage = [[NSImage alloc] initWithCGImage:inCGImageRef size:NSZeroSize];
		}
	}
	
	return outImage;
}

//
// This function returns the primary color of an image
//
NSColor *GetPrimaryColorForCGImage(CGImageRef inCGImageRef)
{
	NSColor *outColor = nil;
	
	if (inCGImageRef != NULL)
	{
		size_t onePixelWidth = 1;
		
		CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
		CGContextRef context = CGBitmapContextCreate(nil, onePixelWidth, onePixelWidth, 8, 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Little);
		if(context != NULL)
		{
			CGContextDrawImage(context, CGRectMake(0, 0, onePixelWidth, onePixelWidth), inCGImageRef);
			uint32_t *dataPtr = CGBitmapContextGetData(context);
			if(dataPtr != NULL)
			{
				outColor = [NSColor colorWithRed: ((*dataPtr >> 24) & 0xff) / 255.0f
										   green: ((*dataPtr >> 16) & 0xff) / 255.0f
											blue: ((*dataPtr >> 8) & 0xff) / 255.0f
										   alpha: ((*dataPtr >> 0) & 0xff) / 255.0f ];
			}
			
			CGContextRelease(context);
		}
		
		CGColorSpaceRelease(colorSpace);
	}
	
	return outColor;
}

//
// This function tells if an image is too white or transparent
// and requires a background
//
BOOL IsCGImageTooWhiteOrTransparent(CGImageRef inCGImageRef)
{
	// Get the primary color of the image
	NSColor *primaryColor = GetPrimaryColorForCGImage(inCGImageRef);
	if(primaryColor != nil)
	{
		CGFloat redValue = 0;
		CGFloat greenValue = 0;
		CGFloat blueValue = 0;
		CGFloat alphaValue = 0;
		[primaryColor getRed:&redValue green:&greenValue blue:&blueValue alpha:&alphaValue];
		
		if(redValue > 250.0/255.0 && greenValue > 250.0/255.0 && blueValue > 250.0/255.0)
		{
			// The image is too white
			return YES;
		}
		else if(alphaValue < 0.1)
		{
			// The image is too transparent
			return YES;
		}
		else
		{
			return NO;
		}
	}
	
	return YES;
}

