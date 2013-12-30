//
//  SVWebViewController.h
//
//  Created by Sam Vermette on 08.11.10.
//  Copyright 2010 Sam Vermette. All rights reserved.
//
//  https://github.com/samvermette/SVWebViewController
//

@class GRWebView;

#pragma mark SVWebViewController

@interface SVWebViewController : UIViewController <UIWebViewDelegate>

@property (strong, nonatomic) NSURL *URL;
@property (weak, nonatomic) IBOutlet UIProgressView *browserProgressView;
@property (weak, nonatomic) IBOutlet GRWebView *browserWebView;
@property (weak, nonatomic) IBOutlet UIToolbar *navigationToolbar;

- (id)initWithURL:(NSURL *)URL;

@end
