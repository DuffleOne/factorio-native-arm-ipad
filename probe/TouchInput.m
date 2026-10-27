// Buttons, the left-thumb modifiers and the stick. See TouchControls.h.
#import "TouchControls.h"

NSNotificationName const FPInputChanged=@"FPInputChanged";
const NSTimeInterval FPHoldDelay=0.35;

UIImpactFeedbackGenerator *FPPressFeedback(void) {
    static UIImpactFeedbackGenerator *generator;
    static dispatch_once_t once;
    dispatch_once(&once,^{ generator=[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight]; });
    return generator;
}

static const int FPModScans[4][2]={{FPModShift,SDL_SCANCODE_LSHIFT},{FPModCtrl,SDL_SCANCODE_LCTRL},
                                   {FPModAlt,SDL_SCANCODE_LALT},{FPModCmd,SDL_SCANCODE_LGUI}};

void FPClick(int button,BOOL down) { FPIMouseButton(button,down); }

void FPTapKey(int scan,FPMods mods) {
    for (int i=0;i<4;i++) if (mods&FPModScans[i][0]) FPIKeyboard(FPModScans[i][1],1);
    FPIKeyboard(scan,1); FPIKeyboard(scan,0);
    for (int i=3;i>=0;i--) if (mods&FPModScans[i][0]) FPIKeyboard(FPModScans[i][1],0);
}

@interface FPInputButton ()
@property(nonatomic) BOOL addedCommand;
@end
@implementation FPInputButton
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self=[super initWithFrame:frame])) {
        [self addTarget:self action:@selector(down) forControlEvents:UIControlEventTouchDown];
        [self addTarget:self action:@selector(up) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel];
    }
    return self;
}
// What the key types with the current Shift and Caps Lock state.
- (NSString *)typedText {
    BOOL shift=(SDL_GetModState()&FPI_MOD_SHIFT)!=0;
    BOOL caps=(SDL_GetModState()&FPI_MOD_CAPS)!=0;
    NSString *text=(shift!=caps) ? self.text.uppercaseString : self.text;
    if (shift && self.text.length==1) {
        NSString *plain=@"`1234567890-=[]\\;',./";
        NSString *shifted=@"~!@#$%^&*()_+{}|:\"<>?";
        NSRange index=[plain rangeOfString:self.text];
        if (index.location!=NSNotFound) text=[shifted substringWithRange:NSMakeRange(index.location,1)];
    }
    return text;
}
- (void)sendDown:(BOOL)down {
    if (self.inputHeld==down) return;
    self.inputHeld=down;
    if (down && self.withCommand && !(SDL_GetModState()&FPI_MOD_GUI)) { self.addedCommand=YES; FPIKeyboard(SDL_SCANCODE_LGUI,1); }
    if (self.scan) FPIKeyboard(self.scan,down);
    if (!down && self.addedCommand) { self.addedCommand=NO; FPIKeyboard(SDL_SCANCODE_LGUI,0); }
    if (down && self.text && !(SDL_GetModState()&(FPI_MOD_CTRL|FPI_MOD_ALT|FPI_MOD_GUI))) FPIText(self.typedText.UTF8String);
    if (self.mouseButton) FPClick(self.mouseButton,down);
    if (self.wheel && down) FPIWheel(self.wheel);
    if (down) [FPPressFeedback() impactOccurred];
    [self refreshAppearance];
    [NSNotificationCenter.defaultCenter postNotificationName:FPInputChanged object:self];
}
- (void)down { [self sendDown:self.latch ? !self.inputHeld : YES]; }
- (void)up {
    if (!self.latch) [self sendDown:NO];
    if (self.tapScan) FPTapKey(self.tapScan,self.tapMods);
    if (self.onTap) self.onTap(self);
}
- (void)setHighlighted:(BOOL)highlighted { [super setHighlighted:NO]; }
- (void)setLit:(BOOL)lit { _lit=lit; [self refreshAppearance]; }
- (void)refreshAppearance {
    BOOL on=self.inputHeld || self.lit;
    UIColor *ink=on ? FPInk() : UIColor.whiteColor;
    self.backgroundColor=on ? FPAccent() : (self.standalone ? FPSurface() : UIColor.clearColor);
    self.layer.borderWidth=self.standalone && !on ? 1 : 0;
    self.tintColor=ink; [self setTitleColor:ink forState:UIControlStateNormal];
    self.transform=self.inputHeld && !self.latch ? CGAffineTransformMakeScale(0.93,0.93) : CGAffineTransformIdentity;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    UIImage *image=self.imageView.image;
    if (!self.captioned || !image) return;
    CGSize size=self.bounds.size, icon=image.size;
    CGFloat captionHeight=ceil(self.titleLabel.font.lineHeight), top=floor((size.height-icon.height-captionHeight)/2);
    self.imageView.frame=CGRectMake(floor((size.width-icon.width)/2),top,icon.width,icon.height);
    self.titleLabel.frame=CGRectMake(3,top+icon.height,size.width-6,captionHeight);
}
@end

