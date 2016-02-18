//
//  ConnectionController.m
//  MDFinal
//
//  Created by Maria Fernanda Bojorquez Cavazos on 2015-04-19.
//  Copyright (c) 2015 Maria Fernanda Bojorquez Cavazos. All rights reserved.
//

#import "ConnectionController.h"
#import <MultipeerConnectivity/MultipeerConnectivity.h>
#import "GameController.h"

@interface ConnectionController()

@property GameController *theGame;

@end

@implementation ConnectionController

NSString* deviceName;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //For debugging purposes
    deviceName = [[UIDevice currentDevice] name];

}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



-(void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    if ([segue.identifier isEqualToString:@"playSegue"]) {
        
        self.theGame = (GameController*) segue.destinationViewController;

        //Pass the peerID to the game
        self.theGame.myPeerID = [self getPeerID];
       
        //NSLog(@"%@: Move to game", deviceName);
    }
}


// create or get the peer id
- (MCPeerID*) getPeerID {
    
    MCPeerID* myPeerID;
    NSString* deviceName = [[UIDevice currentDevice] name];
    
    // because of a bug with iOS, the Peer ID should only be created once
    
    // check if a Peer needs to be created
    if ([[NSUserDefaults standardUserDefaults] dataForKey:@"PeerID"] == nil)
    {
        myPeerID = [[MCPeerID alloc] initWithDisplayName:deviceName];
        [[NSUserDefaults standardUserDefaults] setObject:[NSKeyedArchiver archivedDataWithRootObject:myPeerID] forKey:@"PeerID"];
    }
    //else it already exists, reuse it from before
    else
    {
        myPeerID = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] dataForKey:@"PeerID"]];
    }
    
    return myPeerID;
}

@end