//
//  BeatTimelineItem.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.11.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OutlineScene.h"

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSInteger {
	TimelineScene = 1,
	TimelineSection,
	TimelineSynopsis,
	TimelineStoryline
} BeatTimelineItemType;

@protocol BeatTimelineItemDelegate <NSObject>
@property (nonatomic) NSColor *backgroundColor;
@property (nonatomic) OutlineScene *currentScene;
- (void)didSelectItem:(id)item;
@end

@interface BeatTimelineItem : NSView
@property (weak) OutlineScene *representedItem;
@property (nonatomic) bool selected;
- (id)initWithDelegate:(id<BeatTimelineItemDelegate>)delegate;
- (void)setItem:(OutlineScene*)scene rect:(NSRect)rect reset:(bool)reset;
- (void)setItem:(OutlineScene*)scene rect:(NSRect)rect reset:(bool)reset storyline:(bool)storyline;
- (void)select;
- (void)deselect;
@end

NS_ASSUME_NONNULL_END