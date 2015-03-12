//
//  SpeedMonitorViewController.m
//  Spoiler_IOS
//
//  Evan Thompson, Tausif Ahmed
//  Copyright (c) 2014 Spoiler. All rights reserved.
//

#import "SpeedMonitorViewController.h"
#import "LogViewController.h"

@interface SpeedMonitorViewController ()  @end

@implementation SpeedMonitorViewController


//=========================================//
//======    File Writing Functions    =====//
//=========================================//

// Function to open up a file to write measurements to
-(void) writeToFile:(NSFileHandle*)fileSys data:(NSString*)data {
//    NSLog(@"Writing to file (%@) : %@", self.currFile, data);
        [self.fileSys seekToEndOfFile];
        [self.fileSys writeData:[data dataUsingEncoding:NSASCIIStringEncoding]];
}

// Function to write a new measurement to the open file
- (BOOL) addMeasurement:(double)val {
    self.fileSys = [NSFileHandle fileHandleForWritingAtPath:self.currFile];
    NSString* valStr = [NSString stringWithFormat:@"%.0f|", val];
    [self writeToFile:self.fileSys data:valStr];
    return TRUE;
}

// Function to close the file for writing
- (void) stopFile {
    [self.fileSys closeFile];
}

- (NSString *) formatFileName: (NSString*) name {
    // Copy of original input
    NSString *format = [NSString stringWithFormat:@"%@", name];
    
    // Format the string to show a proper log name
    format = [format stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    format = [format substringWithRange:NSMakeRange(0, 19)];
    NSString *date = [format substringWithRange:NSMakeRange(0, 10)];
    NSString *time = [format substringWithRange:NSMakeRange(11, 8)];
    time = [time stringByReplacingOccurrencesOfString:@"/" withString:@"."];
    format = [date stringByAppendingFormat:@" %@", time];
    
    return format;
}

// Function to prepare file for writing measurements into
-(void) runFileSetup:(double)rate {
    
    // Retrieve the current date
    NSDate* date = [NSDate date];
    
    // Initialize object to format date correctly
    NSDateFormatter* df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"MM_dd_yyyy_HH_mm_ss"];
    
    // Format strings to generate log file name
    NSString* dateStr = [NSString stringWithString:[df stringFromDate:date]];
    NSString* docsDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSString* name = [NSString stringWithFormat:@"%@.log",dateStr];
    NSString* correct_name = [self formatFileName:name];
    
    NSLog(@"Name of file : %@", correct_name);

    
    NSString* path = [docsDir stringByAppendingPathComponent:correct_name];
    
    // Make a reference to new file for writing
    self.currFile = path;
    self.fileSys = [NSFileHandle fileHandleForWritingAtPath:self.currFile];
    
    // Create meta data
    NSString* toWrite = [NSString stringWithFormat:@"%@|%f|", correct_name, rate];
    
//    NSLog(@"File path for writing: %@", self.currFile);
    
    // Create file manager for writing measurements
    NSFileManager* manager = [NSFileManager defaultManager];
    [manager createFileAtPath:self.currFile contents: [toWrite dataUsingEncoding:NSASCIIStringEncoding] attributes:nil];
    
    // Write to the file
    [self writeToFile:self.fileSys data:toWrite];
}



//=========================================//
//======         UI Functions         =====//
//=========================================//

// Function to update the speed displayed on the app page
- (void)lblUpdate:(double)velo {
    NSString * numStr = [NSString stringWithFormat:@"%.0f", velo];
    [self.lbl setText:numStr];
}

