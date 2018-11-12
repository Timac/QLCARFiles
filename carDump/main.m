//
//  main.m
//  carDump
//
//  Created by Alexandre Colucci.
//  Copyright © 2018 blog.timac.org. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CoreUI.h"
#import "CarUtilities.h"

NSString * FindUniquePathForPath(NSString *inPath, NSString *optionalPathComponent, BOOL forceUseOptionalFileNamePathComponent)
{
	NSString *outPath = inPath;
	
	// If the path exists, add the optional path component for differenciation
	if([optionalPathComponent length] > 0 && ([[NSFileManager defaultManager] fileExistsAtPath:inPath] || forceUseOptionalFileNamePathComponent))
	{
		NSString *pathExtension = [inPath pathExtension];
		if([pathExtension length] > 0)
		{
			NSString *replaceString = [NSString stringWithFormat:@".%@", pathExtension];
			outPath = [inPath stringByReplacingOccurrencesOfString:replaceString withString:[NSString stringWithFormat:@"~%@%@", optionalPathComponent, replaceString] options:NSBackwardsSearch range:NSMakeRange(0, [inPath length])];
		}
		else
		{
			outPath = [inPath stringByAppendingFormat:@"%@", [NSString stringWithFormat:@"~%@", optionalPathComponent]];
		}
	}
	
	// Ensure the path does not exist
	NSString *initialPath = outPath;
	if([[NSFileManager defaultManager] fileExistsAtPath:initialPath])
	{
		NSString *pathExtension = [initialPath pathExtension];
		if([pathExtension length] > 0)
		{
			NSString *replaceString = [NSString stringWithFormat:@".%@", pathExtension];
			NSUInteger fileSuffix = 1;
			while([[NSFileManager defaultManager] fileExistsAtPath:outPath])
			{
				outPath = [initialPath stringByReplacingOccurrencesOfString:replaceString withString:[NSString stringWithFormat:@"~%ld%@", fileSuffix, replaceString] options:NSBackwardsSearch range:NSMakeRange(0, [initialPath length])];
				fileSuffix++;
			}
		}
		else
		{
			NSUInteger fileSuffix = 1;
			while([[NSFileManager defaultManager] fileExistsAtPath:outPath])
			{
				outPath = [initialPath stringByAppendingFormat:@"%@", [NSString stringWithFormat:@"~%ld", fileSuffix]];
				fileSuffix++;
			}
		}
	}
	
	return outPath;
}

void DumpCGImageToPath(CGImageRef inImage, NSString *inPath)
{
	if(inImage != NULL && inPath != nil)
	{
		// Get the file URL
		CFURLRef fileURL = (__bridge CFURLRef)[NSURL fileURLWithPath:inPath];
		
		// Write the CGImageRef to disk
		CGImageDestinationRef destinationRef = CGImageDestinationCreateWithURL(fileURL, kUTTypePNG, 1, NULL);
		if(destinationRef != NULL)
		{
			CGImageDestinationAddImage(destinationRef, inImage, nil);
			if (!CGImageDestinationFinalize(destinationRef))
			{
				NSLog(@"Could not dump the image to %@", inPath);
			}
			
			CFRelease(destinationRef);
		}
	}
}


void ProcessNamedLookup(NSString *inOutputFolder, NSString *fileName, NSString *optionalFileNameComponent, BOOL forceUseOptionalFileNamePathComponent, CGImageRef cgImage, NSData *representation)
{
	//
	//
	// From /Applications/Xcode.app/Contents/Developer/Platforms/AppleTVSimulator.platform/Developer/SDKs/AppleTVSimulator.sdk/System/Library/PrivateFrameworks/CoreThemeDefinition.framework/CoreThemeDefinition
	// "ZZZZExplicitlyPackedAsset-%d.%d.%d-gamut%d"
	// "ZZZZPackedAsset-%d.%d.%d-gamut%d"
	// "ZZZZFlattenedImage-%d.%d.%d"
	// "ZZZZRadiosityImage-%d.%d.%d"
	//
	
	if([fileName hasPrefix:@"ZZZZPackedAsset"])
	{
		// Ignore ZZZZPackedAsset
		return;
	}
	
	NSString *uniqueFilePath = FindUniquePathForPath([inOutputFolder stringByAppendingPathComponent:fileName], optionalFileNameComponent, forceUseOptionalFileNamePathComponent);
	
	if(cgImage != NULL)
	{
		DumpCGImageToPath(cgImage, uniqueFilePath);
	}
	else if([representation isKindOfClass:[NSData class]])
	{
		[(NSData *)representation writeToFile:uniqueFilePath atomically:NO];
	}
	else
	{
		NSLog(@"Nothing to output for %@", uniqueFilePath);
	}
}

void ProcessCARFile(NSString *inCARPath, NSString *inOutputPathPrefix)
{
	ProcessCarFileAtPath(inCARPath, inOutputPathPrefix, ^(NSString *inOutputFolder, CarNamedLookupDict carNamedLookupDict)
	{
		if(carNamedLookupDict != nil)
		{
			CGImageRef cgImage = (__bridge CGImageRef)(carNamedLookupDict[kCarInfoDict_CGImageKey]);
			NSData *assetData = carNamedLookupDict[kCarInfoDict_DataKey];
			NSString *fileName = carNamedLookupDict[kCarInfoDict_FilenameKey];
			
			NSString *optionalFileNamePathComponent = nil;
			if(cgImage != nil)
			{
				optionalFileNamePathComponent = [NSString stringWithFormat:@"%ldx%ld", CGImageGetWidth(cgImage), CGImageGetHeight(cgImage)];
			}
			
			BOOL forceUseOptionalFileNamePathComponent = [carNamedLookupDict[kCarInfoDict_IsMultisizeImageKey] boolValue];
			ProcessNamedLookup(inOutputFolder, fileName, optionalFileNamePathComponent, forceUseOptionalFileNamePathComponent, cgImage, assetData);
		}
	});
}

