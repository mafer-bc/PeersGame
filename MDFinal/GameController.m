//
//  ViewController.m
//  MDFinal
//
//  Created by Maria Fernanda Bojorquez Cavazos on 2015-04-19.
//  Copyright (c) 2015 Maria Fernanda Bojorquez Cavazos. All rights reserved.
//

#import "GameController.h"
#import "MyMCSession.h"

@interface GameController () <NSStreamDelegate, MCBrowserViewControllerDelegate>

//View references
@property (strong, nonatomic) IBOutlet UIImageView *ball;
@property (strong, nonatomic) IBOutlet UIImageView *exit;
@property (strong, nonatomic) IBOutletCollection(UIImageView) NSArray *wall;

@property (strong, nonatomic) IBOutlet UIImageView *otherBall;


//Ball properties for position and movement
@property (assign, nonatomic) CGPoint currentPoint;
@property (assign, nonatomic) CGPoint previousPoint;
@property (assign, nonatomic) CGFloat xVel;
@property (assign, nonatomic) CGFloat yVel;
@property (assign, nonatomic) CGFloat angle;

//The other ball position
@property CGPoint otherPosition;

//Accelerometer properties
@property (assign, nonatomic) CMAcceleration acceleration;
@property (strong, nonatomic) CMMotionManager *motionManager;
@property (strong, nonatomic) NSOperationQueue *queue;

//Often used variables
@property CGSize screenSize;
@property CGSize ballSize;
@property CGRect ballFrame;

//To control the updates from the accelerometer
@property (strong, nonatomic) NSDate *lastUpdateTime;

//Multipeer variables
@property (nonatomic, strong) MyMCSession* theSession;
@property (nonatomic, strong) MCAdvertiserAssistant* advertiser;
@property (nonatomic, strong) MCBrowserViewController* browser;
@property NSOutputStream *output;

@end

@implementation GameController

NSString* deviceName;
#define kUpdateInterval (1.0f / 60.0f);

//Constants for names and notifications 
static NSString* const kInputStream = @"inputStream";
static NSString* const kServiceType = @"VFSServiceType";
static NSString* const kConnected = @"connected";
static NSString* const kGameOver = @"gameOver";



- (void)viewDidLoad {
    [super viewDidLoad];
    
    //For debugging purposes
    deviceName = [[UIDevice currentDevice] name];
    

    self.lastUpdateTime = [[NSDate alloc] init];
    
    //Get variables that are used often
    self.screenSize = self.view.bounds.size;
    self.ballSize = self.ball.image.size;
    self.ballFrame = self.ball.frame;
    
    self.currentPoint = CGPointMake(0, 100);
    
    //Create a Session
    self.theSession = [[MyMCSession alloc] initWithPeer:self.myPeerID];
    
    //Setup an advertiser
    self.advertiser = [[MCAdvertiserAssistant alloc]
                       initWithServiceType:kServiceType discoveryInfo:nil session:self.theSession];
    
    [self.advertiser start];
    
    //Setup the browser view controller
    self.browser = [[MCBrowserViewController alloc] initWithServiceType:kServiceType session:self.theSession];
    self.browser.delegate = self;
    
    //Present the browser rigth away to start the connection
    [self presentViewController:self.browser animated:YES completion:nil];

    
    //Observer for the notification that the Session will send when it changes to Connected
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(connected:)
                                                 name:kConnected
                                               object:nil];
    
    
    //Listen to the MCSession when the inputStream is available
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(setInputStream:)
                                                 name:kInputStream
                                               object:nil];
    
    //Listen to the MCSession when the other player wins
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(gameOver:)
                                                 name:kGameOver
                                               object:nil];
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



//Notifications handlers
-(void) connected:(NSNotification*) notification {
    //Close the browser
    [self.browser dismissViewControllerAnimated:YES completion:nil];
    
    //Start the accelerometer and the streaming
    [self initMotionManager];
    [self startStreaming];
}

