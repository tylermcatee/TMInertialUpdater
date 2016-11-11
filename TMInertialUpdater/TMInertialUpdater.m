//
//  TMInertialUpdater.m
//  MoveToCursor
//
//  Created by Tyler McAtee on 11/11/16.
//  Copyright © 2016 Apple. All rights reserved.
//

#import "TMInertialUpdater.h"

#define INVALID_POINT           (CGPointMake(NAN, NAN))
#define POINT_VALID(p)          (!isnan(p.x) && !isnan(p.y))

#define DECELERATION_CONSTANT   (0.994)
#define BOUNCE_CONSTANT         (0.985)


static inline CGFloat
RoundToPixel(CGFloat coordinate)
{
    static CGFloat __scale;
    static dispatch_once_t __once;
    dispatch_once(&__once, ^{
        __scale = [[UIScreen mainScreen] scale];
    });
    
    coordinate *= __scale;
    coordinate = roundf(coordinate);
    coordinate /= __scale;
    
    return coordinate;
}

static inline CGPoint
RoundPointToPixel(CGPoint point)
{
    return CGPointMake(RoundToPixel(point.x), RoundToPixel(point.y));
}


@implementation TMInertialUpdater {
    BOOL _dragging;
    CGPoint _velocity;
    CGPoint _lastVelocity;
    CGPoint _target;
    CGPoint _clientTarget;
    CGPoint _offset;
    CFTimeInterval _lastDecelerationUpdate;
    CFTimeInterval _lastInteractionTime;
    CADisplayLink *_displayLink;
    
    struct {
        unsigned inertialUpdater_willDecelerateWithTarget:1;
        unsigned inertialUpdater_scrolledWithDelta:1;
        unsigned inertialUpdaterFinishedScrolling:1;
    } _delegateFlags;
}

- (void)addDragDelta:(CGPoint)delta {
    [self _beginDraggingIfNecessary];
    [self _handleDragDelta:delta];
}

- (void)endDragging {
    _dragging = NO;
    _offset = CGPointZero;
    
    if (!POINT_VALID(_velocity)) {
        _velocity = CGPointZero;
    } else {
        _velocity.x = 0.75 * _velocity.x + 0.25 * _lastVelocity.x;
        _velocity.y = 0.75 * _velocity.y + 0.25 * _lastVelocity.y;
    }
    
    [self _computeDecelerationTarget];
    [self _updateDisplayLink];
    
    if (!_displayLink) {
        [self _updateDeletaWithFinishedScrolling];
    }
}

- (BOOL)_needsDisplayLink {
    if (_dragging || !POINT_VALID(_target))
        return NO;
    
    bool targetWithinTolerance = fabs(_offset.x - _target.x) < 0.5 && fabs(_offset.y - _target.y) < 0.5;
    bool clientTargetWithinTolerance = fabs(_offset.x - _clientTarget.x) < 0.5 && fabs(_offset.y - _clientTarget.y) < 0.5;
    
    return !(targetWithinTolerance && clientTargetWithinTolerance);
}

- (void)_updateDisplayLink {
    if ([self _needsDisplayLink]) {
        if (!_displayLink) {
            _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(_displayLinkFired:)];
            [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        }
    } else if (_displayLink) {
        [_displayLink invalidate];
        _displayLink = nil;
    }
}

- (CGPoint)_constrainedOffset:(CGPoint)offset {
    
    if ((offset.x > _clientTarget.x && _target.x >= offset.x) || (offset.x < _clientTarget.x && _target.x <= offset.x))
        offset.x = _clientTarget.x;
    
    if ((offset.y > _clientTarget.y && _target.y >= offset.y) || (offset.y < _clientTarget.y && _target.y <= offset.y))
        offset.y = _clientTarget.y;
    
    return offset;
}

- (void)_decelerate:(CFTimeInterval)dt {
    CGPoint lastOffset = _offset;
    
    CGFloat kn = powf(DECELERATION_CONSTANT, dt * 1000);
    _offset.x = (1 - kn) * _target.x + kn * _offset.x;
    _offset.y = (1 - kn) * _target.y + kn * _offset.y;
    
    CGPoint constrainedOffset = [self _constrainedOffset:_offset];
    
    CGFloat bn = powf(BOUNCE_CONSTANT, dt * 1000);
    if (fabs(constrainedOffset.x - _offset.x) > 0.001) {
        _offset.x = (1 - bn) * constrainedOffset.x + bn * _offset.x;
        _target.x = (1 - bn) * constrainedOffset.x + bn * _target.x;
    }
    
    if (fabs(constrainedOffset.y - _offset.y) > 0.001) {
        _offset.y = (1 - bn) * constrainedOffset.y + bn * _offset.y;
        _target.y = (1 - bn) * constrainedOffset.y + bn * _target.y;
    }
    
    CGPoint delta = CGPointMake(_offset.x - lastOffset.x, _offset.y - lastOffset.y);
    
    [self _updateDelegateWithDelta:delta];
}