// Baseline only: a plain latch, until tap, hold and double-tap arrive.
@implementation FPModifierButton {
    UILabel *_title, *_caption;
}
+ (instancetype)modifierWithTitle:(NSString *)title caption:(NSString *)caption scan:(int)scan {
    FPModifierButton *b=[[self alloc] initWithFrame:CGRectZero];
    b->_scan=scan;
    b->_title=[UILabel new]; b->_title.text=title; b->_title.textColor=UIColor.whiteColor;
    b->_title.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold]; b->_title.textAlignment=NSTextAlignmentCenter;
    b->_caption=[UILabel new]; b->_caption.text=caption; b->_caption.textColor=[UIColor colorWithWhite:1 alpha:0.6];
    b->_caption.font=[UIFont systemFontOfSize:10 weight:UIFontWeightMedium]; b->_caption.textAlignment=NSTextAlignmentCenter;
    [b addSubview:b->_title]; [b addSubview:b->_caption];
    b.backgroundColor=FPSurface(); b.layer.borderWidth=1; b.layer.borderColor=FPStroke().CGColor; b.layer.cornerRadius=12;
    b.accessibilityLabel=title; b.isAccessibilityElement=YES;
    [b addTarget:b action:@selector(tapped) forControlEvents:UIControlEventTouchDown];
    return b;
}
- (void)tapped {
    _modifierState=_modifierState==FPModifierOff ? FPModifierLocked : FPModifierOff;
    FPIKeyboard(_scan,_modifierState!=FPModifierOff);
    self.layer.borderColor=(_modifierState==FPModifierOff ? FPStroke() : FPAccent()).CGColor;
    [FPPressFeedback() impactOccurred];
    [NSNotificationCenter.defaultCenter postNotificationName:FPInputChanged object:self];
}
- (void)armOnce { if (_modifierState==FPModifierOff) [self tapped]; }
- (void)reset { if (_modifierState!=FPModifierOff) [self tapped]; }
- (void)layoutSubviews {
    [super layoutSubviews];
    CGSize s=self.bounds.size;
    _title.frame=CGRectMake(2,s.height*0.18,s.width-4,s.height*0.42);
    _caption.frame=CGRectMake(2,s.height*0.58,s.width-4,s.height*0.26);
}
@end

@implementation FPJoystick {
    CGPoint _offset;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self=[super initWithFrame:frame])) {
        self.backgroundColor=UIColor.clearColor; self.opaque=NO; self.direction=-1;
        self.contentMode=UIViewContentModeRedraw; self.accessibilityLabel=@"Movement stick";
    }
    return self;
}
static BOOL FPDirectionHas(int direction,int a,int b,int c) { return direction==a || direction==b || direction==c; }
- (void)updatePoint:(CGPoint)p {
    CGFloat radius=self.bounds.size.width/2;
    CGFloat dx=(p.x-radius)/radius, dy=(p.y-radius)/radius, length=hypot(dx,dy);
    if (length>1) { dx/=length; dy/=length; }
    _offset=CGPointMake(dx,dy);
    // Eight equal sectors make diagonals as easy to hold as the cardinal directions.
    int direction=length<0.22 ? -1 : ((int)lround(atan2(dy,dx)/(M_PI/4))+8)%8;
    if (direction!=self.direction) {
        self.direction=direction;
        FPIKeyboard(SDL_SCANCODE_D,FPDirectionHas(direction,7,0,1));
        FPIKeyboard(SDL_SCANCODE_S,FPDirectionHas(direction,1,2,3));
        FPIKeyboard(SDL_SCANCODE_A,FPDirectionHas(direction,3,4,5));
        FPIKeyboard(SDL_SCANCODE_W,FPDirectionHas(direction,5,6,7));
    }
    [self setNeedsDisplay];
}
- (void)reset { [self updatePoint:CGPointMake(self.bounds.size.width/2,self.bounds.size.height/2)]; }
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    CGFloat r=self.bounds.size.width/2+18;
    return hypot(point.x-self.bounds.size.width/2,point.y-self.bounds.size.height/2)<=r;
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updatePoint:[touches.anyObject locationInView:self]]; }
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self touchesBegan:touches withEvent:event]; }
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self reset]; }
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self reset]; }
- (void)drawRect:(CGRect)rect {
    CGFloat r=self.bounds.size.width/2;
    UIBezierPath *base=[UIBezierPath bezierPathWithOvalInRect:CGRectInset(self.bounds,1,1)];
    [FPSurface() setFill]; [base fill];
    [FPStroke() setStroke]; base.lineWidth=1; [base stroke];
    CGContextRef context=UIGraphicsGetCurrentContext();
    const int lit[4][3]={{7,0,1},{1,2,3},{3,4,5},{5,6,7}};
    for (int i=0;i<4;i++) {
        CGContextSaveGState(context);
        CGContextTranslateCTM(context,r,r); CGContextRotateCTM(context,i*M_PI/2);
        CGFloat x=r-r*0.16, size=r*0.07;
        UIBezierPath *chevron=[UIBezierPath bezierPath];
        [chevron moveToPoint:CGPointMake(x-size,-size*1.6)];
        [chevron addLineToPoint:CGPointMake(x+size,0)];
        [chevron addLineToPoint:CGPointMake(x-size,size*1.6)];
        chevron.lineWidth=2; chevron.lineCapStyle=kCGLineCapRound; chevron.lineJoinStyle=kCGLineJoinRound;
        [(FPDirectionHas(self.direction,lit[i][0],lit[i][1],lit[i][2]) ? FPAccent() : [UIColor colorWithWhite:1 alpha:0.35]) setStroke];
        [chevron stroke];
        CGContextRestoreGState(context);
    }
    CGFloat thumb=r*0.4, travel=r-thumb-r*0.08;
    CGRect knob=CGRectMake(r-thumb+_offset.x*travel,r-thumb+_offset.y*travel,thumb*2,thumb*2);
    UIBezierPath *path=[UIBezierPath bezierPathWithOvalInRect:knob];
    [[UIColor colorWithWhite:1 alpha:self.direction<0 ? 0.55 : 0.9] setFill]; [path fill];
    [[UIColor colorWithWhite:0 alpha:0.25] setStroke]; path.lineWidth=1; [path stroke];
}
@end
