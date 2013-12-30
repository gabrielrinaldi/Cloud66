//
//  GRWebView.h
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

typedef void (^GRWebViewProgressBlock)(float progress);

@protocol GRWebViewProgressDelegate;

#pragma mark GRWebView

@interface GRWebView : UIView

@property (copy, nonatomic) GRWebViewProgressBlock progressBlock;
@property (assign, nonatomic, readonly) float progress;
@property (weak, nonatomic) IBOutlet id <GRWebViewProgressDelegate> progressDelegate;
@property (weak, nonatomic) IBOutlet id <UIWebViewDelegate> delegate;

- (void)resetProgress;

@end

@protocol GRWebViewProgressDelegate <NSObject>

- (void)webViewProgress:(GRWebView *)webView updateProgress:(float)progress;

@end
