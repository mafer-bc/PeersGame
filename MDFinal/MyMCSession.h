//
//  MyMCSession.h
//  MDFinal
//
//  Created by Maria Fernanda Bojorquez Cavazos on 2015-04-20.
//Users/pg02maria/Desktop/MDFinal/MDFinal/ConnectionController.h/  Copyright (c) 2015 Maria Fernanda Bojorquez Cavazos. All rights reserved.
//

#import <MultipeerConnectivity/MultipeerConnectivity.h>

@interface MyMCSession : MCSession <MCSessionDelegate>


- (instancetype)initWithPeer:(MCPeerID *)myPeerID;

- (NSOutputStream *)startStreamWithName:(NSString *)streamName
                                 toPeer:(MCPeerID *)peerID
                                  error:(NSError **)error;

@property NSInputStream* theInputStream;

@end