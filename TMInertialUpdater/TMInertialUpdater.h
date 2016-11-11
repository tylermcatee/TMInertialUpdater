//
//  TMInertialUpdater.h
//  MoveToCursor
//
//  Created by Tyler McAtee on 11/11/16.
//  Copyright © 2016 Apple. All rights reserved.
//

#import <UIKit/UIKit.h>

@class TMInertialUpdater;

@protocol TMInertialUpdaterDelegate <NSObject>
@optional
/**
 *  @method inertialUpdater:willDecelerateWithTarget:
 *  @param updater The inertial updater
 *  @param decelerationTarget The point the inertial updater will decelerate towards
 *  @return A corrected target incase the target passed in by this method is outside the desired bounds
 */
- (CGPoint)inertialUpdater:(TMInertialUpdater *)updater willDecelerateWithTarget:(CGPoint)decelerationTarget;
/**
 *  @method inertialUpdater:scrolledWithDelta:
 *  @param updater The inertial updater
 *  @param delta The change in position from the updater
 *  @discussion Use this callback to update your views position
 */
- (void)inertialUpdater:(TMInertialUpdater *)updater scrolledWithDelta:(CGPoint)delta;
/**
 *  @method inertialUpdaterFinishedScrolling:
 *  @param updater The inertial updater
 *  @discussion Called when no more updates should be expected from the inertial updater.
 */
- (void)inertialUpdaterFinishedScrolling:(TMInertialUpdater *)updater;

@end

@interface TMInertialUpdater : NSObject

/**
 *  @method addDragDelta:
 *  @param delta The change in position for the updater
 *  @discussion Feed in deltas to the updater and it will calculate velocity when you call endDragging
 */
- (void)addDragDelta:(CGPoint)delta;

- (void)endDragging;

@property (nonatomic, unsafe_unretained) id<TMInertialUpdaterDelegate> delegate;
@end
