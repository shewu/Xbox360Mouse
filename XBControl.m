//
//  XBControl.m
//  Xbox360Mouse
//
//  Created by Sherry Wu on 10/2/11.
//  Credits to Colin Munro (TattieBogle) for the bulk of the code -- based off Pref360Control
//  Thanks so much for making my life awesome!
//

#include <mach/mach.h>
#include <IOKit/usb/IOUSBLib.h>
#import <Foundation/Foundation.h>

#import "XBControl.h"

static void
callbackHandleDevice(void* param, io_iterator_t iterator)
{
	printf("callback handle\n");
	io_service_t object = 0;
	BOOL update = FALSE;
	while ((object = IOIteratorNext(iterator)) != 0) {
		IOObjectRelease(object);
		update = TRUE;
	}
	if (update) {
		[(XBControl *)param handleDeviceChange];
	}
}

static void
CallbackFunction(void* target, IOReturn result, void* refCon, void* sender)
{
	if (target) {
		[((XBControl *)target) eventQueueFired:sender withResult:result];
	}
}

@interface XBControl ()

- (void)startDevice;
- (void)stopDevice;

- (void)updateDeviceList;

- (void)axis:(int)index changedTo:(int)value;
- (void)button:(int)i;

- (void)mouseMoveThread;

@end

@implementation XBControl

- (id)init 
{
	if (self = [super init]) {
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		
		io_object_t object;
		
		// Get master port, for accessing I/O Kit
		IOMasterPort(MACH_PORT_NULL, &masterPort);
		// Set up notification of USB device addition/removal
		notifyPort = IONotificationPortCreate(masterPort);
		notifySource = IONotificationPortGetRunLoopSource(notifyPort);
		CFRunLoopAddSource(CFRunLoopGetCurrent(), notifySource, kCFRunLoopCommonModes);
		// Prepare other fields
		deviceArray = [[NSMutableArray arrayWithCapacity:1] retain];
		device = NULL;
		hidQueue = NULL;
		// Activate callbacks
        // Wired
		IOServiceAddMatchingNotification(notifyPort, kIOFirstMatchNotification, IOServiceMatching(kIOUSBDeviceClassName), callbackHandleDevice, self, &onIteratorWired);
		callbackHandleDevice(self, onIteratorWired);
		IOServiceAddMatchingNotification(notifyPort, kIOTerminatedNotification, IOServiceMatching(kIOUSBDeviceClassName), callbackHandleDevice, self, &offIteratorWired);
		while ((object = IOIteratorNext(offIteratorWired)) != 0) {
			NSLog(@"hi");
			IOObjectRelease(object);
		}
        // Wireless
		IOServiceAddMatchingNotification(notifyPort, kIOFirstMatchNotification, IOServiceMatching("WirelessHIDDevice"), callbackHandleDevice, self, &onIteratorWireless);
		callbackHandleDevice(self, onIteratorWireless);
		IOServiceAddMatchingNotification(notifyPort, kIOTerminatedNotification, IOServiceMatching("WirelessHIDDevice"), callbackHandleDevice, self, &offIteratorWireless);
		while ((object = IOIteratorNext(offIteratorWireless)) != 0) {
			IOObjectRelease(object);
		}
		
		[NSThread detachNewThreadSelector:@selector(mouseMoveThread) toTarget:self withObject:nil];
		
		[pool drain];
		[pool release];
	}
	return self;
}

- (void)dealloc
{
	// finish this
	[super dealloc];
}

#pragma mark -
#pragma mark Starting, Stopping Device

- (void)stopDevice
{
	if (registryEntry == 0) {
		return;
	}
	if (hidQueue) {
		CFRunLoopSourceRef eventSource;
		
		(*hidQueue)->stop(hidQueue);
		eventSource = (*hidQueue)->getAsyncEventSource(hidQueue);
		if (eventSource && CFRunLoopContainsSource(CFRunLoopGetCurrent(), eventSource, kCFRunLoopCommonModes)) {
			CFRunLoopRemoveSource(CFRunLoopGetCurrent(), eventSource, kCFRunLoopCommonModes);
		}
		(*hidQueue)->Release(hidQueue);
		hidQueue = NULL;
	}
	if (device) {
		(*device)->close(device);
		device = NULL;
	}
	registryEntry = 0;
}

