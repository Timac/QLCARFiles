//
//  GeneratePreviewForURL.m
//  QLCARFiles
//
//  Created by Alexandre Colucci.
//  Copyright © 2018 blog.timac.org. All rights reserved.
//

#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#import "CoreUI.h"
#import "CarUtilities.h"
#import "ImageUtilities.h"
#import <AppKit/AppKit.h>
#import <AVFoundation/AVFoundation.h>
#include <malloc/malloc.h>
#include <os/log.h>

// QuickLook has a 30s timeout to render the preview (QLMaxPreviewTimeOut).
// After 20s, we don't process anymore the assets but only count them.
#define RENDERING_TIMEOUT	20

// QuickLook kills the plugin right away if it uses more than 120 MB of memory (QLMemoryUsedCritical).
// QuickLook might also kill the plugin if it uses more than 80 MB of memory (QLMemoryUsedUsage).
// If we used 70 MB of memory, we don't process anymore the assets but only count them.
#define MAX_MEMORY_LIMIT	70*1024*1024

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options);
void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview);


BOOL IsCriticalMemoryUsage()
{
	malloc_statistics_t stats = { 0 };
	malloc_zone_statistics(NULL, &stats);
	
	if(stats.size_in_use > MAX_MEMORY_LIMIT)
	{
		os_log(OS_LOG_DEFAULT, "Using too much memory: %0.1f MB", ((double)stats.size_in_use) / (1024.0 * 1024.0));
		return YES;
	}
	
	return NO;
}


NSString *FileDescription(NSString *utiType, NSUInteger dataSize, NSSize imageDimension)
{
	static NSByteCountFormatter *sByteCountFormatter = nil;
	if(sByteCountFormatter == nil)
	{
		sByteCountFormatter = [[NSByteCountFormatter alloc] init];
	}
	
	NSString *imageDescription = @"";
	if(!CGSizeEqualToSize(imageDimension, CGSizeZero) && dataSize > 0)
	{
		imageDescription = [NSString stringWithFormat:@"%ld x %ld (%@)", (size_t)imageDimension.width, (size_t)imageDimension.height, [sByteCountFormatter stringFromByteCount:dataSize]];
	}
	else if(!CGSizeEqualToSize(imageDimension, CGSizeZero))
	{
		imageDescription = [NSString stringWithFormat:@"%ld x %ld", (size_t)imageDimension.width, (size_t)imageDimension.height];
	}
	else if(dataSize > 0)
	{
		imageDescription = [NSString stringWithFormat:@"%@", [sByteCountFormatter stringFromByteCount:dataSize]];
	}
	else if([utiType length] > 0)
	{
		imageDescription = utiType;
	}

	return imageDescription;
}

NSData *PNGRepresentationOfImage(NSImage *image)
{
	NSData *outData = nil;
	
	CGImageRef imageRef = [image CGImageForProposedRect:NULL context:NULL hints:nil];
	if(imageRef != NULL)
	{
		NSMutableData *destData = [NSMutableData data];
		CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)destData, kUTTypePNG, 1, NULL);
		if(destination != NULL)
		{
			CGImageDestinationAddImage(destination, imageRef, NULL);
			if(CGImageDestinationFinalize(destination))
			{
				outData = [destData copy];
			}
			
			CFRelease(destination);
		}
	}
	
	return outData;
}

NSString *UniqueIDForFileName(NSString * inFileName)
{
	// Add a random integer as suffix to the fileName.
	// This ensures support for multiple assets with the same name but in different folders (namespaced assets).
	return [NSString stringWithFormat:@"%@%u", inFileName, (arc4random() % 1000)];
}

