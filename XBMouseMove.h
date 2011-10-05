/*
 *  XBMouseMove.h
 *  Xbox360Mouse
 *
 *  Created by Sherry Wu on 10/3/11.
 *  Copyright 2011 __MyCompanyName__. All rights reserved.
 *
 */

void postMouseEvent(const CGMouseButton button, const CGEventType type, const CGPoint point);

void moveMouseToDest(const CGPoint point);
void moveMouseWithPitch(const float xpitch, const float ypitch);

void clickDown(const CGMouseButton button);
void clickUp(const CGMouseButton button);