void ProcessCARFilesInFolder(NSString *inFolderPath, NSString *inOutputPathPrefix, NSString *inOutputFolder)
{
	NSError *error = nil;
	NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:inFolderPath error:&error];
	if(error != nil)
	{
		return;
	}
	
	NSEnumerator *enumeratorContent = [contents objectEnumerator];
	NSString *file = nil;
	BOOL isDirectory = NO;

	while((file = [enumeratorContent nextObject]))
	{
		@autoreleasepool
		{
			NSString *fullPath = [inFolderPath stringByAppendingPathComponent:file];
			BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDirectory];
			if(fileExists)
			{
				if(isDirectory)
				{
					NSString *outputPathPrefix = [inOutputPathPrefix stringByAppendingPathComponent:file];
					ProcessCARFilesInFolder(fullPath, outputPathPrefix, inOutputFolder);
				}
				else if([[file pathExtension] isEqualToString:@"car"])
				{
					NSLog(@"Processing %@", fullPath);
					
					NSString *outputPath = [inOutputPathPrefix stringByAppendingPathComponent:[file stringByDeletingPathExtension]];
					outputPath = [outputPath stringByReplacingOccurrencesOfString:@"." withString:@"_"];
					NSString *outputFolder = [inOutputFolder stringByAppendingPathComponent:outputPath];
					
					// Ensure the output folder exists
					[[NSFileManager defaultManager] createDirectoryAtPath:outputFolder withIntermediateDirectories:YES attributes:nil error:nil];
					
					ProcessCARFile(fullPath, outputFolder);
				}
			}
		}
	}
}

void PrintUsage()
{
	printf("NAME\n");
	printf("\t\tcarDump to dump .car files\n\n");
	
	printf("SYNOPSIS\n");
	printf("\t\tcarDump [-r] path outputPath\n\n");
	
	printf("DESCRIPTION\n");
	printf("\t\tcarDump is a command line tool to dump the content of .car files.\n\n");
	
	printf("OPTIONS\n");
	printf("\t\t-r\n\t\t\tRecursively find .car files into the passed path and dump all of them.\n\n");
	
	printf("EXAMPLES\n");
	printf("\t\tcarDump Assets.car ~/Desktop/carDump\n");
	printf("\t\tcarDump -r /Applications ~/Desktop/carDump\n");
	
	printf("\n");
}

int main(int argc, const char * argv[])
{
	@autoreleasepool
	{
		BOOL validCommand = NO;
		BOOL isRecursive = NO;
		NSString *path = nil;
		NSString *outputFolder = nil;
		
		if(argc == 3)
		{
			validCommand = YES;
			path = [NSString stringWithUTF8String:argv[1]];
			outputFolder = [NSString stringWithUTF8String:argv[2]];
		}
		else if(argc == 4)
		{
			NSString *option1 = [NSString stringWithUTF8String:argv[1]];
			if([option1 isEqualToString:@"-r"])
			{
				isRecursive = YES;
				validCommand = YES;
			}
			
			path = [NSString stringWithUTF8String:argv[2]];
			outputFolder = [NSString stringWithUTF8String:argv[3]];
		}
		
		path = [path stringByExpandingTildeInPath];
		outputFolder = [outputFolder stringByExpandingTildeInPath];
		
		if(path == nil || outputFolder == nil)
		{
			PrintUsage();
			return -1;
		}
		
		// Check the parameter is a valid .car file or folder
		if(!isRecursive)
		{
			BOOL isDirectory = NO;
			if([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] && !isDirectory)
			{
				// Valid command
			}
			else
			{
				validCommand = NO;
			}
		}
		else
		{
			BOOL isDirectory = NO;
			if([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory])
			{
				if(isDirectory)
				{
					// Valid command
				}
				else if([[path pathExtension] isEqualToString:@"car"])
				{
					// Valid command
				}
				else if([[path pathExtension] isEqualToString:@"car"])
				{
					validCommand = NO;
				}
			}
		}
		
		// Check that the output folder exists
		{
			BOOL isDirectory = NO;
			if([[NSFileManager defaultManager] fileExistsAtPath:outputFolder isDirectory:&isDirectory] && isDirectory)
			{
				// Valid command
			}
			else
			{
				validCommand = NO;
			}
		}
		
		if (!validCommand)
		{
			PrintUsage();
			return -1;
		}
		
		BOOL isDirectory = NO;
		BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory];
		if(fileExists)
		{
			if(isDirectory)
			{
				ProcessCARFilesInFolder(path, @"", outputFolder);
			}
			else if([[path pathExtension] isEqualToString:@"car"])
			{
				ProcessCARFile(path, outputFolder);
			}
			else
			{
				PrintUsage();
			}
		}
	}
	
	return 0;
}