BOOL RenderHTML(NSString *inFileName,
				NSString *inDisplayName,
				NSString *inDescription,
				NSString *inUTIType,
				NSNumber *inFileSize,
				CGImageRef inCGImageRef,
				NSMutableString **inOutHTMLDataString,
				NSMutableDictionary **inOutAttachments)
{
	if(inCGImageRef != NULL)
	{
		CGSize imageDimension = CGSizeMake(CGImageGetWidth(inCGImageRef), CGImageGetHeight(inCGImageRef));
		NSImage *theImage = GetRenderedNSImageFromCGImage(inCGImageRef, CGSizeMake(PREVIEW_MAX_WIDTH, PREVIEW_MAX_HEIGHT));
		if(theImage != nil && theImage.size.width > 0 && theImage.size.height > 0)
		{
			NSData *imageData = PNGRepresentationOfImage(theImage);
			if(imageData != nil)
			{
				NSString *imageDescription = inDescription;
				if(imageDescription == nil)
				{
					NSUInteger dataSize = (inFileSize != nil) ? [inFileSize unsignedIntegerValue] : [imageData length];
					imageDescription = FileDescription(inUTIType, dataSize, imageDimension);
				}
				
				BOOL shouldAddBackground = IsCGImageTooWhiteOrTransparent(inCGImageRef);
				NSString *fileUniqueID = UniqueIDForFileName(inFileName);
				
				[*inOutHTMLDataString appendFormat:@"<div class=\"gallery\"><img style=\"margin-top: %dpx; %@\" src=\"cid:%@\" width=\"%d\" height=\"%d\"/><div class=\"description\"><p>%@</p><p>%@</p></div></div>\n",
										(int)ceil((PREVIEW_MAX_HEIGHT - theImage.size.height) / 2),
										shouldAddBackground ? @"background:#fcfcfc;" : @"",
										fileUniqueID,
										(int)theImage.size.width,
										(int)theImage.size.height,
										inDisplayName,
										imageDescription];
				
				[*inOutAttachments setObject:@{(NSString *) kQLPreviewPropertyMIMETypeKey: @"image/png", (NSString *) kQLPreviewPropertyAttachmentDataKey: imageData} forKey:fileUniqueID];
				
				return YES;
			}
		}
	}
	
	return NO;
}

void RenderDummyHTML(NSString *inFileName, NSString *inDisplayName, NSString *inUTIType, NSNumber *inFileSize, NSMutableString **inOutHTMLDataString, NSMutableDictionary **inOutAttachments)
{
	NSUInteger dataSize = (inFileSize != nil) ? [inFileSize unsignedIntegerValue] : 0;
	NSString *imageDescription = FileDescription(inUTIType, dataSize, CGSizeZero);
	
	[*inOutHTMLDataString appendFormat:@"<div class=\"gallery\"><div class=\"dataDescription\"><p style=\"color: black; font-size: x-large;\">DATA</p></div><div class=\"description\"><p>%@</p><p>%@</p></div></div>\n",
								inDisplayName,
								imageDescription];
}

void RenderUnprocessedHTML(NSUInteger inUnprocessedAssetsNumber, NSMutableString **inOutHTMLDataString)
{
	[*inOutHTMLDataString appendFormat:@"<div class=\"gallery\"><div class=\"dataDescription\"><p style=\"color: black; font-size: x-large;\">+%ld</p></div></div>\n",
								inUnprocessedAssetsNumber];
}

NSString *DisplayNameForURL(NSURL *inURL, NSUInteger inNumberOfAssets)
{
	if(inURL != nil)
	{
		NSString *filePath = [inURL path];
		NSString *fileName = [filePath lastPathComponent];
		NSString *parentName = [[filePath stringByDeletingLastPathComponent] lastPathComponent];
		if([[parentName pathExtension] isEqualToString:@"app"] ||
			[[parentName pathExtension] isEqualToString:@"framework"] ||
			[[parentName pathExtension] isEqualToString:@"bundle"])
		{
			return [NSString stringWithFormat:@"%@/%@ (%ld)", parentName, fileName, (unsigned long)inNumberOfAssets];
		}
		else
		{
			return [NSString stringWithFormat:@"%@ (%ld)", fileName, (unsigned long)inNumberOfAssets];
		}
	}
	
	return nil;
}

