//
//  MyMCSession.m
//  MDFinal
//
//  Created by Maria Fernanda Bojorquez Cavazos on 2015-04-20.
//  Copyright (c) 2015 Maria Fernanda Bojorquez Cavazos. All rights reserved.
//

#import "MyMCSession.h"

#import <MultipeerConnectivity/MultipeerConnectivity.h>

@interface MyMCSession () <MCSessionDelegate>

@end

@implementation MyMCSession

//Constants for names and notifications
static NSString* const kInputStream = @"inputStream";
static NSString* const kConnected = @"connected";
static NSString* const kGameOver = @"gameOver";


//Constructor
- (instancetype)initWithPeer:(MCPeerID *)myPeerID{
    if ((self = [super initWithPeer:myPeerID])) {
        self.delegate = self;
    }
    
    return self;
}


- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    
    NSString* stateString;
    
    switch (state) {
        //Notify to the gameCtrl that the connection is done so it can start the game
        case MCSessionStateConnected:{
            [[NSNotificationCenter defaultCenter] postNotificationName:kConnected object:nil];
            return;
        }
        case MCSessionStateNotConnected:
            stateString = @"Not Connected";
            break;
        default:
            break;
    }
    
    if (stateString) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertView* connected = [[UIAlertView alloc] initWithTitle:peerID.displayName message:stateString delegate:nil cancelButtonTitle:@"DONE"otherButtonTitles:nil, nil];
            [connected show];
        });
    }
}



- (NSOutputStream *)startStreamWithName:(NSString *)streamName
                                 toPeer:(MCPeerID *)peerID
                                  error:(NSError **)error{
    //NSLog(@"%@: Start Stream %@",[[UIDevice currentDevice] name], streamName);
    return [super startStreamWithName:streamName toPeer:peerID error:error];
}



- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID {
    
    //NSLog(@"%@: Recieve stream: %@ from: %@", [[UIDevice currentDevice] name],streamName, peerID);
    
    self.theInputStream = stream;
    
    //Notify the game that it recieve and inputStream
    [[NSNotificationCenter defaultCenter] postNotificationName:kInputStream object:nil];
}



- (BOOL)sendData:(NSData *)data toPeers:(NSArray *)peerIDs withMode:(MCSessionSendDataMode)mode error:(NSError *__autoreleasing *)error{
    return [super sendData:data toPeers:peerIDs withMode:mode error:error];
}


- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    NSString *msg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if ([msg isEqualToString:kGameOver]){
        NSLog(@"%@: Data: %@ from: %@", [[UIDevice currentDevice] name],msg, peerID);
        //Notify the game that the player lose
        [[NSNotificationCenter defaultCenter] postNotificationName:kGameOver object:nil];\
    }
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress {}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error {}

@end