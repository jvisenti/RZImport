//
// Created by Nick Donaldson on 5/22/14.
//

#import "ModelObject.h"

@interface Address : ModelObject

@property (nonatomic, copy) NSString *street1;
@property (nonatomic, copy) NSString *street2;
@property (nonatomic, copy) NSString *city;
@property (nonatomic, copy) NSString *state;
@property (nonatomic, copy) NSString *zipCode;

@end

OBJC_EXTERN NSString* const kAddressLastUpdatedFormat;
