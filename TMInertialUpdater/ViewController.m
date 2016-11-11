//
//  ViewController.m
//  TMInertialUpdater
//
//  Created by Tyler McAtee on 11/11/16.
//  Copyright © 2016 McAtee. All rights reserved.
//

#import "ViewController.h"
#import "TMInertialUpdater.h"

static const CGFloat Diameter = 100.0;

@interface ViewController() <TMInertialUpdaterDelegate>

@end

@implementation ViewController {
    UIView *_redView;
    TMInertialUpdater *_inertialUpdater;
    CGPoint _lastDragPoint;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    _redView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, Diameter, Diameter)];
    [_redView setBackgroundColor:[UIColor redColor]];
    [_redView.layer setPosition:self.view.layer.position];
    [self.view addSubview:_redView];
    
    _inertialUpdater = [[TMInertialUpdater alloc] init];
    [_inertialUpdater setDelegate:self];
    
    UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_handlePanGestureRecognizer:)];
    [_redView addGestureRecognizer:panGestureRecognizer];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Gesture Handling

CGPoint pointDelta(CGPoint p1, CGPoint p2) {
    return CGPointMake(p2.x - p1.x, p2.y - p1.y);
}

- (void)_handlePanGestureRecognizer:(UIPanGestureRecognizer *)panGestureRecognizer {
    switch (panGestureRecognizer.state) {
        case UIGestureRecognizerStateBegan:
        {
            _lastDragPoint = [panGestureRecognizer locationInView:self.view];
        }
            break;
        case UIGestureRecognizerStateChanged:
        {
            CGPoint currentDragPoint = [panGestureRecognizer locationInView:self.view];
            CGPoint dragDelta = pointDelta(_lastDragPoint, currentDragPoint);
            [_inertialUpdater addDragDelta:dragDelta];
            _lastDragPoint = currentDragPoint;
        }
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateFailed:
        {
            [_inertialUpdater endDragging];
        }
            break;
        default:
            break;
    }
}

#pragma mark - TMInertialUpdaterDelegate

- (void)inertialUpdater:(TMInertialUpdater *)updater scrolledWithDelta:(CGPoint)delta {
    CGAffineTransform transform = CGAffineTransformMakeTranslation(delta.x, delta.y);
    _redView.layer.position = CGPointApplyAffineTransform(_redView.layer.position, transform);
}

- (CGPoint)inertialUpdater:(TMInertialUpdater *)updater willDecelerateWithTarget:(CGPoint)decelerationTarget {
    CGPoint position = _redView.layer.position;
    
    CGPoint maxNegativeDelta = CGPointMake(-1.0 * position.x + Diameter/2.0, -1.0 * position.y + Diameter/2.0);
    CGPoint maxPositiveDelta = CGPointMake(CGRectGetMaxX(self.view.bounds) - position.x - Diameter/2.0, CGRectGetMaxY(self.view.bounds) - position.y - Diameter/2.0);
    
    CGFloat dx = MIN(MAX(maxNegativeDelta.x, decelerationTarget.x), maxPositiveDelta.x);
    CGFloat dy = MIN(MAX(maxNegativeDelta.y, decelerationTarget.y), maxPositiveDelta.y);
    
    return CGPointMake(dx, dy);
}
@end
