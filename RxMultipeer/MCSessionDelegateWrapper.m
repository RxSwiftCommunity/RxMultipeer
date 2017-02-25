//
//  MCSessionDelegateWrapper.m
//  RxMultipeer
//
//  Created by Nathan Kot on 1/02/17.
//  Copyright © 2017 Nathan Kot. All rights reserved.
//

@import Foundation;

#import "MCSessionDelegateWrapper.h"

@implementation MCSessionDelegateWrapper

// @synthesize delegate = _delegate;

- (id _Nonnull) initWithDelegate: (id<MCSessionDelegateWrapperDelegate> _Nonnull) delegate {
  self = [super init];

  if (self) {
    _delegate = delegate;
  }

  return self;
}

#pragma mark - MCSessionDelegate

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
  if ([self.delegate respondsToSelector:@selector(session:didReceiveData:fromPeer:)]) {
    [self.delegate session:session didReceiveData:data fromPeer:peerID];
  }
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress {
  if ([self.delegate respondsToSelector:@selector(session:didStartReceivingResourceWithName:fromPeer:withProgress:)]) {
    [self.delegate session:session didStartReceivingResourceWithName:resourceName fromPeer:peerID withProgress:progress];
  }
}

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
  if ([self.delegate respondsToSelector:@selector(session:peer:didChangeState:)]) {
    [self.delegate session:session peer:peerID didChangeState:state];
  }
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error {
  if ([self.delegate respondsToSelector:@selector(session:didFinishReceivingResourceWithName:fromPeer:atURL:withError:)]) {
    [self.delegate session:session didFinishReceivingResourceWithName:resourceName fromPeer:peerID atURL:localURL withError:error];
  }
}

- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID {
  if ([self.delegate respondsToSelector:@selector(session:didReceiveStream:withName:fromPeer:)]) {
    [self.delegate session:session didReceiveStream:stream withName:streamName fromPeer:peerID];
  }
}

- (void)session:(MCSession *)session didReceiveCertificate:(NSArray *)certificate fromPeer:(MCPeerID *)peerID certificateHandler:(void (^)(BOOL accept))certificateHandler {
  if ([self.delegate respondsToSelector:@selector(session:didReceiveCertificate:fromPeer:certificateHandler:)]) {
    [self.delegate session:session didReceiveCertificate:certificate fromPeer:peerID certificateHandler:certificateHandler];
  }
}

@end
