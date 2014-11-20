//
//  ViewController.m
//  Help
//
//  Created by Brigitte Michau on 2014/11/20.
//  Copyright (c) 2014 BrigitteMichau. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AVFoundation/AVCaptureSession.h>
#import "AppDelegate.h"

@interface ViewController () <AVCaptureAudioDataOutputSampleBufferDelegate>

@property CIDetector *faceDetector;

@property (weak, nonatomic) IBOutlet UIView *previewView;
@property (weak, nonatomic) IBOutlet UITextView *log;

@property AppDelegate *appDelegate;

@end

@implementation ViewController

static const BOOL USE_FRONT_CAMERA = YES;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if(!self.appDelegate) {
        self.appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    }
    
    NSDictionary *detectorOptions = @{CIDetectorAccuracy: CIDetectorAccuracyHigh};
    self.faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:detectorOptions];
    
    [self captureSessionSettings];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)log:(NSString *)msg {
    self.log.text = [@"\r\n" stringByAppendingString:self.log.text];
    self.log.text = [msg stringByAppendingString:self.log.text];
}

- (void)captureSessionSettings {
    NSError *deviceError;
    
    AVCaptureDevice *cameraDevice;
    
    if(USE_FRONT_CAMERA) {
        cameraDevice = [self frontCamera];
    } else {
        cameraDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    
    AVCaptureDeviceInput *inputDevice = [AVCaptureDeviceInput deviceInputWithDevice:cameraDevice error:&deviceError];
    
    AVCaptureVideoDataOutput *outputDevice = [[AVCaptureVideoDataOutput alloc] init];
    
    [outputDevice setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    AVCaptureSession *captureSession = [[AVCaptureSession alloc] init];
    [captureSession addInput:inputDevice];
    [captureSession addOutput:outputDevice];
    
    AVCaptureVideoPreviewLayer *previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:captureSession];
    
    previewLayer.frame = self.previewView.bounds;
    [self.previewView.layer addSublayer:previewLayer];
    
    [captureSession startRunning];
    
}

- (AVCaptureDevice *)frontCamera {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if ([device position] == AVCaptureDevicePositionFront) {
            return device;
        }
    }
    return nil;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
    CIImage *ciImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer
                                                      options:(__bridge NSDictionary *)attachments];
    
    if (attachments) {
        CFRelease(attachments);
    }
    
    UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
    NSDictionary *detectorOptions = @{
                                      CIDetectorImageOrientation:[self exifOrientation:curDeviceOrientation],
                                      CIDetectorSmile: @(YES),
                                      CIDetectorEyeBlink: @(YES),};
    
    NSArray *features = [self.faceDetector featuresInImage:ciImage
                                                   options:detectorOptions];
    
    for(CIFaceFeature* faceFeature in features) {
        
        if(faceFeature.hasSmile) {
            [self log:@"Smile 😄"];
        }
        
        //        if(faceFeature.hasLeftEyePosition) {
        //            if(faceFeature.hasLeftEyePosition) {
        //                NSLog(@"leftEye: %f, %f",faceFeature.leftEyePosition.x,faceFeature.leftEyePosition.y);
        //            }
        //        }
        //
        //        if(faceFeature.hasRightEyePosition) {
        //            NSLog(@"rightEye: %f, %f",faceFeature.rightEyePosition.x,faceFeature.rightEyePosition.y);
        //        }
        
        
        if(faceFeature.leftEyeClosed) {
            [self log:@"Left Eye"];
        }
        
        if(faceFeature.rightEyeClosed) {
            [self log:@"Right Eye"];
        }
        
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantPast]];
        
    }
}

- (NSNumber *)exifOrientation: (UIDeviceOrientation) orientation {
    int exifOrientation;
    
    enum {
        PHOTOS_EXIF_0ROW_TOP_0COL_LEFT                        = 1, //   1  =  0th row is at the top, and 0th column is on the left (THE DEFAULT).
        PHOTOS_EXIF_0ROW_TOP_0COL_RIGHT                        = 2, //   2  =  0th row is at the top, and 0th column is on the right.
        PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT      = 3, //   3  =  0th row is at the bottom, and 0th column is on the right.
        PHOTOS_EXIF_0ROW_BOTTOM_0COL_LEFT       = 4, //   4  =  0th row is at the bottom, and 0th column is on the left.
        PHOTOS_EXIF_0ROW_LEFT_0COL_TOP          = 5, //   5  =  0th row is on the left, and 0th column is the top.
        PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP         = 6, //   6  =  0th row is on the right, and 0th column is the top.
        PHOTOS_EXIF_0ROW_RIGHT_0COL_BOTTOM      = 7, //   7  =  0th row is on the right, and 0th column is the bottom.
        PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM       = 8  //   8  =  0th row is on the left, and 0th column is the bottom.
    };
    
    switch (orientation) {
        case UIDeviceOrientationPortraitUpsideDown:  // Device oriented vertically, home button on the top
            exifOrientation = PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM;
            break;
        case UIDeviceOrientationLandscapeLeft:       // Device oriented horizontally, home button on the right
            if (USE_FRONT_CAMERA)
                exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
            else
                exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
            break;
        case UIDeviceOrientationLandscapeRight:      // Device oriented horizontally, home button on the left
            if (USE_FRONT_CAMERA)
                exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
            else
                exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
            break;
        case UIDeviceOrientationPortrait:            // Device oriented vertically, home button on the bottom
        default:
            exifOrientation = PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP;
            break;
    }
    return [NSNumber numberWithInt:exifOrientation];
}

@end