- (void)startDevice
{
	int i = 0, j;
	CFArrayRef elements;
	CFDictionaryRef element;
	CFTypeRef object;
	long number;
	IOHIDElementCookie cookie;
	long usage, usagePage;
	CFRunLoopSourceRef eventSource;
	IOReturn ret;
	
	if ([deviceArray count] == 0) {
		NSLog(@"no device found!");
		return;
	}
	NSLog(@"there are %u devices", [deviceArray count]);
	if (i < [deviceArray count]) {
		DeviceItem* item = [deviceArray objectAtIndex:i];
		device = [item hidDevice];
		ffDevice = [item ffDevice];
		registryEntry = [item rawDevice];
		NSLog(@"I has a controller");
	}
	IOReturn retval;
	if ((retval = (*device)->copyMatchingElements(device, NULL, &elements)) != kIOReturnSuccess) {
		NSLog(@"retval = %d", retval);
		NSLog(@"can't get elements list");
		return;
	}
	for (i = 0; i < CFArrayGetCount(elements); ++i) {
		element = CFArrayGetValueAtIndex(elements, i);
		object = CFDictionaryGetValue(element, CFSTR(kIOHIDElementCookieKey));
		if (!object || CFGetTypeID(object) != CFNumberGetTypeID()) {
			continue;
		}
		if (!CFNumberGetValue((CFNumberRef)object, kCFNumberLongType, &number)) {
			continue;
		}
		cookie = (IOHIDElementCookie)number;
		
		object = CFDictionaryGetValue(element, CFSTR(kIOHIDElementUsageKey));
		if (object == 0 || CFGetTypeID(object) != CFNumberGetTypeID()) {
			continue;
		}
		if (!CFNumberGetValue((CFNumberRef)object, kCFNumberLongType, &number)) {
			continue;
		}
		usage = number;
		
		object = CFDictionaryGetValue(element, CFSTR(kIOHIDElementUsagePageKey));
		if (object == 0 || CFGetTypeID(object) != CFNumberGetTypeID()) {
			continue;
		}
		if (!CFNumberGetValue((CFNumberRef)object, kCFNumberLongType, &number)) {
			continue;
		}
		usagePage = number;
		switch(usagePage) {
            case 0x01:  // Generic Desktop
                j=0;
                switch(usage) {
                    case 0x35:  // Right trigger
                        j++;
                    case 0x32:  // Left trigger
                        j++;
                    case 0x34:  // Right stick Y
                        j++;
                    case 0x33:  // Right stick X
                        j++;
                    case 0x31:  // Left stick Y
                        j++;
                    case 0x30:  // Left stick X
                        axis[j]=cookie;
                        break;
                    default:
                        break;
                }
                break;
            case 0x09:  // Button
                if((usage>=1)&&(usage<=15)) {
                    // Button 1-11
                    buttons[usage-1]=cookie;
                }
                break;
				default:
                break;
        }
    }

	if ((*device)->open(device, 0) != kIOReturnSuccess) {
		NSLog(@"can't open device");
		return;
	}
	if (!(hidQueue = (*device)->allocQueue(device))) {
		NSLog(@"unable to allocate queue");
		return;
	}
	ret=(*hidQueue)->create(hidQueue,0,32);
    if(ret!=kIOReturnSuccess) {
        NSLog(@"Unable to create the queue");
        // Error?
        return;
    }	
	if ((ret = (*hidQueue)->createAsyncEventSource(hidQueue, &eventSource)) != kIOReturnSuccess) {
		NSLog(@"unable to create async event source");
		return;
	}
	if ((ret = (*hidQueue)->setEventCallout(hidQueue, CallbackFunction, self, NULL)) != kIOReturnSuccess) {
		NSLog(@"unable to set event callback");
		return;
	}
	CFRunLoopAddSource(CFRunLoopGetCurrent(), eventSource, kCFRunLoopCommonModes);
	for (i = 0; i < 6; ++i) {
		(*hidQueue)->addElement(hidQueue, axis[i], 0);
	}
	for (i = 0; i < 15; ++i) {
		(*hidQueue)->addElement(hidQueue, buttons[i], 0);
	}
	
	ret = (*hidQueue)->start(hidQueue);
	if (ret != kIOReturnSuccess) {
		NSLog(@"unable to start queue: 0x%.8x", ret);
		return;
	}
	// the rest is manipulating the GUI
}

