//
//  GRWebView.m
//
//  The MIT License (MIT)
//
//  Copyright (c) 2013 Gabriel Rinaldi
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

// Progress handling by Satoshi Aasano (https://github.com/ninjinkun/NJKWebViewProgress)

#define GRWEBVIEW_MARGIN 50
#define GRWEBVIEW_SHADOW_OPACITY 0.4
#define GRWEBVIEW_PAGE_OFFSET 100
#define GRWEBVIEW_EFFORT 0.5

#import "GRWebView.h"

typedef enum {
    GRWebViewSwipeDirectionLeft = 0,
    GRWebViewSwipeDirectionRight = 1,
    GRWebViewSwipeDirectionNone
} GRWebViewSwipeDirection;

NSString *completeRPCURL = @"webviewprogressproxy:///complete";

static const float initialProgressValue = 0;
static const float beforeInteractiveMaxProgressValue = 0.5;
static const float afterInteractiveMaxProgressValue = 0.9;

#pragma mark GRWebView (Private)

@interface GRWebView () <UIGestureRecognizerDelegate, UIWebViewDelegate>

@property (strong, nonatomic) NSURL *currentURL;
@property (strong, nonatomic) UIWebView *hitWebView;
@property (strong, nonatomic) UIImage *screenshotImage;
@property (strong, nonatomic) UIImageView *backgroundImageView;
@property (assign, nonatomic) CGPoint origin;
@property (assign, nonatomic) CGPoint start;
@property (assign, nonatomic) GRWebViewSwipeDirection direction;
@property (assign, nonatomic) NSUInteger loadingCount;
@property (assign, nonatomic) NSUInteger maxLoadCount;
@property (assign, nonatomic, getter = isInteractive) BOOL interactive;

@end

#pragma mark - GRWebView

@implementation GRWebView

#pragma mark - Getters/Setters

@synthesize currentURL;
@synthesize hitWebView;
@synthesize screenshotImage;
@synthesize backgroundImageView;
@synthesize origin;
@synthesize start;
@synthesize direction;
@synthesize loadingCount;
@synthesize maxLoadCount;
@synthesize interactive;

#pragma mark - Initialization

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];

    origin = CGPointZero;

    direction = GRWebViewSwipeDirectionNone;

    hitWebView = [[UIWebView alloc] initWithFrame:self.bounds];
    [hitWebView setDelegate:self];
    [hitWebView setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
    [[hitWebView layer] setShadowOpacity:0.0];
    [[hitWebView layer] setShadowOffset:CGSizeMake(-1, 0)];
    [[hitWebView layer] setShadowRadius:5];
    [[hitWebView layer] setShadowPath:[[UIBezierPath bezierPathWithRect:hitWebView.bounds] CGPath]];
    [self addSubview:hitWebView];

    UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(swipeDetected:)];
    [panGestureRecognizer setMinimumNumberOfTouches:1];
    [panGestureRecognizer setMaximumNumberOfTouches:1];
    [panGestureRecognizer setDelegate:self];
    [self addGestureRecognizer:panGestureRecognizer];

    [[[hitWebView scrollView] panGestureRecognizer] requireGestureRecognizerToFail:panGestureRecognizer];

    backgroundImageView = [[UIImageView alloc] initWithFrame:self.bounds];
    [backgroundImageView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [[backgroundImageView layer] setShadowOpacity:0.0];
    [[backgroundImageView layer] setShadowOffset:CGSizeMake(-1, 0)];
    [[backgroundImageView layer] setShadowRadius:5];
    [[backgroundImageView layer] setShadowPath:[[UIBezierPath bezierPathWithRect:hitWebView.bounds] CGPath]];
    [self insertSubview:backgroundImageView belowSubview:hitWebView];

    [self resetProgress];

    return self;
}

#pragma mark - Progress handling

- (void)startProgress {
    if ([self progress] < initialProgressValue) {
        [self setProgress:initialProgressValue];
    }
}

- (void)incrementProgress {
    float progress = [self progress];
    float maxProgress = [self isInteractive] ? afterInteractiveMaxProgressValue : beforeInteractiveMaxProgressValue;
    float remainPercent = (float)loadingCount / (float)maxLoadCount;
    float increment = (maxProgress - progress) * remainPercent;

    progress += increment;
    progress = fmin(progress, maxProgress);

    [self setProgress:progress];
}

- (void)completeProgress {
    double delayInSeconds = 0.35;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        if (!CGPointEqualToPoint(origin, CGPointZero)) {
            [hitWebView setCenter:origin];
            [self insertSubview:hitWebView aboveSubview:backgroundImageView];
        }
    });

    [self setProgress:1.0];
}

- (void)setProgress:(float)progress {
    if (progress > [self progress] || progress == 0) {
        _progress = progress;
        if ([[self progressDelegate] respondsToSelector:@selector(webViewProgress:updateProgress:)]) {
            [[self progressDelegate] webViewProgress:self updateProgress:progress];
        }

        if (_progressBlock) {
            _progressBlock(progress);
        }
    }
}