// Function to set up animations
-(void) setupAnim {
    
    // Setup the pulsing animation for the active label
    self.anim = [CABasicAnimation animationWithKeyPath:@"opacity"];
    [self.anim setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
    [self.anim setRepeatCount:HUGE_VALF];
    [self.anim setFromValue:[NSNumber numberWithFloat:.25]];
    [self.anim setToValue:[NSNumber numberWithFloat:1.0]];
    [self.anim setAutoreverses:YES];
    [self.anim setDuration:1.0];
}

// Function to change UI when user starts gathering speed
- (void) runUISetup {
    
    // Enable and disable the correct buttons
    [self.StopBtn setEnabled:YES];
    [self.RunBtn setEnabled:NO];
    
    // Set the descriptive label to running
    [self.activeLabel setText:@"Running..."];
    
    // Enable the animation
    [[[self activeLabel] layer] addAnimation:self.anim forKey:@"pulse"];
}

// Function to change the UI upon user
// indicating they are done recording their speed
- (void) stopUISetup {
    
    // Enable and disable the correct buttons
    [self.RunBtn setEnabled:YES];
    [self.StopBtn setEnabled:NO];
    
    // Set the descriptive label to inactive
    [self.activeLabel setText:@"Inactive..."];
    
    // Disable the animation
    [[[self activeLabel] layer] removeAnimationForKey:@"pulse"];
    [self.lbl setText:@"0"];
}

//=========================================//
//======      Location Functions      =====//
//=========================================//

// Function that is called at the rate of RATE
// to get location and data and parse needed data from it
- (void) tick {
    
    // Initialize the CLLocationManager
    self.cllManager = [[CLLocationManager alloc] init];
    // Start retrieving location data
    [self.cllManager startUpdatingLocation];

    // Store the retrieved location in loc
    self.loc = [self.cllManager location];
    
    // Retrieve speed from the stored location data
    double velo = self.loc.speed;
    
    // Update the label
    [self lblUpdate:velo];
    
    // Add the measurment and check to see if the measurement has been added,
    // if not print out an error text alerting user
    if(![self addMeasurement:velo]){
        [self lblUpdate:-1];
        [self.activeLabel setText:@"SPEED NOT ADDED"];
    }
}

// Function to stop retreiving location
- (void) stopLocation {
    
    // Stop updating the location.  Will save battery.
    [self.cllManager stopUpdatingLocation];
    self.cllManager = nil;
}


//=========================================//
//======     Start/Stop Functions     =====//
//=========================================//

// Function that intializes all necessary parts for gathering speed
- (void) runInitializations {
    
    // Set up the Log
    self.lblLog = [[Log alloc] init];
    
    // Initialize the CLLocationManager
    self.cllManager = [[CLLocationManager alloc] init];
    
    // Check for iOS 8. Without this guard the code will crash with "unknown selector" on iOS 7.
    if ([self.cllManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
        [self.cllManager requestWhenInUseAuthorization];
    }
    
    // Set the accuracy of CLLocationManager
    [self.cllManager setPausesLocationUpdatesAutomatically:NO];
    [self.cllManager setDesiredAccuracy:kCLLocationAccuracyBestForNavigation];
    [self.cllManager setDistanceFilter:kCLDistanceFilterNone];
    
    // Begin updating
    [self.cllManager startUpdatingLocation];
}

// Function that is called when the run button is pressed
- (IBAction)onRun:(id)sender {
    
    // Intitalize the parts needed for log
    [self runInitializations];
    
    // Change the UI for the run state
    [self runUISetup];
    
    // Get the file ready for initiliazation
    [self runFileSetup:self.RATE];
    
    // Start the timer for updating the label
    self.lblTimer = [NSTimer scheduledTimerWithTimeInterval: self.RATE target:self selector: @selector(tick) userInfo:nil repeats:YES];
}

// Function that executed when the user presse the Stop button
- (IBAction)onStop:(id)sender {
    
    // Set the UI to the stop state
    [self stopUISetup];
    
    // Set the location to a stopped state
    [self stopLocation];
    
    // Close up the file
    [self stopFile];
    
    // End the label timer
    [self.lblTimer invalidate];
}



//=========================================//
//======      Overriden Functions     =====//
//=========================================//


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self.StopBtn setEnabled:NO];
    [self.RunBtn setEnabled:YES];
    [self setupAnim];
    
    
    
    self.RATE = 1.0;
    self.SPEEDSYSTEM = 2.236;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