- (void)_finalizeOffset {
    CGPoint finalDelta = CGPointMake(_clientTarget.x - _offset.x, _clientTarget.y - _offset.y);
    finalDelta = RoundPointToPixel(finalDelta);
    
    if (finalDelta.x != 0.0 || finalDelta.y != 0.0)
        [self _handleDragDelta:finalDelta];
}

- (void)_displayLinkFired:(CADisplayLink *)link {
    CFTimeInterval timestamp = [link timestamp];
    CFTimeInterval dt;
    
    if (isnan(_lastDecelerationUpdate)) {
        _lastDecelerationUpdate = timestamp;
        return;
    }
    
    dt = timestamp - _lastDecelerationUpdate;
    _lastDecelerationUpdate = timestamp;
    
    [self _decelerate:dt];
    [self _updateDisplayLink];
    
    if (!_displayLink) {
        [self _finalizeOffset];
        [self _updateDeletaWithFinishedScrolling];
    }
}

- (void)_beginDraggingIfNecessary {
    if (!_dragging) {
        _dragging = YES;
        _velocity = INVALID_POINT;
        _lastVelocity = INVALID_POINT;
        _clientTarget = INVALID_POINT;
        _offset = INVALID_POINT;
        _lastInteractionTime = CACurrentMediaTime();
        _lastDecelerationUpdate = NAN;
        
        [self _updateDisplayLink];
    }
}

- (void)_handleDragDelta:(CGPoint)delta {
    CFTimeInterval now = CACurrentMediaTime();
    
    _lastVelocity = _velocity;
    
    CFTimeInterval dt = now - _lastInteractionTime;
    _lastInteractionTime = now;
    
    if (dt < 0.001) {
        dt = 1.0 / 60.0;
    }
    
    _velocity = CGPointMake(delta.x / dt, delta.y / dt);
    
    if (!POINT_VALID(_lastVelocity)) {
        _lastVelocity = _velocity;
    }
    
    [self _updateDelegateWithDelta:delta];
}

- (void)_computeDecelerationTarget {
    const CGFloat kVelocityCoefficient = DECELERATION_CONSTANT / (1000 * (1 - DECELERATION_CONSTANT));
    
    CGPoint target;
    target.x = kVelocityCoefficient * _velocity.x;
    target.y = kVelocityCoefficient * _velocity.y;
    target = RoundPointToPixel(target);
    _target = target;
    
    CGPoint correctedTarget = [self _delegateWillDecelerateWithTarget:target];
    _clientTarget = correctedTarget;
    
    /* if target is less than client target, make client target the new target */
    if ((_clientTarget.x >= 0.0 == _target.x >= 0.0 && fabs(_target.x) < fabs(_clientTarget.x)) || _clientTarget.x >= 0.0 != _target.x >= 0.0)
        _target.x = _clientTarget.x;
    
    if ((_clientTarget.y >= 0.0 == _target.y >= 0.0 && fabs(_target.y) < fabs(_clientTarget.y)) || _clientTarget.y >= 0.0 != _target.y >= 0.0)
        _target.y = _clientTarget.y;
}

#pragma mark - Delegate

- (void)setDelegate:(id<TMInertialUpdaterDelegate>)delegate {
    _delegate = delegate;
    _delegateFlags.inertialUpdater_willDecelerateWithTarget = [_delegate respondsToSelector:@selector(inertialUpdater:willDecelerateWithTarget:)];
    _delegateFlags.inertialUpdater_scrolledWithDelta = [_delegate respondsToSelector:@selector(inertialUpdater:scrolledWithDelta:)];
    _delegateFlags.inertialUpdaterFinishedScrolling = [_delegate respondsToSelector:@selector(inertialUpdaterFinishedScrolling:)];
}

- (CGPoint)_delegateWillDecelerateWithTarget:(CGPoint)target {
    if (_delegateFlags.inertialUpdater_willDecelerateWithTarget) {
        CGPoint correctedTarget = [_delegate inertialUpdater:self willDecelerateWithTarget:target];
        return correctedTarget;
    }
    return target;
}

- (void)_updateDelegateWithDelta:(CGPoint)delta {
    if (_delegateFlags.inertialUpdater_scrolledWithDelta) {
        [_delegate inertialUpdater:self scrolledWithDelta:delta];
    }
}

- (void)_updateDeletaWithFinishedScrolling {
    if (_delegateFlags.inertialUpdaterFinishedScrolling) {
        [_delegate inertialUpdaterFinishedScrolling:self];
    }
}

@end