- (void)resetProgress {
    maxLoadCount = loadingCount = 0;
    interactive = NO;

    [self setProgress:0.0];
}

#pragma mark - Method forwarding

- (void)forwardInvocation:(NSInvocation *)invocation {
	if (![self hitWebView]) {
		[self doesNotRecognizeSelector:[invocation selector]];
	}

	[invocation invokeWithTarget:[self hitWebView]];
}

- (NSMethodSignature*)methodSignatureForSelector:(SEL)selector {
	NSMethodSignature *signature = [super methodSignatureForSelector:selector];
	if (!signature) {
		signature = [[self hitWebView] methodSignatureForSelector:selector];
	}

	return signature;
}

#pragma mark - Web view delegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    if (navigationType != UIWebViewNavigationTypeOther) {
        UIGraphicsBeginImageContextWithOptions(self.frame.size, YES, [[UIScreen mainScreen] scale]);
        [[hitWebView layer] renderInContext:UIGraphicsGetCurrentContext()];

        screenshotImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }

    BOOL shouldLoad = YES;

    if ([[self delegate] respondsToSelector:@selector(webView:shouldStartLoadWithRequest:navigationType:)]) {
        shouldLoad = [[self delegate] webView:webView shouldStartLoadWithRequest:request navigationType:navigationType];
    }

    if ([[[request URL] absoluteString] isEqualToString:completeRPCURL]) {
        [self completeProgress];

        return NO;
    }

    BOOL isFragmentJump = NO;
    if ([[request URL] fragment]) {
        NSString *nonFragmentURL = [[[request URL] absoluteString] stringByReplacingOccurrencesOfString:[@"#" stringByAppendingString:[[request URL] fragment]] withString:@""];
        isFragmentJump = [nonFragmentURL isEqualToString:[[[webView request] URL] absoluteString]];
    }

    BOOL isTopLevelNavigation = [[request mainDocumentURL] isEqual:[request URL]];

    BOOL isHTTP = [[[request URL] scheme] isEqualToString:@"http"] || [[[request URL] scheme] isEqualToString:@"https"];
    if (shouldLoad && !isFragmentJump && isHTTP && isTopLevelNavigation) {
        currentURL = [request URL];
        [self resetProgress];
    }

    return shouldLoad;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    if ([[self delegate] respondsToSelector:@selector(webViewDidStartLoad:)]) {
        [[self delegate] webViewDidStartLoad:webView];
    }

    loadingCount++;
    maxLoadCount = fmax(maxLoadCount, loadingCount);

    [self startProgress];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    if ([[self delegate] respondsToSelector:@selector(webViewDidFinishLoad:)]) {
        [[self delegate] webViewDidFinishLoad:webView];
    }

    loadingCount--;
    [self incrementProgress];

    NSString *readyState = [webView stringByEvaluatingJavaScriptFromString:@"document.readyState"];

    BOOL isInteractive = [readyState isEqualToString:@"interactive"];
    if (isInteractive) {
        interactive = YES;
        NSString *waitForCompleteJS = [NSString stringWithFormat:@"window.addEventListener('load',function() { var iframe = document.createElement('iframe'); iframe.style.display = 'none'; iframe.src = '%@'; document.body.appendChild(iframe);  }, false);", completeRPCURL];
        [webView stringByEvaluatingJavaScriptFromString:waitForCompleteJS];
    }

    BOOL isNotRedirect = currentURL && [currentURL isEqual:[[webView request] mainDocumentURL]];
    BOOL complete = [readyState isEqualToString:@"complete"];
    if (complete && isNotRedirect) {
        [self completeProgress];
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    if ([[self delegate] respondsToSelector:@selector(webView:didFailLoadWithError:)]) {
        [[self delegate] webView:webView didFailLoadWithError:error];
    }

    loadingCount--;
    [self incrementProgress];

    NSString *readyState = [webView stringByEvaluatingJavaScriptFromString:@"document.readyState"];

    BOOL isInteractive = [readyState isEqualToString:@"interactive"];
    if (isInteractive) {
        interactive = YES;
        NSString *waitForCompleteJS = [NSString stringWithFormat:@"window.addEventListener('load',function() { var iframe = document.createElement('iframe'); iframe.style.display = 'none'; iframe.src = '%@'; document.body.appendChild(iframe);  }, false);", completeRPCURL];
        [webView stringByEvaluatingJavaScriptFromString:waitForCompleteJS];
    }

    BOOL isNotRedirect = currentURL && [currentURL isEqual:[[webView request] mainDocumentURL]];
    BOOL complete = [readyState isEqualToString:@"complete"];
    if (complete && isNotRedirect) {
        [self completeProgress];
    }
}

