// ReactNativeStripeTerminalV2.h

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <StripeTerminal/StripeTerminal.h>

@interface ReactNativeStripeTerminalV2 : RCTEventEmitter <RCTBridgeModule, SCPConnectionTokenProvider, SCPBluetoothReaderDelegate, SCPDiscoveryDelegate, SCPTerminalDelegate> {
    SCPConnectionTokenCompletionBlock pendingConnectionTokenCompletionBlock;
    SCPPaymentIntent *intent;
    
    SCPCancelable *discoverCancelable;
    SCPCancelable *collectCancelable;
    SCPCancelable *reusableCancelable;
    SCPCancelable *refundCancelable;
    SCPCancelable *updateCancelable;


    NSArray<SCPReader *> *readers;


    bool hasListeners;
}

@end