#pragma mark -
#pragma mark Misc

- (void)updateDeviceList
{
	CFMutableDictionaryRef hidDictionary;
    IOReturn ioReturn;
    io_iterator_t iterator;
    io_object_t hidDevice, parent;
    int count;
    DeviceItem *item;

	[self stopDevice];
	[deviceArray removeAllObjects];
	
	hidDictionary = IOServiceMatching(kIOHIDDeviceKey);
	ioReturn = IOServiceGetMatchingServices(masterPort, hidDictionary, &iterator);
	if (ioReturn != kIOReturnSuccess || iterator == 0) {
		return;
	}
	count = 0;
	while (hidDevice = IOIteratorNext(iterator)) {
		parent = 0;
		IORegistryEntryGetParentEntry(hidDevice, kIOServicePlane, &parent);
		BOOL deviceWired = IOObjectConformsTo(parent, "Xbox360Peripheral") && IOObjectConformsTo(hidDevice, "Xbox360ControllerClass");
		BOOL deviceWireless = IOObjectConformsTo(hidDevice, "WirelessHIDDevice");
		if (!(deviceWired || deviceWireless)) {
			IOObjectRelease(hidDevice);
			continue;
		}
		item = [DeviceItem allocateDeviceItemForDevice:hidDevice];
		if (item) {
			[deviceArray addObject:item];
		}
	}
	IOObjectRelease(iterator);
	[self startDevice];
}

- (mach_port_t)masterPort
{
    return masterPort;
}

- (void)handleDeviceChange
{
    // Ideally, this function would make a note of the controller's Location ID, then
    // reselect it when the list is updated, if it's still in the list.
    [self updateDeviceList];
}

#pragma mark -
#pragma mark Event Processing

static BOOL buttonState[15];
static float lastPitch[2];

- (void)axis:(int)index changedTo:(int)value
{
	switch (index) {
		case 0:
		case 1:
			lastPitch[index] = (float)(value / (1<<6));
			break;
		default:
			break;
	}
}

- (void)button:(int)i
{
	if (buttonState[i] = 1-buttonState[i]) {
		clickDown(i);
	} else {
		clickUp(i);
	}
}

- (void)eventQueueFired:(void *)sender withResult:(IOReturn)result
{
    AbsoluteTime zeroTime={0,0};
    IOHIDEventStruct event;
    BOOL found;
    int i;
    
    if (sender != hidQueue) {
		return;
	}
    while (result == kIOReturnSuccess) {
        result = (*hidQueue)->getNextEvent(hidQueue, &event, zeroTime, 0);
        if (result != kIOReturnSuccess) {
			continue;
		}
        // Check axis
        for (i = 0, found = FALSE; (i < 6) && (!found); i++) {
            if(event.elementCookie == axis[i]) {
				//NSLog(@"axis %d changed to value %d", i, event.value); // value between -1<<15, -1 + 1<<15
				[self axis:i changedTo:event.value];
                found = TRUE;
            }
        }
        if (found) {
			continue;
		}
        // Check buttons
        for (i = 0, found = FALSE; (i < 15) && (!found); i++) {
            if (event.elementCookie == buttons[i]) {
				//NSLog(@"button %d changed", i);
				[self button:i];
                found = TRUE;
            }
        }
        if (found) {
			continue;
		}
        // Cookie wasn't for us?
    }
}

- (void)mouseMoveThread
{
	while (TRUE) {
		//NSLog(@"last pitch = (%f, %f)", lastPitch[0], lastPitch[1]);
		moveMouseWithPitch(-lastPitch[0], -lastPitch[1]);
		[NSThread sleepForTimeInterval:0.01f];
	}
}

@end
