//
//  MCSessionDelegateWrapper.h
//  RxMultipeer
//
//  Created by Nathan Kot on 1/02/17.
//  Copyright © 2017 Nathan Kot. All rights reserved.
//

#ifndef MCSessionDelegateWrapper_h
#define MCSessionDelegateWrapper_h

#import <MultipeerConnectivity/MultipeerConnectivity.h>

#import "MCSessionSwiftDelegate.h"

@interface MCSessionDelegateWrapper : NSObject <MCSessionDelegate>

@property (readonly, nonnull) id<MCSessionSwiftDelegate> delegate;

- (id _Nonnull) initWithDelegate: (id<MCSessionSwiftDelegate> _Nonnull) delegate;

@end

#endif /* MCSessionDelegateWrapper_h */
