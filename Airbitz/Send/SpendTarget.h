//
//  SpendTarget.h
//  AirBitz
//

#import "ABC.h"
#import "Wallet.h"

@interface SpendTarget : NSObject

@property (nonatomic)               tABC_SpendTarget        *pSpend;
@property (nonatomic, strong)       Wallet                  *srcWallet;
@property (nonatomic, strong)       Wallet                  *destWallet;

- (id)init;
- (BOOL)newSpend:(NSString *)text error:(tABC_Error *)pError;
- (BOOL)newTransfer:(NSString *)walletUUID error:(tABC_Error *)pError;
- (BOOL)spendNewInternal:(NSString *)address
                   label:(NSString *)label
                category:(NSString *)category
                   notes:(NSString *)notes
           amountSatoshi:(uint64_t)amountSatoshi
                   error:(tABC_Error *)pError;
- (NSString *)approve:(double)fiatAmount
                error:(tABC_Error *)pError;

- (BOOL)isMutable;
- (uint64_t)maxSpendable:(NSString *)walletUUID;
- (tABC_Error)calcSendFees:(NSString *)walletUUID
                 totalFees:(uint64_t *)totalFees;

@end
