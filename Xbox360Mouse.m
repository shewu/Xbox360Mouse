//
//  Xbox360Mouse.m
//  Xbox360Mouse
//
//  Created by Sherry Wu on 10/2/11.
//

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

#include <mach/mach.h>
#include <IOKit/usb/IOUSBLib.h>

#import "XBControl.h"
#import "XBMouseMove.h"

int
main(int argc, const char* argv[])
{
	//moveMouse(makeCGPoint(1,1));
	XBControl* xbControl = [[XBControl alloc] init];
	
	while (1) {
		[[NSRunLoop mainRunLoop] runUntilDate:[NSDate distantFuture]];
	}
	
	[xbControl release];
    return 0;
}
