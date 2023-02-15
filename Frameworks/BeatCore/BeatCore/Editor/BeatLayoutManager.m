//
//  BeatLayoutManager.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.2.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatLayoutManager.h"
#import <BeatCore/BeatCore.h>
#import <BeatThemes/BeatThemes.h>
#import <BeatCore/BeatCore-Swift.h>

//#import "BeatTextView.h"
//#import "BeatMeasure.h"
//#import "Beat-Swift.h"
#import "BeatRevisions.h"

@interface BeatLayoutManager()
@property (nonatomic) NSMutableParagraphStyle* _Nullable markerStyle;
@property (nonatomic) NSMutableParagraphStyle* _Nullable sceneNumberStyle;
@end

@implementation BeatLayoutManager

@dynamic delegate;

- (instancetype)initWithDelegate:(id<BeatEditorDelegate>)editorDelegate
{
	self = [super init];
	if (self) {
		_editorDelegate = editorDelegate;
	}
	return self;
}

- (void)drawGlyphsForGlyphRange:(NSRange)glyphsToShow atPoint:(NSPoint)origin
{
	if (_markerStyle == nil) {
		_markerStyle = NSMutableParagraphStyle.new;
		_markerStyle.minimumLineHeight = self.editorDelegate.editorLineHeight;
	}
	
    /*
	if (!self.textView) {
		NSLog(@"WARNING: No text view set for BeatLayoutManager.");
		[super drawGlyphsForGlyphRange:glyphsToShow atPoint:origin];
		return;
	}
     */
	
	[super drawGlyphsForGlyphRange:glyphsToShow atPoint:origin];
		
	NSRange charRange = [self characterRangeForGlyphRange:glyphsToShow actualGlyphRange:nil];
	
	[self drawSceneNumberForGlyphRange:glyphsToShow charRange:charRange];
	//[self drawDisclosureForRange:glyphsToShow charRange:charRange];
	[self drawRevisionMarkers:glyphsToShow];
}

- (void)drawDisclosureForRange:(NSRange)glyphRange charRange:(NSRange)charRange
{
    BXTextView* textView = self.editorDelegate.getTextView;
    
	NSInteger i = [self.editorDelegate.parser lineIndexAtPosition:charRange.location];
	ContinuousFountainParser* parser = self.editorDelegate.parser;
	
	NSMutableArray<Line*>* lines = NSMutableArray.new;
	for (; i < parser.lines.count; i++) {
		Line* l = parser.lines[i];
		if (!NSLocationInRange(l.position, charRange)) break;
		
		if (l.type == section) [lines addObject:l];
	}
	
	for (Line* l in lines) {
		NSRange sectionGlyphRange = [self glyphRangeForCharacterRange:NSMakeRange(l.position, 1) actualCharacterRange:nil];
		NSRect r = [self boundingRectForGlyphRange:sectionGlyphRange inTextContainer:self.textContainers.firstObject];
		
		NSRect triangle = NSMakeRect(textView.textContainerInset.width, r.origin.y + textView.textContainerInset.height + r.size.height - 15, 12, 12);
		[NSColor.redColor setFill];
		NSRectFill(triangle);
	}
}

- (void)drawSceneNumberForGlyphRange:(NSRange)glyphRange charRange:(NSRange)charRange
{
    NSTextView* textView = self.firstTextView;
    
	// Scene number drawing is off, return
	if (!self.editorDelegate.showSceneNumberLabels) return;
	
	// Create the style if needed
	if (_sceneNumberStyle == nil) {
		_sceneNumberStyle = NSMutableParagraphStyle.new;
		_sceneNumberStyle.minimumLineHeight = self.editorDelegate.editorLineHeight;
	}
		
	[self.textStorage enumerateAttribute:@"representedLine" inRange:charRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		Line* line = (Line*)value;
		if (line == nil || line.type != heading) return;
		
		NSRange headingRange = NSMakeRange(line.position, 1);
		if (self.editorDelegate.hideFountainMarkup) {
			if (line.length > 1) headingRange.location += 1;
			else headingRange = line.range;
		}
		
		NSRange lineRange = [self glyphRangeForCharacterRange:headingRange actualCharacterRange:nil];
		NSRect boundingRect = [self boundingRectForGlyphRange:lineRange inTextContainer:self.textContainers.firstObject];
		
		// Calculate rect for the marker position
		NSRect rect = NSMakeRect(textView.textContainerInset.width,
								 textView.textContainerInset.height + boundingRect.origin.y,
								 7.5 * line.sceneNumber.length,
								 boundingRect.size.height + 1.0);
		
		NSColor* color;
		if (line.color.length > 0) color = [BeatColors color:line.color];
		if (color == nil) color = ThemeManager.sharedManager.textColor.effectiveColor;
		
		NSString *sceneNumber = line.sceneNumber;
		[sceneNumber drawAtPoint:rect.origin withAttributes:@{
			NSFontAttributeName: self.editorDelegate.courier,
			NSForegroundColorAttributeName: color,
			NSParagraphStyleAttributeName: self.sceneNumberStyle
		}];
	}];
}


