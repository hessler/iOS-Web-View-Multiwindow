//----------------------------------------------------------------------
//
//  HDViewController.m
//  WebViewMultiWindowExample
//
//  Copyright (c) 2013 Hessler Design. All rights reserved.
//
//----------------------------------------------------------------------

#import "HDViewController.h"
#import "HDString.h"

//
// This is our JS we're going to inject into each web view. It looks a bit messy,
// but in short, it overrides the window.open and window.close methods. It does
// this by creating an iframe and setting the iframe src attribute to a custom
// URL scheme: "hdwebview://".
//
// This custom URL scheme is followed by a method name we will catch in the
// webView:shouldStartLoadWithRequest:navigationType method. Our method names are:
//    - jswindowopenoverride
//    - jswindowcloseoverride
//
// There is also logic in this JS block that loops through all anchor tags on
// a given page, and finds any that have a target of "_blank", replacing the
// blank target with an onclick event that fires a window.open method, passing
// in the href attribute as the URL to open. And since we have overridden the
// window.open method, this action will be caught as a new window open event.
//
// At this time, I haven't yet figured out how to get window-to-window communication
// via JavaScript -- for example, having a child window call a method to its parent.
// If anyone can figure out how to do that, please let me know!
//
static NSString * const kJSOverrides = @"(function () { 'use strict'; /*global document, window, setInterval, clearInterval */ window.open = function (url, name, specs, replace) { var iframe = document.createElement('IFRAME'); iframe.setAttribute('src', 'hdwebview://jswindowopenoverride||' + url); iframe.setAttribute('frameborder', '0'); iframe.style.width = '1px'; iframe.style.height = '1px'; document.body.appendChild(iframe); document.body.removeChild(iframe); iframe = null; }; window.close = function () { var iframe = document.createElement('IFRAME'); iframe.setAttribute('src', 'hdwebview://jswindowcloseoverride'); iframe.setAttribute('frameborder', '0'); iframe.style.width = '1px'; iframe.style.height = '1px'; document.body.appendChild(iframe); document.body.removeChild(iframe); iframe = null; }; window.hdMakeHandler = function (anchor) { return function () { window.open(anchor.getAttribute('href')); }; }; window.hdWebViewReadyInterval = setInterval(function () { if (document.readyState === 'complete') { var i, ab = document.getElementsByTagName('a'), abLength = ab.length; for (i = 0; i < abLength; i += 1) { if (ab[i].getAttribute('target') === '_blank') { ab[i].removeAttribute('target'); ab[i].onclick = window.hdMakeHandler(ab[i]); } } clearInterval(window.hdWebViewReadyInterval); } }, 10); }());";

@interface HDViewController ()

@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *backBtn;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *forwardBtn;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *refreshBtn;
@property (nonatomic) NSMutableArray *windows;
@property (nonatomic) UIWebView *activeWindow;

@end


@implementation HDViewController

@synthesize windows = _windows;

//----------------------------------------------------------------------
//
//  View Methods
//
//----------------------------------------------------------------------

#pragma mark - View Methods
- (void)viewDidLoad
{
    [super viewDidLoad];
	
    // Create Web View
    UIWebView *webView = [self newWebView];
    
    // Attach event handlers
    self.backBtn.action = @selector(navigateBack:);
    self.forwardBtn.action = @selector(navigateForward:);
    self.refreshBtn.action = @selector(refreshWebView:);
    
    // Load URL into web view
    NSURL *url = [NSURL URLWithString:@"http://www.hesslerdesign.com/tests/js_window_methods/"];
    NSURLRequest *requestObj = [NSURLRequest requestWithURL:url];
    [webView loadRequest:requestObj];
    
    [self.view addSubview:webView];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


//----------------------------------------------------------------------
//
//  Accessor Methods
//
//----------------------------------------------------------------------

#pragma mark - Initialization
- (NSMutableArray *) windows
{
    if (!_windows) {
        _windows = [[NSMutableArray alloc] init];
    }
    return _windows;
}


//----------------------------------------------------------------------
//
//  Web View Creation
//
//----------------------------------------------------------------------

#pragma mark - Web View Creation

- (UIWebView *) newWebView
{
    // Create a web view that fills the entire window, minus the toolbar height
    UIWebView *webView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, (float)self.view.bounds.size.width, (float)self.view.bounds.size.height - 44)];
    webView.scalesPageToFit = YES;
    webView.delegate = self;
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    // Add to windows array and make active window
    [self.windows addObject:webView];
    self.activeWindow = webView;
    
    return webView;
}


