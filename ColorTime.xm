#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface CContact : NSObject
@property(nonatomic, copy) NSString *m_nsUsrName;
@property(nonatomic, copy) NSString *userName;
@end

static BOOL gBLAuthorized = NO;

static NSArray<NSString *> *BLAuthRoomIDs(void) {
    static NSArray<NSString *> *ids = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ids = @[
            @"45622129757@chatroom",
            @"53529734076@chatroom"
        ];
    });
    return ids;
}

static void BLUpdateAuthWithChatID(NSString *chatID) {
    if (gBLAuthorized) return;
    if (chatID.length == 0) return;
    NSArray *auth = BLAuthRoomIDs();
    if (auth.count == 0) {
        gBLAuthorized = YES;
        return;
    }
    for (NSString *aid in auth) {
        if ([aid isEqualToString:chatID]) {
            gBLAuthorized = YES;
            break;
        }
    }
}

static BOOL BLIsAuthorized(void) {
    if (gBLAuthorized) return YES;
    NSArray *auth = BLAuthRoomIDs();
    if (auth.count == 0) return YES;
    return NO;
}

static BOOL BLIsInWeChatChatVC(UIView *v) {
    UIResponder *r = v;
    while (r) {
        if ([NSStringFromClass([r class]) isEqualToString:@"BaseMsgContentViewController"]) {
            return YES;
        }
        r = [r nextResponder];
    }
    return NO;
}

// 是否在 ChatTimeCellView 里面（大时间那条）
static BOOL BLIsInChatTimeCell(UIView *v) {
    UIView *cur = v.superview;
    while (cur) {
        NSString *cls = NSStringFromClass([cur class]);
        if ([cls rangeOfString:@"ChatTimeCellView"].location != NSNotFound) {
            return YES;
        }
        cur = cur.superview;
    }
    return NO;
}

static NSString *BLCleanString(NSString *s) {
    if (!s) return @"";
    return [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static BOOL BLTextLooksLikeTime(NSString *t) {
    t = BLCleanString(t);
    if (t.length == 0) return NO;

    static NSRegularExpression *rePlain = nil;
    static NSRegularExpression *reWithDay = nil;
    static NSRegularExpression *reDateDash = nil;
    static NSRegularExpression *reWeekTime = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSError *err = nil;
        rePlain = [NSRegularExpression regularExpressionWithPattern:@"^\\d{1,2}:\\d{2}(:\\d{2})?$"
                                                             options:0
                                                               error:&err];
        reWithDay = [NSRegularExpression regularExpressionWithPattern:@"^(昨|前)天\\s*\\d{1,2}:\\d{2}(:\\d{2})?$"
                                                              options:0
                                                                error:&err];
        reDateDash = [NSRegularExpression regularExpressionWithPattern:@"^\\d{2}-\\d{2}-\\d{2}(\\s*[AP]M)?$"
                                                               options:0
                                                                 error:&err];
        reWeekTime = [NSRegularExpression regularExpressionWithPattern:@"^(?:周|星期)[一二三四五六日天]\\s*\\d{1,2}:\\d{2}(:\\d{2})?$"
                                                               options:0
                                                                 error:&err];
    });

    NSRange full = NSMakeRange(0, t.length);
    if ([rePlain firstMatchInString:t options:0 range:full]) return YES;
    if ([reWithDay firstMatchInString:t options:0 range:full]) return YES;
    if ([reDateDash firstMatchInString:t options:0 range:full]) return YES;
    if ([reWeekTime firstMatchInString:t options:0 range:full]) return YES;

    BOOL hasColon = [t rangeOfString:@":"].location != NSNotFound;
    if (!hasColon) return NO;

    BOOL hasCNDate = ([t rangeOfString:@"月"].location != NSNotFound &&
                      [t rangeOfString:@"日"].location != NSNotFound);
    BOOL hasWeek = ([t rangeOfString:@"周"].location != NSNotFound ||
                    [t rangeOfString:@"星期"].location != NSNotFound);

    if (hasCNDate || hasWeek) return YES;

    return NO;
}

static UIColor *BLGradientTextColor(void) {
    static UIColor *color = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGSize size = CGSizeMake(32, 16);
        UIGraphicsBeginImageContextWithOptions(size, NO, 0);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        if (!ctx) {
            UIGraphicsEndImageContext();
            color = [UIColor whiteColor];
            return;
        }

        UIColor *c1 = [UIColor colorWithRed:0.73 green:0.62 blue:0.96 alpha:0.9];
        UIColor *c2 = [UIColor colorWithRed:0.57 green:0.70 blue:0.96 alpha:0.9];
        UIColor *c3 = [UIColor colorWithRed:0.91 green:0.54 blue:0.62 alpha:0.9];
        UIColor *c4 = [UIColor colorWithRed:0.78 green:0.80 blue:0.84 alpha:0.9];

        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        NSArray *colors = @[(__bridge id)c1.CGColor,
                            (__bridge id)c2.CGColor,
                            (__bridge id)c3.CGColor,
                            (__bridge id)c4.CGColor];
        CGFloat locations[] = {0.0, 0.33, 0.66, 1.0};
        CGGradientRef grad = CGGradientCreateWithColors(space, (__bridge CFArrayRef)colors, locations);

        CGPoint start = CGPointMake(0, size.height / 2.0);
        CGPoint end   = CGPointMake(size.width, size.height / 2.0);
        CGContextDrawLinearGradient(ctx, grad, start, end, 0);

        UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
        CGGradientRelease(grad);
        CGColorSpaceRelease(space);
        UIGraphicsEndImageContext();

        if (!img) {
            color = [UIColor whiteColor];
        } else {
            color = [UIColor colorWithPatternImage:img];
        }
    });
    return color;
}

static BOOL BLLabelShouldGradient(UILabel *lab) {
    if (!lab) return NO;
    if (!BLIsAuthorized()) return NO;
    if (!BLIsInWeChatChatVC(lab)) return NO;

    BOOL isChatTime = BLIsInChatTimeCell(lab);

    NSString *t = nil;
    if (lab.attributedText && lab.attributedText.string.length > 0) {
        t = lab.attributedText.string;
    } else {
        t = lab.text;
    }
    if (!BLTextLooksLikeTime(t)) return NO;

    CGFloat fontSize = lab.font.pointSize;
    if (!isChatTime && fontSize > 18.0) return NO;

    return YES;
}

static void BLMaybeApplyGradientToLabel(UILabel *lab) {
    if (!BLLabelShouldGradient(lab)) return;
    lab.textColor = BLGradientTextColor();
}

%hook UILabel

- (void)setText:(NSString *)text {
    %orig(text);
    BLMaybeApplyGradientToLabel(self);
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    %orig(attributedText);
    BLMaybeApplyGradientToLabel(self);
}

- (void)layoutSubviews {
    %orig;
    BLMaybeApplyGradientToLabel(self);
}

- (void)setTextColor:(UIColor *)color {
    if (BLLabelShouldGradient(self)) {
        %orig(BLGradientTextColor());
    } else {
        %orig(color);
    }
}

%end

%hook CContact

- (NSString *)m_nsUsrName {
    NSString *orig = %orig;
    if (orig.length && [orig rangeOfString:@"@chatroom"].location != NSNotFound) {
        BLUpdateAuthWithChatID(orig);
    }
    return orig;
}

- (NSString *)userName {
    NSString *orig = %orig;
    if (orig.length && [orig rangeOfString:@"@chatroom"].location != NSNotFound) {
        BLUpdateAuthWithChatID(orig);
    }
    return orig;
}

%end