-(void)drawRevisionMarkers:(NSRange)glyphRange
{
	/*
	 
	 This works in a peculiar way:
	 We'll store the NSRect of each marker range into a set using NSNumber, so there will
	 never be two overlapping rects. Those rects are put in a dictionary entry under the
	 revision color.
	 
	 After all glyphs have been iterated, we'll draw the marker strings and draw a rect
	 under them - and voilà: latest revision markers block out the earlier ones.
	 
	 It's a bit convoluted scheme, but works surprisingly well and efficiently.
	 
	 2022/12: Thanks, past me, for this completely useless documentation.
	 
	*/
	
	/*
	NSArray<NSString*>* shownRevisions = self.textView.editorDelegate.shownRevisionGenerations;
	*/
    //NSTextView* textView = self.firstTextView;
    
	NSArray<NSString*>* shownRevisions = BeatRevisions.revisionColors;
	
	NSTextStorage* textStorage = self.textStorage;
	NSTextContainer* textContainer = self.textContainers.firstObject;
	NSSize offset = textContainer.textView.textContainerInset;
	
	NSMutableDictionary<NSString*, NSMutableSet<NSValue*>*> *revisions = NSMutableDictionary.new;
	for (NSString *string in BeatRevisions.revisionColors) revisions[string] = NSMutableSet.new;
	
	while (glyphRange.length > 0) {
		// Get character range for the range we're displaying
		NSRange charRange = [self characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL], attributeCharRange, attributeGlyphRange;
		
		// Get revision attributes at this range
		BeatRevisionItem *revision = [textStorage attribute:BeatRevisions.attributeKey
													atIndex:charRange.location longestEffectiveRange:&attributeCharRange
													inRange:charRange];
			
		// Get actual glyphs
		attributeGlyphRange = [self glyphRangeForCharacterRange:attributeCharRange actualCharacterRange:NULL];
		// Get intersection range between the glyphs being displayed and the actual attribute range
		attributeGlyphRange = NSIntersectionRange(attributeGlyphRange, glyphRange);
				
		// Check if there actually was a revision attribute
		if ((revision.type == RevisionAddition || revision.type == RevisionCharacterRemoved) &&
			revision != nil && revision.colorName != nil && [shownRevisions containsObject:revision.colorName.lowercaseString]) {
			// Get bounding rect for the range
			NSRect boundingRect = [self boundingRectForGlyphRange:attributeGlyphRange
												  inTextContainer:textContainer];
			
			// Calculate rect for the marker position
			NSRect rect = NSMakeRect(offset.width + _editorDelegate.documentWidth - 22,
									offset.height + boundingRect.origin.y,
									 22,
									 boundingRect.size.height + 1.0);
			
			// Add the marker to dictionary:
			// dict["colorName"][] -> rect
			[revisions[revision.colorName] addObject:[NSNumber valueWithRect:rect]];
		}
				
		glyphRange.length = NSMaxRange(glyphRange) - NSMaxRange(attributeGlyphRange);
		glyphRange.location = NSMaxRange(attributeGlyphRange);
	}
	
	for (NSString *color in BeatRevisions.revisionColors) {
		[NSGraphicsContext saveGraphicsState];
		
		NSMutableSet *rects = revisions[color];
		NSString *marker = BeatRevisions.revisionMarkers[color];
		NSColor *bgColor = ThemeManager.sharedManager.backgroundColor.effectiveColor;
		
		[rects enumerateObjectsUsingBlock:^(id  _Nonnull obj, BOOL * _Nonnull stop) {
			NSRect rect = [(NSValue*)obj rectValue];
			NSMutableString *markerStr = NSMutableString.new;
			NSUInteger lineCount = round(rect.size.height / self.editorDelegate.editorLineHeight);
			
			// Create markers by line count
			for (NSUInteger i=0; i<lineCount; i++) {
				[markerStr appendFormat:@"%@\n", marker];
			}

			// Draw a background rect under the marker to block out earlier markers
			[bgColor setFill];
			NSRectFill(rect);
			
			// Draw string
			[markerStr drawAtPoint:rect.origin withAttributes:@{
				NSFontAttributeName: self.editorDelegate.courier,
				NSForegroundColorAttributeName: ThemeManager.sharedManager.textColor.effectiveColor,
				NSParagraphStyleAttributeName: _markerStyle
			}];
		}];
		
		[NSGraphicsContext restoreGraphicsState];
	}
}