NSString *CreateTemporaryFolder()
{
	NSString *outTmpFolderPath = nil;
	
	NSString *folderTemplate = [NSTemporaryDirectory() stringByAppendingPathComponent:@"qlcar.XXXXXX"];
	const char *folderTemplateCString = [folderTemplate fileSystemRepresentation];
	
	size_t len = strlen(folderTemplateCString);
	char *folderNameCString = (char *)malloc(len + 1);
	strlcpy(folderNameCString, folderTemplateCString, len);
	char *result = mkdtemp(folderNameCString);
	if (result != NULL)
	{
		outTmpFolderPath = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:folderNameCString length:strlen(result)];
	}
	
	free(folderNameCString);
	
	return outTmpFolderPath;
}


OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
	// The path of the HTML template we are trying to display
	NSString *templatePath = [NSString stringWithFormat:@"%@/Contents/Resources/previewTemplate.html", [[NSBundle bundleWithIdentifier:@"org.timac.QLCARFiles"] bundlePath]];
	NSMutableString *htmlDataString = [[NSMutableString alloc] initWithContentsOfFile:templatePath encoding:NSUTF8StringEncoding error:nil];
	
	[htmlDataString replaceOccurrencesOfString:@"PREVIEW_MAX_WIDTH" withString:[NSString stringWithFormat:@"%d", PREVIEW_MAX_WIDTH] options:0 range:NSMakeRange(0, [htmlDataString length])];
	[htmlDataString replaceOccurrencesOfString:@"PREVIEW_MAX_HEIGHT" withString:[NSString stringWithFormat:@"%d", PREVIEW_MAX_HEIGHT] options:0 range:NSMakeRange(0, [htmlDataString length])];
	
	NSMutableDictionary *attachments = [NSMutableDictionary dictionary];
	
	// Create a temporary folder to store videos
	__block NSString *tmpFolderPath = nil;
	
	// Count the number of assets
	__block NSUInteger numberOfAssets = 0;
	
	// The preview needs to be rendered under a certain duration
	CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
	CFAbsoluteTime timeOutTime = startTime + RENDERING_TIMEOUT;
	
	// Count the number of assets not processed
	__block NSUInteger numberOfAssetsNotProcessed = 0;
	
	
	BOOL canExtractCAR = ProcessCarFileAtPath([(__bridge NSURL *)url path], nil, ^(NSString *inOutputFolder, CarNamedLookupDict carNamedLookupDict)
	{
		if(carNamedLookupDict != nil)
		{
			numberOfAssets++;
			
			// Stop processing assets if we reached the timeout or are using too much memory.
			if((CFAbsoluteTimeGetCurrent() > timeOutTime) || IsCriticalMemoryUsage())
			{
				numberOfAssetsNotProcessed++;
				return;
			}
			
			@try
			{
				CGImageRef cgImage = (__bridge CGImageRef)(carNamedLookupDict[kCarInfoDict_CGImageKey]);
				NSData *assetData = carNamedLookupDict[kCarInfoDict_DataKey];
				NSString *fileName = carNamedLookupDict[kCarInfoDict_FilenameKey];
				NSString *displayName = carNamedLookupDict[kCarInfoDict_DisplayNameKey];
				NSString *description = carNamedLookupDict[kCarInfoDict_DescriptionKey];
				if(displayName == nil)
				{
					displayName = fileName;
				}
				
				NSString *utiType = carNamedLookupDict[kCarInfoDict_UTITypeKey];
				
				NSNumber *fileSize = nil;
				if(assetData != nil)
				{
					fileSize = @([assetData length]);
				}
				else if(cgImage != NULL)
				{
					NSImage *theImage = [[NSImage alloc] initWithCGImage:cgImage size:NSZeroSize];
					NSData *pngRepresentation = PNGRepresentationOfImage(theImage);
					fileSize = @([pngRepresentation length]);
				}
				
				CGSize imageDimension = CGSizeZero;
				if(cgImage != NULL && CGImageGetWidth(cgImage) > 0 && CGImageGetHeight(cgImage) > 0)
				{
					imageDimension = CGSizeMake(CGImageGetWidth(cgImage), CGImageGetHeight(cgImage));
				}
				
				BOOL namedLookupRendered = NO;
				
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
					namedLookupRendered = YES;
					numberOfAssets--;
				}
				else if (cgImage != NULL)
				{
					NSMutableString * __autoreleasing autoreleasingHTMLDataString = htmlDataString;
					NSMutableDictionary * __autoreleasing autoreleasingAttachments = attachments;
					namedLookupRendered = RenderHTML(fileName, displayName, description, utiType, fileSize, cgImage, &autoreleasingHTMLDataString, &autoreleasingAttachments);
				}
				else if([assetData isKindOfClass:[NSData class]])
				{
					NSImage *theImage = [[NSImage alloc] initWithData:(NSData *)assetData];
					
					if(UTTypeConformsTo((__bridge CFStringRef)(utiType), kUTTypeGIF))
					{
						NSUInteger dataSize = (fileSize != nil) ? [fileSize unsignedIntegerValue] : 0;
						NSString *imageDescription = FileDescription(utiType, dataSize, CGSizeZero);
						NSString *fileUniqueID = UniqueIDForFileName(fileName);
						
						[htmlDataString appendFormat:@"<div class=\"gallery\"><img style=\"margin-top: %dpx;\" src=\"cid:%@\"/><div class=\"description\"><p>%@</p><p>%@</p></div></div>\n",
							(int)ceil((PREVIEW_MAX_HEIGHT - theImage.size.height) / 2),
							fileUniqueID,
							displayName,
							imageDescription];
						
						NSString *mimeType = CFBridgingRelease(UTTypeCopyPreferredTagWithClass((__bridge CFStringRef _Nonnull)(utiType), kUTTagClassMIMEType));
						if([mimeType length] > 0)
						{
							[attachments setObject:@{(NSString *) kQLPreviewPropertyMIMETypeKey: mimeType, (NSString *) kQLPreviewPropertyAttachmentDataKey: (NSData *)assetData} forKey:fileUniqueID];
						}
						else
						{
							[attachments setObject:@{(NSString *) kQLPreviewPropertyAttachmentDataKey: (NSData *)assetData} forKey:fileUniqueID];
						}
						
						namedLookupRendered = YES;
					}
					else if(theImage != nil && theImage.size.width > 0 && theImage.size.height > 0)
					{
						NSData *pngRepresentation = PNGRepresentationOfImage(theImage);
						CGImageSourceRef imageSourceRef = CGImageSourceCreateWithData((CFDataRef)pngRepresentation, NULL);
						if(imageSourceRef != NULL)
						{
							CGImageRef cgImageRef = CGImageSourceCreateImageAtIndex(imageSourceRef, 0, NULL);
							if(cgImageRef != NULL)
							{
								NSMutableString * __autoreleasing autoreleasingHTMLDataString = htmlDataString;
								NSMutableDictionary * __autoreleasing autoreleasingAttachments = attachments;
								namedLookupRendered = RenderHTML(fileName, displayName, description, utiType, fileSize, cgImageRef, &autoreleasingHTMLDataString, &autoreleasingAttachments);
								CGImageRelease(cgImageRef);
							}
							
							CFRelease(imageSourceRef);
						}
					}
					else if(UTTypeConformsTo((__bridge CFStringRef)(utiType), kUTTypeImage))
					{
						NSUInteger dataSize = (fileSize != nil) ? [fileSize unsignedIntegerValue] : 0;
						NSString *imageDescription = FileDescription(utiType, dataSize, CGSizeZero);
						NSString *fileUniqueID = UniqueIDForFileName(fileName);
						
						[htmlDataString appendFormat:@"<div class=\"gallery\"><img src=\"cid:%@\"/><div class=\"description\"><p>%@</p><p>%@</p></div></div>\n",
							fileUniqueID,
							displayName,
							imageDescription];
				
						NSString *mimeType = CFBridgingRelease(UTTypeCopyPreferredTagWithClass((__bridge CFStringRef _Nonnull)(utiType), kUTTagClassMIMEType));
						if([mimeType length] > 0)
						{
							[attachments setObject:@{(NSString *) kQLPreviewPropertyMIMETypeKey: mimeType, (NSString *) kQLPreviewPropertyAttachmentDataKey: (NSData *)assetData} forKey:fileUniqueID];
						}
						else
						{
							[attachments setObject:@{(NSString *) kQLPreviewPropertyAttachmentDataKey: (NSData *)assetData} forKey:fileUniqueID];
						}
						
						namedLookupRendered = YES;
					}
					else if(UTTypeConformsTo((__bridge CFStringRef)(utiType), kUTTypeAudiovisualContent))
					{
						// Create a temporary folder if needed
						if(tmpFolderPath == nil)
						{
							tmpFolderPath = CreateTemporaryFolder();
						}
						
						// Save the NSData to disk
						NSString *tempFilePath = [tmpFolderPath stringByAppendingPathComponent:fileName];
						if(tempFilePath != nil)
						{
							if([[NSFileManager defaultManager] createFileAtPath:tempFilePath contents:assetData attributes:nil])
							{
								// Create an AVAsset
								AVURLAsset *avAsset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:tempFilePath] options:nil];
								if(avAsset != nil)
								{
									// Create an AVAssetImageGenerator to extract one image from the video
									AVAssetImageGenerator* imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:avAsset];
									if(imageGenerator != nil)
									{
										imageGenerator.appliesPreferredTrackTransform = YES;
										CGImageRef cgImageRef = [imageGenerator copyCGImageAtTime:CMTimeMake(0, 1) actualTime:nil error:nil];
										if(cgImageRef != NULL)
										{
											NSMutableString * __autoreleasing autoreleasingHTMLDataString = htmlDataString;
											NSMutableDictionary * __autoreleasing autoreleasingAttachments = attachments;
											namedLookupRendered = RenderHTML(fileName, displayName, description, utiType, fileSize, cgImageRef, &autoreleasingHTMLDataString, &autoreleasingAttachments);
											CGImageRelease(cgImageRef);
										}
									}
								}
								
								// Cleanup
								[[NSFileManager defaultManager] removeItemAtPath:tempFilePath error:nil];
							}
						}
					}
				}
				
				if(!namedLookupRendered)
				{
					NSMutableString * __autoreleasing autoreleasingHTMLDataString = htmlDataString;
					NSMutableDictionary * __autoreleasing autoreleasingAttachments = attachments;
					RenderDummyHTML(fileName, displayName, utiType, fileSize, &autoreleasingHTMLDataString, &autoreleasingAttachments);
				}
			}
			@catch (NSException *exception)
			{
				// Exception caught
			}
		}
	});
	
	if(canExtractCAR)
	{
		// Add an image with the number of assets not processed
		if(numberOfAssetsNotProcessed > 0)
		{
			NSMutableString * __autoreleasing autoreleasingHTMLDataString = htmlDataString;
			RenderUnprocessedHTML(numberOfAssetsNotProcessed, &autoreleasingHTMLDataString);
		}
		
		// Finalize the HTML
		[htmlDataString appendString:@"</div></body></html>"];
		
		NSString *displayName = DisplayNameForURL((__bridge NSURL *)url, numberOfAssets);
		NSDictionary *properties = nil;
		if([displayName length] > 0)
		{
			properties = @{(NSString *) kQLPreviewPropertyDisplayNameKey: displayName,
                               (NSString *) kQLPreviewPropertyAttachmentsKey: attachments};
		}
		else
		{
			properties = @{(NSString *) kQLPreviewPropertyAttachmentsKey: attachments};
		}
		
		NSData *htmlData = [htmlDataString dataUsingEncoding:NSUnicodeStringEncoding];
		QLPreviewRequestSetDataRepresentation(preview, (__bridge CFDataRef)htmlData, kUTTypeHTML, (__bridge CFDictionaryRef)(properties));
	}
	
	if(tmpFolderPath != nil)
	{
		[[NSFileManager defaultManager] removeItemAtPath:tmpFolderPath error:nil];
	}
	
	return noErr;
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview)
{
    // Not implemented
}