//----------------------------------------------------------------------
//
//  Web View Delegate Methods
//
//----------------------------------------------------------------------

#pragma mark - Web View Delegate Methods

- (BOOL) webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    // Check URL for special prefix, which marks where we overrode JS. If caught, return NO.
    if ([[[request URL] absoluteString] hasPrefix:@"hdwebview"]) {
        
        // The injected JS window override separates the method (i.e. "jswindowopenoverride") and the
        // suffix (i.e. a URL to open in the overridden window.open method) with double pipes ("||")
        // Here we strip out the prefix and break apart the method so we know how to handle it.
        NSString *suffix = [[[request URL] absoluteString] stringByReplacingOccurrencesOfString:@"hdwebview://" withString:@""];
        NSArray *methodAsArray = [suffix componentsSeparatedByString:[HDString encodedString:@"||"]];
        NSString *method = [methodAsArray objectAtIndex:0];
        
        if ([method isEqualToString:@"jswindowopenoverride"]) {
            
            NSLog(@"window.open caught");
            UIWebView *webView = [self newWebView];
            NSURL *url = [NSURL URLWithString:[NSString stringWithString:[methodAsArray objectAtIndex:1]]];
            NSURLRequest *requestObj = [NSURLRequest requestWithURL:url];
            [webView loadRequest:requestObj];
            [self.view addSubview:webView];
            NSLog(@"Number of windows: %d", [_windows count]);
            [self refreshToolbar];
            
        } else if ([method isEqualToString:@"jswindowcloseoverride"] || [method isEqualToString:@"jswindowopenerfocusoverride"]) {
            
            // Only close the active web view if it's not the base web view. We don't want to close
            // the last web view, only ones added to the top of the original one.
            NSLog(@"window.close caught");
            if ([self.windows count] > 1) {
                [self closeActiveWebView];
            }
            
        }
        
        return NO;
        
    }
    
    // If the web view isn't the active window, we don't want it to do any more requests.
    // This fixes the issue with popup window overrides, where the underlying window was still
    // trying to redirect to the original anchor tag location in addition to the new window
    // going to the same location, which resulted in the "back" button needing to be pressed twice.
    if (![webView isEqual:self.activeWindow]) {
        return NO;
    }
    
    return YES;
}

- (void) webViewDidStartLoad:(UIWebView *)webView
{
    // Show the network activity indicator
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

- (void) webViewDidFinishLoad:(UIWebView *)webView
{
    // Refresh toolbar and hide network activity indicator
    [self refreshToolbar];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    
    // Inject JS to override window prototype methods
    __unused NSString *jsOverrides = [webView stringByEvaluatingJavaScriptFromString:kJSOverrides];
}
- (void) webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    // Add any fail errors needed here. For this demo, we'll let it silently fail.
}


//----------------------------------------------------------------------
//
//  Toolbar
//
//----------------------------------------------------------------------

#pragma mark - Toolbar
- (void) refreshToolbar
{
    if ([self.activeWindow isEqual:[self.windows objectAtIndex:0]]) {
        
        // Only enable if the web view can go back.
        self.backBtn.enabled = [self.activeWindow canGoBack];
        
    } else {
        
        // This web view isn't the original one, so we're enabling the back button
        // because it will either have a history, or close itself if it has no history,
        // showing the underlying web view.
        self.backBtn.enabled = YES;
        
    }
    self.forwardBtn.enabled = [self.activeWindow canGoForward];
}
- (void) refreshWebView:(id)sender
{
    [self.activeWindow reload];
}
- (void) navigateBack:(id)sender
{
    if (self.activeWindow.canGoBack) {
        
        // This web view can go back, so we're telling it to go back.
        [self.activeWindow goBack];
        
    } else {
        
        if (![self.activeWindow isEqual:[self.windows objectAtIndex:0]]) {
            // This web view can't go back, so we're closing the window and showing the underlying one.
            NSLog(@"active web view can't go back, so we're closing it");
            [self closeActiveWebView];
        }
        
    }
}
- (void) navigateForward:(id)sender
{
    [self.activeWindow goForward];
}
- (void) closeActiveWebView
{
    // Grab and remove the top web view, remove its reference from the windows array,
    // and nil itself and its delegate. Then we re-set the activeWindow to the
    // now-top web view and refresh the toolbar.
    UIWebView *webView = [self.windows lastObject];
    [webView removeFromSuperview];
    [self.windows removeLastObject];
    webView.delegate = nil;
    webView = nil;
    NSLog(@"Number of windows: %d", [_windows count]);
    self.activeWindow = [self.windows lastObject];
    [self refreshToolbar];
}

@end
