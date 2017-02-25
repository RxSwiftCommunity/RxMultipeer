//
//  MCSessionDelegateWrapper.h
//  RxMultipeer
//
//  Created by Nathan Kot on 1/02/17.
//  Copyright © 2017 Nathan Kot. All rights reserved.
//

@import Foundation;
@import MultipeerConnectivity;

// MCSessionDelegate has a bug introduced when annotating the
// session:didFinishRecivingResourceWithName:fromPeer:atURL:withError method,
// atURL: is meant to be optional however it wasn't marked as so. Thus if
// a Swift class implementing this Delegate was ever called with an error for
// the above method, it would crash.
//
// This protocol is the 'fixed' version, and can be trampolined onto by using
// the MCSessionDelegateWrapper.
@protocol MCSessionDelegateWrapperDelegate <NSObject>

// Remote peer changed state.
- (void) session:(MCSession * _Nonnull)session peer:(MCPeerID * _Nonnull)peerID didChangeState:(MCSessionState)state;
// Received data from remote peer.
- (void) session:(MCSession * _Nonnull)session didReceiveData:(NSData * _Nonnull)data fromPeer:(MCPeerID * _Nonnull)peerID;
// Received a byte stream from remote peer.
- (void) session:(MCSession * _Nonnull)session didReceiveStream:(NSInputStream * _Nonnull)stream withName:(NSString * _Nonnull)streamName fromPeer:(MCPeerID * _Nonnull)peerID;
// Start receiving a resource from remote peer.
- (void) session:(MCSession * _Nonnull)session didStartReceivingResourceWithName:(NSString * _Nonnull)resourceName fromPeer:(MCPeerID * _Nonnull)peerID withProgress:(NSProgress * _Nonnull)progress;
// Finished receiving a resource from remote peer and saved the content
// in a temporary location - the app is responsible for moving the file
// to a permanent location within its sandbox.
- (void) session:(MCSession * _Nonnull)session didFinishReceivingResourceWithName:(NSString * _Nonnull)resourceName fromPeer:(MCPeerID * _Nonnull)peerID atURL:(nullable NSURL *)localURL withError:(nullable NSError *)error;
// Made first contact with peer and have identity information about the
// remote peer (certificate may be nil).
- (void) session:(MCSession * _Nonnull)session didReceiveCertificate:(nullable NSArray *)certificate fromPeer:(MCPeerID * _Nonnull)peerID certificateHandler:(nonnull void (^)(BOOL accept))certificateHandler;

@end

@interface MCSessionDelegateWrapper : NSObject <MCSessionDelegate>

@property (weak, nullable) id <MCSessionDelegateWrapperDelegate> delegate;
- (instancetype _Nonnull) initWithDelegate: (id<MCSessionDelegateWrapperDelegate> _Nonnull) delegate;

@end
