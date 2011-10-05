/*
 *  XBMouseMove.c
 *  Xbox360Mouse
 *
 *  Created by Sherry Wu on 10/3/11.
 *  Copyright 2011 __MyCompanyName__. All rights reserved.
 *
 */

#import <Foundation/Foundation.h>

#include "XBMouseMove.h"

static const float dt = 0.01f;
static const float dx = 4.0f;

static CGPoint
makeCGPoint(float x, float y)
{
	return (CGPoint){x, y};
}

void
postMouseEvent(const CGMouseButton button, const CGEventType type, const CGPoint point)
{
    CGEventRef theEvent = CGEventCreateMouseEvent(NULL, type, point, button);
    CGEventSetType(theEvent, type);
    CGEventPost(kCGHIDEventTap, theEvent);
    CFRelease(theEvent);
}

void
moveMouseToDest(const CGPoint point)
{
	CGEventRef getMouse = CGEventCreate(NULL);
	CGPoint mouseLoc = CGEventGetLocation(getMouse);
	//NSLog(@"%f %f", mouseLoc.x, mouseLoc.y);
	float moveX = point.x - mouseLoc.x;
	float moveY = point.y - mouseLoc.y;
	float dy = dx * (moveY / moveX);
	unsigned time = (unsigned)abs(moveX / dx);
	
	unsigned i;
	for (i = 1; i <= time; ++i) {
		CGPoint pt = makeCGPoint(mouseLoc.x - dx * i, mouseLoc.y - dy * i);
		//NSLog(@"%f %f", pt.x, pt.y);
		postMouseEvent(1, kCGEventLeftMouseUp, pt);
		[NSThread sleepForTimeInterval:dt];
	}
	CFRelease(getMouse);
}

void
moveMouseWithPitch(const float xpitch, const float ypitch)
{
	CGEventRef getMouse = CGEventCreate(NULL);
	CGPoint mouseLoc = CGEventGetLocation(getMouse);
	postMouseEvent(1, kCGEventLeftMouseUp, makeCGPoint(mouseLoc.x - xpitch * dt, mouseLoc.y - ypitch * dt));
	CFRelease(getMouse);
}

void
clickDown(const CGMouseButton button)
{
	CGPoint mouseLoc = CGEventGetLocation(CGEventCreate(NULL));
	switch (button) {
		case 0:
			postMouseEvent(button, kCGEventLeftMouseDown, mouseLoc);
			break;
		case 1:
			postMouseEvent(button, kCGEventRightMouseDown, mouseLoc);
			break;
		default:
			break;
	}
}

void
clickUp(const CGMouseButton button)
{
	CGPoint mouseLoc = CGEventGetLocation(CGEventCreate(NULL));
	switch (button) {
		case 0:
			postMouseEvent(button, kCGEventLeftMouseUp, mouseLoc);
			break;
		case 1:
			postMouseEvent(button, kCGEventRightMouseUp, mouseLoc);
			break;
		default:
			break;
	}
}
