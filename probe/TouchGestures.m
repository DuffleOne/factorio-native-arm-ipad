// Touches on the game itself: Direct and Precise modes, and a hardware mouse's cursor.
// See TouchControls.h.
#import "TouchControls.h"

@interface FPPointerSurface ()
@property(nonatomic) CGPoint cursorPoint;
@property(nonatomic,strong) CADisplayLink *cursorUpdates;
@end
@implementation FPPointerSurface
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self=[super initWithFrame:frame])) {
        self.backgroundColor=UIColor.clearColor; self.opaque=NO;
        self.contentMode=UIViewContentModeRedraw;
    }
    return self;
}
- (void)didMoveToWindow {
    [super didMoveToWindow];
    [self.cursorUpdates invalidate]; self.cursorUpdates=nil;
    if (self.window) {
        self.cursorUpdates=[CADisplayLink displayLinkWithTarget:self selector:@selector(refreshCursor)];
        self.cursorUpdates.preferredFramesPerSecond=30;
        [self.cursorUpdates addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    }
}
- (CGRect)gameRect {
    UIView *game=self.window.rootViewController.view;
    if (!game || !game.window) return self.bounds;
    CGRect rect=[game convertRect:game.bounds toView:self];
    return rect.size.width>0 && rect.size.height>0 ? rect : self.bounds;
}
- (BOOL)drawsCursor { return self.mode==FPTouchPrecise || self.hardwareCursor; }
- (void)refreshCursor {
    if (self.hidden || !self.drawsCursor) return;
    float x,y;
    if (!FPIGetPointer(&x,&y)) return;
    CGRect game=[self gameRect];
    CGPoint p=CGPointMake(CGRectGetMinX(game)+x*game.size.width,
                          CGRectGetMinY(game)+y*game.size.height);
    if (!CGPointEqualToPoint(p,self.cursorPoint)) { self.cursorPoint=p; [self setNeedsDisplay]; }
}
- (void)drawRect:(CGRect)rect {
    if (!self.drawsCursor) return;
    // Arrow tip is the exact SDL click position, including after lifting a finger.
    CGContextRef context=UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    CGContextTranslateCTM(context,self.cursorPoint.x,self.cursorPoint.y);
    UIBezierPath *arrow=[UIBezierPath bezierPath];
    [arrow moveToPoint:CGPointZero];
    [arrow addLineToPoint:CGPointMake(1,28)];
    [arrow addLineToPoint:CGPointMake(8,21)];
    [arrow addLineToPoint:CGPointMake(14,34)];
    [arrow addLineToPoint:CGPointMake(20,31)];
    [arrow addLineToPoint:CGPointMake(14,18)];
    [arrow addLineToPoint:CGPointMake(24,17)]; [arrow closePath];
    arrow.lineWidth=3; arrow.lineJoinStyle=kCGLineJoinRound;
    [UIColor.blackColor setStroke]; [arrow stroke];
    [UIColor.whiteColor setFill]; [arrow fill];
    CGContextRestoreGState(context);
}
- (void)move:(UITouch *)touch {
    CGPoint p=[touch locationInView:self];
    CGRect game=[self gameRect];
    FPIPointer(MAX(0,MIN(1,(p.x-CGRectGetMinX(game))/game.size.width)),
               MAX(0,MIN(1,(p.y-CGRectGetMinY(game))/game.size.height)));
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self move:touches.anyObject]; }
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self move:touches.anyObject]; }
- (void)reset {}
@end