-(void)setInputStream:(NSNotification *)notification{
    //Gets the stream from the session object
    NSInputStream* inputStream = self.theSession.theInputStream;
    
    //Set the delegate to this controller
    inputStream.delegate = self;
    
    //The stream gets open will call the delegate method stream:handleEvent: (implemented below)
    [inputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [inputStream open];
}

-(void)gameOver:(NSNotification *)notification{
    [self.motionManager stopAccelerometerUpdates];
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"You lose"
                                                        message:@"GAME OVER"
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil, nil];
        [alert show];
    });
}



-(void) startStreaming {
    NSError *error;
    
    //Start a stream with a unique identifier, so two devices don't create the same stream
    NSString *streamName = [NSString stringWithFormat:@"%@", [[UIDevice currentDevice] identifierForVendor]];
    
    self.output = [self.theSession startStreamWithName:streamName toPeer:self.theSession.connectedPeers.firstObject error:&error];

    if (error) {
        NSLog(@"%@: Error %@", deviceName, error.localizedDescription);
        return;
    }
    
    //Open the output to start sending the position of the ball to the second device
    [self.output scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [self.output open];
}



-(void) update {
    //Get the time elapsed since the last update
    NSTimeInterval secondsSinceLastDraw = -([self.lastUpdateTime timeIntervalSinceNow]);
    
    //New velocity vector for the movement of the ball (xVel takes acceleration.y due the screen orientation)
    self.xVel = self.xVel + (self.acceleration.y * secondsSinceLastDraw);
    self.yVel = self.yVel + (self.acceleration.x * secondsSinceLastDraw);
    
    //Position change to apply to the ball. Depends on the time that pass between frames,
    //the current velocity and a scale factor, so the ball moves faster
    CGFloat xDelta = secondsSinceLastDraw * self.xVel * 100;
    CGFloat yDelta = secondsSinceLastDraw * self.yVel * 100;
    
    CGFloat offSetScreenWidth = self.screenSize.width - self.ballSize.width;
    CGFloat offSetScreenHeight = self.screenSize.height - self.ballSize.height;
    
    //Add boundaries with the screen and reduce velocity of the ball when it collides,
    //so it feels like it bounces
    CGFloat newX = self.currentPoint.x + xDelta;
    if (newX > offSetScreenWidth || newX < 0){
        xDelta = 0;
        self.xVel = -(self.xVel / 2.0);
    }
    
    CGFloat newY = self.currentPoint.y + yDelta;
    if (newY > offSetScreenHeight || newY < 0){
        yDelta = 0;
        self.yVel = -(self.yVel / 2.0);
    }
    
    self.currentPoint = CGPointMake(self.currentPoint.x + xDelta, self.currentPoint.y + yDelta);
    
    [self moveBall];
    
    //If the ball collides with the "exit" element
    if (CGRectIntersectsRect(self.ball.frame, self.exit.frame)) [self winAlert];
    
    self.lastUpdateTime = [NSDate date];
}



-(void) moveBall {
    //Check if is colliding with a wall
    [self addWallCollisions];

    int lastX = lroundf(self.previousPoint.x);
    int lastY = lroundf(self.previousPoint.y);
    
    self.previousPoint = self.currentPoint;
    
    CGRect newFrame = self.ball.frame;
    newFrame.origin.x = self.currentPoint.x;
    newFrame.origin.y = self.currentPoint.y;
    
    //Assign the new position to the ball
    self.ball.frame = newFrame;
    
    //Send the current postion of the ball only on significant position changes (no decimals)
    if (lastX != lroundf(newFrame.origin.x) && lastY != lroundf(newFrame.origin.y)){
        
        NSString* stringPoint = (NSString*) NSStringFromCGPoint(self.currentPoint);
        NSData* data = [stringPoint dataUsingEncoding:NSUTF8StringEncoding];
        
        [self.output write:data.bytes maxLength:data.length];
    }
}



/*** NSStreamDelegate Methods ***/
#pragma mark NSStreamDelegate methods
-(void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode{
    switch (eventCode) {
        case NSStreamEventHasBytesAvailable:{
            
            NSInputStream *inputStream = (NSInputStream *) aStream;
            
            //Define a length for the buffer, due the CGPoint size (20-30 bytes),
            //the length set is a little bit greater than that
            uint8_t buffer[100];
            NSInteger size = [inputStream read:(uint8_t *)buffer maxLength:100];
            
            NSData *data = [NSData dataWithBytes:buffer length:size];
            
            NSString *stringPoint = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            
            //Create the point from the string sended by the other device
            self.otherPosition = (CGPoint)CGPointFromString(stringPoint);
            
            [self moveOtherBall];
            
            break;
        }
            
        default:
            break;
    }
}



-(void) moveOtherBall {
    CGRect newFrame = self.otherBall.frame;
    newFrame.origin.x = self.otherPosition.x;
    newFrame.origin.y = self.otherPosition.y;
    
    //Assign the new position to the second ball
    self.otherBall.frame = newFrame;
}



- (void) addWallCollisions {
    CGRect newFrame = self.ball.frame;
    newFrame.origin.x = self.currentPoint.x;
    newFrame.origin.y = self.currentPoint.y;
    
    for (UIImageView *wallImage in self.wall) {
        if (CGRectIntersectsRect(newFrame, wallImage.frame)){
            
            CGPoint ballCenter = CGPointMake(newFrame.origin.x + (newFrame.size.width/2),
                                             newFrame.origin.y + (newFrame.size.height/2));
            
            CGPoint wallImageCenter = CGPointMake(wallImage.frame.origin.x + (wallImage.frame.size.width/2),
                                                  wallImage.frame.origin.y + (wallImage.frame.size.height/2));
            
            //Get the distance (diagonal) from the center of the ball to the center of the wall
            CGFloat angleX = ballCenter.x - wallImageCenter.x;
            CGFloat angleY = ballCenter.y - wallImageCenter.y;
            
            //Get the absolute values of both axis and check which is the one that is colliding
            //As with the screen boundaries, it reduces the velocity and resets the position
            if (abs(angleX) > abs(angleY)){
                _currentPoint.x = self.previousPoint.x;
                self.xVel = -(self.xVel / 2.0);
            } else {
                _currentPoint.y = self.previousPoint.y;
                self.yVel = -(self.yVel / 2.0);
            }
        }
    }
}



-(void) winAlert {
    NSError *error;
    
    [self.theSession sendData:[kGameOver dataUsingEncoding:NSUTF8StringEncoding] toPeers:self.theSession.connectedPeers withMode:MCSessionSendDataUnreliable error:&error];
    
    if (error) {
        NSLog(@"%@: Error %@", deviceName, error.localizedDescription);
        return;
    }
    
    [self.motionManager stopAccelerometerUpdates];
        
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"You won"
                                                  message:@"GAME OVER"
                                                  delegate:self
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil, nil];
    [alert show];
    [self.output close];
}



-(void) initMotionManager {
    self.motionManager = [[CMMotionManager alloc] init];
    self.queue = [[NSOperationQueue alloc] init];
    
    self.motionManager.accelerometerUpdateInterval = kUpdateInterval;
    
    //Run the following block forever, until we tell the motionManager to stop updating
    [self.motionManager startAccelerometerUpdatesToQueue:self.queue
            withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
                [(id) self setAcceleration:accelerometerData.acceleration];
                [self performSelectorOnMainThread:@selector(update) withObject:nil waitUntilDone:NO];
    }];
}



/*** MCBrowserViewControllerDelegate Methods ***/
#pragma mark MCBrowserViewControllerDelegate methods

- (void)browserViewControllerDidFinish:(MCBrowserViewController *)browserViewController {
    //The user chose a peer to connect
    [self.browser dismissViewControllerAnimated:YES completion:nil];
}

- (void)browserViewControllerWasCancelled:(MCBrowserViewController *)browserViewController {
    //The user canceled the searching
    [self.browser dismissViewControllerAnimated:YES completion:nil];
}


@end
