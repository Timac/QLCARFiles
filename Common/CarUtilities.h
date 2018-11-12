//
//  CarUtilities.h
//  QLCARFiles
//
//  Created by Alexandre Colucci.
//  Copyright © 2018 blog.timac.org. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>


//
// Size of the images in the QuickLook plugin
//
#define PREVIEW_MAX_WIDTH	120
#define PREVIEW_MAX_HEIGHT	PREVIEW_MAX_WIDTH


//
// Keys used by the CarNamedLookupDict dictionary
//
extern NSString * const kCarInfoDict_FilenameKey;
extern NSString * const kCarInfoDict_DisplayNameKey;
extern NSString * const kCarInfoDict_DescriptionKey;
extern NSString * const kCarInfoDict_CGImageKey;
extern NSString * const kCarInfoDict_UTITypeKey;
extern NSString * const kCarInfoDict_DataKey;
extern NSString * const kCarInfoDict_IsMultisizeImageKey;


//
// Declare the block to be executed when a rendition is found
//
typedef NSDictionary <NSString *, id>* CarNamedLookupDict;
typedef void (^CarNamedLookupBlock)(NSString *inOutputFolder, CarNamedLookupDict carNamedLookupDict);


//
// Function that parses a .car file at the specified inCarPath and call the block for each rendition found
//
BOOL ProcessCarFileAtPath(NSString *inCarPath, NSString *inOutputFolder, CarNamedLookupBlock namedLookupsCallback);