#pragma mark - Gesture recognizer

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    CGPoint point = [gestureRecognizer locationInView:hitWebView];
    if (point.x >= GRWEBVIEW_MARGIN && point.x <= (hitWebView.frame.size.width - GRWEBVIEW_MARGIN)) {
        return NO;
    }

    if (point.x < GRWEBVIEW_MARGIN && ![hitWebView canGoBack]) {
        return NO;
    } else if (point.x > (hitWebView.frame.size.width - GRWEBVIEW_MARGIN) && ![hitWebView canGoForward]) {
        return NO;
    }

    [[self backgroundImageView] setImage:screenshotImage];

    origin = hitWebView.center;
    start = point;

    if (point.x < GRWEBVIEW_MARGIN) {
        direction = GRWebViewSwipeDirectionRight;
        [backgroundImageView setCenter:origin];
        [self insertSubview:hitWebView aboveSubview:backgroundImageView];
    } else {
        direction = GRWebViewSwipeDirectionLeft;
        [backgroundImageView setCenter:CGPointMake(origin.x + hitWebView.frame.size.width, origin.y)];
        [self insertSubview:backgroundImageView aboveSubview:hitWebView];
    }

    return YES;
}

- (void)swipeDetected:(UIPanGestureRecognizer *)gestureRecognizer {
    CGPoint point = [gestureRecognizer locationInView:hitWebView];
    CGPoint backgroundPoint = [gestureRecognizer locationInView:backgroundImageView];
    CGPoint neutralPoint = [gestureRecognizer locationInView:self];

    float ratio = 0;
    if (direction == GRWebViewSwipeDirectionRight) {
        ratio = 1 - fabsf((point.x - neutralPoint.x) / self.frame.size.width);
    } else {
        ratio = fabsf((backgroundPoint.x - neutralPoint.x) / self.frame.size.width);
    }

    if ([gestureRecognizer state] == UIGestureRecognizerStateEnded || [gestureRecognizer state] == UIGestureRecognizerStateCancelled || [gestureRecognizer state] == UIGestureRecognizerStateFailed) {
        [gestureRecognizer setEnabled:NO];

        __block BOOL shouldCommit = NO;
        [UIView animateWithDuration:0.15 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            if (hitWebView.center.x >= (hitWebView.frame.size.width - ((hitWebView.frame.size.width / 2) * GRWEBVIEW_EFFORT)) && direction == GRWebViewSwipeDirectionRight) {
                shouldCommit = YES;
                [hitWebView setCenter:CGPointMake(hitWebView.frame.size.width + origin.x, origin.y)];
                [backgroundImageView setCenter:origin];
            } else if (backgroundImageView.center.x <= (hitWebView.frame.size.width + ((hitWebView.frame.size.width / 2) * GRWEBVIEW_EFFORT)) && direction == GRWebViewSwipeDirectionLeft) {
                shouldCommit = YES;
                [backgroundImageView setCenter:origin];
                [hitWebView setCenter:CGPointMake(origin.x - GRWEBVIEW_PAGE_OFFSET, origin.y)];
            } else {
                if (direction == GRWebViewSwipeDirectionRight) {
                    [backgroundImageView setCenter:CGPointMake(origin.x - GRWEBVIEW_PAGE_OFFSET, origin.y)];
                    [hitWebView setCenter:origin];
                } else {
                    [hitWebView setCenter:origin];
                    [backgroundImageView setCenter:CGPointMake(origin.x + hitWebView.frame.size.width, origin.y)];
                }
            }
        } completion:^(BOOL finished) {
            if (shouldCommit) {
                if (direction == GRWebViewSwipeDirectionRight) {
                    [[self hitWebView] goBack];
                } else {
                    [[self hitWebView] goForward];
                }
            }

            direction = GRWebViewSwipeDirectionNone;

            [gestureRecognizer setEnabled:YES];
        }];

        return;
    }

    if (direction != GRWebViewSwipeDirectionNone) {
        if (direction == GRWebViewSwipeDirectionRight) {
            float x = MAX(origin.x, hitWebView.center.x + (point.x - start.x));
            [hitWebView setCenter:CGPointMake(x, hitWebView.center.y)];
            [[hitWebView layer] setShadowOpacity:GRWEBVIEW_SHADOW_OPACITY * ratio];
            [backgroundImageView setCenter:CGPointMake(origin.x - (GRWEBVIEW_PAGE_OFFSET * ratio), origin.y)];
        } else {
            float x = backgroundImageView.frame.size.width + backgroundImageView.center.x + (backgroundPoint.x - start.x);
            [backgroundImageView setCenter:CGPointMake(x, backgroundImageView.center.y)];
            [[backgroundImageView layer] setShadowOpacity:GRWEBVIEW_SHADOW_OPACITY * ratio];
            [hitWebView setCenter:CGPointMake(origin.x - (GRWEBVIEW_PAGE_OFFSET * (1 - ratio)), origin.y)];
        }
    }
}

@end
