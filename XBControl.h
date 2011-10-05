//
//  XBControl.h
//  Xbox360Mouse
//
//  Created by Sherry Wu on 10/2/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/IOCFPlugIn.h>
#import <IOKit/hid/IOHIDLib.h>
#import <IOKit/hid/IOHIDKeys.h>
#import <ForceFeedback/ForceFeedback.h>

#import "DeviceItem.h"


@interface XBControl : NSObject {
    // Internal info
    mach_port_t masterPort;
    NSMutableArray *deviceArray;
    IOHIDElementCookie axis[6],buttons[15];
    
    IOHIDDeviceInterface122 **device;
    IOHIDQueueInterface **hidQueue;
    FFDeviceObjectReference ffDevice;
    io_registry_entry_t registryEntry;
    
    int largeMotor,smallMotor;
    
    IONotificationPortRef notifyPort;
    CFRunLoopSourceRef notifySource;
    io_iterator_t onIteratorWired, offIteratorWired;
    io_iterator_t onIteratorWireless, offIteratorWireless;	
}

- (id)init;
- (void)eventQueueFired:(void *)sender withResult:(IOReturn)result;
- (void)handleDeviceChange;
- (mach_port_t)masterPort;

@end
