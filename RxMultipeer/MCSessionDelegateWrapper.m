//
//  MCSessionDelegateWrapper.m
//  RxMultipeer
//
//  Created by Nathan Kot on 1/02/17.
//  Copyright © 2017 Nathan Kot. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MCSessionDelegateWrapper.h"

@implementation MCSessionDelegateWrapper

@synthesize delegate = _delegate;

- (id _Nonnull) initWithDelegate: (id<MCSessionSwiftDelegate> _Nonnull) delegate {
  _delegate = delegate;
  return self;
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID
{
  [_delegate session:session didReceiveData:data fromPeer:peerID];
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress
{
  [_delegate
   session:session
   didStartReceivingResourceWithName:resourceName
   fromPeer:peerID
   withProgress:progress];
}

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
  [_delegate session:session peer:peerID didChangeState:state];
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error
{
  [_delegate session:session didFinishReceivingResourceWithName:resourceName fromPeer:peerID atURL:localURL withError:error];
}

- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID
{
  [_delegate session:session didReceiveStream:stream withName:streamName fromPeer:peerID];
}

- (void)session:(MCSession *)session didReceiveCertificate:(NSArray *)certificate fromPeer:(MCPeerID *)peerID certificateHandler:(void (^)(BOOL accept))certificateHandler
{
  [_delegate
   session:session
   didReceiveCertificate:certificate
   fromPeer:peerID
   certificateHandler:certificateHandler];
}

@end