-(void)drawBackgroundForGlyphRange:(NSRange)glyphsToShow atPoint:(NSPoint)origin
{
	static NSMutableDictionary* bgColors;
	if (bgColors == nil) bgColors = NSMutableDictionary.new;
    
    CGSize inset = self.firstTextView.textContainerInset;
    NSTextView* textView = self.firstTextView;
    
	[self enumerateLineFragmentsForGlyphRange:glyphsToShow usingBlock:^(NSRect rect, NSRect usedRect, NSTextContainer * _Nonnull textContainer, NSRange glyphRange, BOOL * _Nonnull stop) {
		NSRange charRange = [self characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL];
		
		[self.textStorage enumerateAttributesInRange:charRange options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
			if (range.location < 0 || NSMaxRange(range) < 0) return;
			            
			BeatRevisionItem* revision = attrs[BeatRevisions.attributeKey];
			BeatTag* tag = attrs[BeatTagging.attributeKey];
			BeatReviewItem *review = attrs[BeatReview.attributeKey];
			
			// Remove line breaks from the range (begin enumeration from the end to catch them as soon as possible)
			NSRange rRange = range;
			for (NSInteger i = NSMaxRange(rRange) - 1; i >= rRange.location; i--) {
				if (i < 0) break; // Why do we need this?
				if ([self.textStorage.string characterAtIndex:i] == '\n') {
					rRange.length = NSMaxRange(rRange) - i - 1;
					break;
				}
			}
			
			NSRange usedRange = [self glyphRangeForCharacterRange:rRange actualCharacterRange:nil];
			NSRect aRect = [self boundingRectForGlyphRange:usedRange inTextContainer:self.textContainers.firstObject];
			aRect.origin.x += inset.width;
			aRect.origin.y += inset.height;
			
			if (review != nil && !review.emptyReview) {
				if (bgColors[@"review"] == nil) {
					NSColor *reviewColor = BeatReview.reviewColor;
					bgColors[@"review"] = [reviewColor colorWithAlphaComponent:.5];
				}
				
				NSColor *color = bgColors[@"review"];
				[color setFill];
				
				NSRange fullGlyphRange = [self glyphRangeForCharacterRange:rRange actualCharacterRange:nil];
				NSRect fullRect = [self boundingRectForGlyphRange:fullGlyphRange inTextContainer:self.textContainers.firstObject];
				bool fullLine = (fullGlyphRange.length == glyphRange.length - 1);
				
				fullRect.origin.x += inset.width;
				fullRect.origin.y += inset.height;
				
				if (fullLine) {
                    CGFloat padding = textView.textContainer.lineFragmentPadding;
					fullRect.origin.x = inset.width + padding;
					fullRect.size.width = inset.width - padding * 2;
				}
				
				//NSBezierPath* path = [NSBezierPath bezierPathWithRoundedRect:fullRect xRadius:2.0 yRadius:2.0];
				//[path fill];
				NSRectFill(fullRect);
			}
			
			if (tag != nil && self.editorDelegate.showTags) {
				if (bgColors[tag.typeAsString] == nil) {
					bgColors[tag.typeAsString] = [[BeatTagging colorFor:tag.type] colorWithAlphaComponent:0.5];
				}

				NSColor *tagColor = bgColors[tag.typeAsString];
				[tagColor setFill];
				
				NSRectFill(aRect);
			}
			
			// Draw revision backgrounds last, so the underlines go on top of other stuff.
			if (revision.type != RevisionNone && self.editorDelegate.showRevisions && rRange.length > 0) {
				NSRect revisionRect = aRect;
				
				if (bgColors[revision.colorName] == nil) {
					bgColors[revision.colorName] = [[BeatColors color:revision.colorName] colorWithAlphaComponent:.3];
				}
				[bgColors[revision.colorName] setFill];
				
				revisionRect.origin.y += revisionRect.size.height - 1.0;
				revisionRect.size.height = 2.0;
				
				NSRectFill(revisionRect);
			}
		}];
	}];
	
	[super drawBackgroundForGlyphRange:glyphsToShow atPoint:origin];

}


-(NSArray*)rectsForGlyphRange:(NSRange)glyphsToShow
{
	NSMutableArray *rects = NSMutableArray.new;
	NSTextContainer *tc = self.textContainers.firstObject;
	
	[self enumerateLineFragmentsForGlyphRange:glyphsToShow usingBlock:^(NSRect rect, NSRect usedRect, NSTextContainer * _Nonnull textContainer, NSRange glyphRange, BOOL * _Nonnull stop) {
		NSRect lfRect = [self boundingRectForGlyphRange:NSIntersectionRange(glyphsToShow, glyphRange) inTextContainer:tc];
		[rects addObject:[NSNumber valueWithRect:lfRect]];
	}];
	
	return rects;
}

@end