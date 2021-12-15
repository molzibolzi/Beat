//
//  BeatSegmentedControl.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 21.10.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatSegmentedControl.h"
#import "BeatSegmentedCell.h"
#import "ThemeManager.h"
#import "BeatEditorDelegate.h"
#import "BeatSidebarTabView.h"

@interface BeatSegmentedControl ()
@end

@implementation BeatSegmentedControl

+ (Class)cellClass
{
	return BeatSegmentedCell.class;
}

- (id) initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	return self;
}
- (id)initWithCoder:(NSCoder *)aDecoder
{
	if (![aDecoder isKindOfClass:[NSKeyedUnarchiver class]])
		return [super initWithCoder:aDecoder];
		
	NSKeyedUnarchiver *unarchiver = (NSKeyedUnarchiver *)aDecoder;
	Class oldClass = [[self superclass] cellClass];
	Class newClass = [[self class] cellClass];
	
	[unarchiver setClass:newClass forClassName:NSStringFromClass(oldClass)];
	self = [super initWithCoder:aDecoder];
	[unarchiver setClass:oldClass forClassName:NSStringFromClass(oldClass)];
		
	[self setSelectedSegment:0];
	
	return self;
}

- (void)awakeFromNib
{
	[self.cell setTrackingMode:NSSegmentSwitchTrackingSelectOne];
}

- (void)drawRect:(NSRect)dirtyRect
{
	NSRect rect = [self bounds];
	rect.size.height -= 1;
	
	[self.cell drawWithFrame:self.frame inView:self];
	[self drawItems:rect];
	
}

-(void)drawCenteredImage:(NSImage*)image inFrame:(NSRect)frame
{
	NSImage *scaled = [self imageResize:image newSize:(NSSize){ frame.size.height * .8, frame.size.height * .8 }];
	CGSize imageSize = scaled.size;
	CGRect rect = NSMakeRect(frame.origin.x + (frame.size.width - imageSize.width) / 2.0,
			   frame.origin.y + (frame.size.height-imageSize.height) / 2.0,
			   imageSize.width,
			   imageSize.height);
	
	[scaled drawInRect:rect];
	
}

- (void)drawItems:(NSRect)rect
{
	[NSGraphicsContext.currentContext setImageInterpolation:NSImageInterpolationDefault];
	[NSGraphicsContext.currentContext setShouldAntialias:YES];
	
	CGFloat width = rect.size.width / [self segmentCount];
	
	for (NSInteger i = 0; i < self.segmentCount; i++) {
		NSImage *img = [self imageForSegment:i].copy;
		NSColor *tint = NSColor.tertiaryLabelColor;
		if (i == self.selectedSegment) tint = NSColor.whiteColor;

		[img lockFocus];
		[tint set];
		NSRect imageRect = {NSZeroPoint, img.size};
		NSRectFillUsingOperation(imageRect, NSCompositingOperationSourceIn);
		[img unlockFocus];
	
		NSRect segmentRect = (NSRect) { i * width, 0 + self.frame.size.height - 30, width, 30  };
		[self drawCenteredImage:img inFrame:segmentRect];
	}
}

- (NSImage *)imageResize:(NSImage*)anImage newSize:(NSSize)newSize {
	NSImage *sourceImage = anImage;
	
	// Report an error if the source isn't a valid image
	if (!sourceImage.isValid){
		NSLog(@"Invalid Image");
	} else {
		NSImage *smallImage = [[NSImage alloc] initWithSize: newSize];
		[smallImage lockFocus];
		[sourceImage setSize: newSize];
		[NSGraphicsContext.currentContext setImageInterpolation:NSImageInterpolationHigh];
		[sourceImage drawAtPoint:NSZeroPoint fromRect:CGRectMake(0, 0, newSize.width, newSize.height) operation:NSCompositingOperationCopy fraction:1.0];
		[smallImage unlockFocus];
		return smallImage;
	}
	return nil;
}

- (void)animateTo:(NSInteger)x
{

	//CGFloat maxX = self.frame.size.width - (self.frame.size.width / self.segmentCount);
	
	/*
	ANKnobAnimation *a = [[ANKnobAnimation alloc] initWithStart:location.x end:x];
	[a setDelegate:self];
	if (location.x == 0 || location.x == maxX){
		[a setDuration:_fastAnimationDuration];
		[a setAnimationCurve:NSAnimationEaseInOut];
	} else {
		[a setDuration:_slowAnimationDuration * ((fabs(location.x - x)) / maxX)];
		[a setAnimationCurve:NSAnimationLinear];
	}
	
	[a setAnimationBlockingMode:NSAnimationBlocking];
	[a startAnimation];
	*/
}


- (void)setPosition:(NSNumber *)x
{
	/*
	location.x = [x intValue];
	[self display];
	 */
}

- (void)setSelectedSegment:(NSInteger)selectedSegment {
	[self setSelectedSegment:selectedSegment animate:NO];
	[self selectTab:nil];
}

- (void)setSelectedSegment:(NSInteger)newSegment animate:(bool)animate
{
	if (newSegment == self.selectedSegment) return;
	
	CGFloat maxX = self.frame.size.width - (self.frame.size.width / self.segmentCount);
	NSInteger x = newSegment > self.segmentCount ? maxX : newSegment * (self.frame.size.width / self.segmentCount);
	
	
	if (animate)
		[self animateTo:x];
	else {
		[self setNeedsDisplay:YES];
	}
	
	[super setSelectedSegment:newSegment];
}

-(IBAction)selectTab:(id)sender {
	[self.tabView selectTabViewItem:[self.tabView tabViewItemAtIndex:self.selectedSegment]];
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

-(void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem {
	if ([tabView respondsToSelector:@selector(reload)]) {
		BeatSidebarTabView *view = (BeatSidebarTabView *)tabView;
		[view.reloadableView reload];
	}
}
-(void)reload {
	// Faux method
}


@end
/*
 
 I never felt as beautiful
 as when you told me I was beautiful
 your words have a tendency to reach deep within
 touching my soul, penetrating my skin
 
 you make my heart beat, steady as a clock
 your words touch as deep, and so does your cock
 your cock and your words, fills me with joy
 everything about you is perfect boy
 
 */