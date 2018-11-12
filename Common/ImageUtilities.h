//
//  ImageUtilities.h
//  QLCARFiles
//
//  Created by Alexandre Colucci.
//  Copyright © 2018 blog.timac.org. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

//
// Creates a CGImageRef filled with a color
//
CGImageRef CreateImageWithColor(CGColorRef inColorRef, CGSize inSize);

//
// Creates a NSImage from a CGImageRef
//
NSImage *GetRenderedNSImageFromCGImage(CGImageRef inCGImageRef, CGSize inMaxSize);

//
// This function tells if an image is too white or transparent
// and requires a background
//
BOOL IsCGImageTooWhiteOrTransparent(CGImageRef inCGImageRef);
