//
//  NSObject+RZImport.m
//  RZImport
//
//  Created by Nick Donaldson on 5/21/14.
//
//  Copyright 2014 Raizlabs and other contributors
//  http://raizlabs.com/
//
//  Permission is hereby granted, free of charge, to any person obtaining
//  a copy of this software and associated documentation files (the
//  "Software"), to deal in the Software without restriction, including
//  without limitation the rights to use, copy, modify, merge, publish,
//  distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to
//  the following conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
//  LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
//  OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
//  WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "NSObject+RZImport.h"
#import "NSObject+RZImport_Private.h"
#import <objc/runtime.h>


static NSString* const kRZImportISO8601DateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";

//
//  Private Utility Macros/Functions
//

#if ( DEBUG )
#define RZILogDebug(msg, ...) NSLog((@"[RZImport : DEBUG] " msg), ##__VA_ARGS__)
#else
#define RZILogDebug(...)
#endif

#define RZILogError(msg, ...) NSLog((@"[RZImport : ERROR] " msg), ##__VA_ARGS__);

#define RZINSNullToNil(x) ([x isEqual:[NSNull null]] ? nil : x)

static objc_property_t rzi_getProperty(NSString *name, Class class) {
    
    objc_property_t property = class_getProperty( class, [name UTF8String] );
    
    if ( property == NULL) {
        // check base classes
        Class baseClass = class_getSuperclass( class );
        while ( baseClass != Nil && property == NULL) {
            property  = class_getProperty( baseClass, [name UTF8String] );
            baseClass = class_getSuperclass( baseClass );
        }
    }
    
    return property;
}

static RZImportDataType rzi_dataTypeForProperty(NSString *propertyName, Class aClass) {
    
    objc_property_t property = rzi_getProperty(propertyName, aClass);
    if ( property == nil ) {
        return RZImportDataTypeUnknown;
    }
    
    char *typeEncoding = nil;
    typeEncoding = property_copyAttributeValue(property, "T");
    
    if ( typeEncoding == NULL ) {
        return RZImportDataTypeUnknown;
    }
    
    RZImportDataType type = RZImportDataTypeUnknown;
    
    switch ( typeEncoding[0] ) {
            
            // Object class
        case _C_ID: {
            
            NSUInteger typeLength = (NSUInteger)strlen(typeEncoding);
            
            if ( typeLength > 3 ) {
                NSString *typeString = [[NSString stringWithUTF8String:typeEncoding] substringWithRange:NSMakeRange(2, typeLength - 3)];
                type = rzi_dataTypeFromString(typeString);
            }
        }
            break;
            
            // Primitive type
        case _C_CHR:
        case _C_UCHR:
        case _C_INT:
        case _C_UINT:
        case _C_SHT:
        case _C_USHT:
        case _C_LNG:
        case _C_ULNG:
        case _C_LNG_LNG:
        case _C_ULNG_LNG:
        case _C_FLT:
        case _C_DBL:
        case _C_BOOL:
            type = RZImportDataTypePrimitive;
            break;
            
        default:
            break;
    }
    
    if ( typeEncoding ) {
        free(typeEncoding), typeEncoding = NULL;
    }
    
    return type;
}

static NSArray* rzi_propertyNamesForClass(Class aClass) {
    
    unsigned int    count;
    objc_property_t *properties = class_copyPropertyList( aClass, &count );
    
    NSMutableArray *names = [NSMutableArray array];
    
    for ( unsigned int i = 0; i < count; i++ ) {
        objc_property_t property      = properties[i];
        NSString        *propertyName = [NSString stringWithUTF8String:property_getName( property )];
        if ( propertyName ) {
            [names addObject:propertyName];
        }
    }
    
    if ( properties ) {
        free( properties ), properties = NULL;
    }
    
    return names;
}

static SEL rzi_setterForProperty(Class aClass, NSString *propertyName) {
    
    NSString        *setterString = nil;
    objc_property_t property      = rzi_getProperty(propertyName, aClass);
    if ( property ) {
        char *setterCString = property_copyAttributeValue( property, "S" );
        
        if ( setterCString ) {
            setterString = [NSString stringWithUTF8String:setterCString];
            free( setterCString );
        }
        else {
            setterString = [NSString stringWithFormat:@"set%@:", [propertyName stringByReplacingCharactersInRange:NSMakeRange( 0, 1 ) withString:[[propertyName substringToIndex:1] capitalizedString]]];
        }
    }
    
    return setterString ? NSSelectorFromString( setterString ) : nil;
}

//
//  Private Header Implementations

NSString *rzi_normalizedKey(NSString *key) {
    if ( key == nil ) {
        return nil;
    }
    return [[key lowercaseString] stringByReplacingOccurrencesOfString:@"_" withString:@""];
}

RZImportDataType rzi_dataTypeFromString(NSString *string)
{
    Class objClass = NSClassFromString(string);
    if ( objClass == Nil ){
        return RZImportDataTypeUnknown;
    }
    
    RZImportDataType type = RZImportDataTypeOtherObject;
    
    if ( [objClass isSubclassOfClass:[NSString class]] ){
        type = RZImportDataTypeNSString;
    }
    else if ( [objClass isSubclassOfClass:[NSNumber class]] ){
        type = RZImportDataTypeNSNumber;
    }
    else if ( [objClass isSubclassOfClass:[NSDate class]] ){
        type = RZImportDataTypeNSDate;
    }
    else if ( [objClass isSubclassOfClass:[NSArray class]] ){
        type = RZImportDataTypeNSArray;
    }
    else if ( [objClass isSubclassOfClass:[NSDictionary class]] ){
        type = RZImportDataTypeNSDictionary;
    }
    else if ( [objClass isSubclassOfClass:[NSSet class]] ) {
        type = RZImportDataTypeNSSet;
    }
    
    return type;
}


@implementation RZIPropertyInfo

// Implementation is empty on purpose - just a simple POD class.

@end

//
//  Category Implementation
//

@implementation NSObject (RZImport)

#pragma mark - Static

+ (NSSet *)s_rzi_ignoredClasses
{
    static NSSet *s_ignoredClasses = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_ignoredClasses = [NSSet setWithArray:@[
                                                 @"NSObject",
                                                 @"NSManagedObject"
                                                 ]];
    });
    return s_ignoredClasses;
}

+ (NSNumberFormatter *)s_rzi_numberFormatter
{
    static NSNumberFormatter *s_numberFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_numberFormatter = [[NSNumberFormatter alloc] init];
        s_numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
        
        // !!!: The locale is mandated to be US, so JSON API responses will parse correctly regardless of locality.
        //      If other localization is required, custom import blocks must be used.
        s_numberFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    });
    return s_numberFormatter;
}

+ (NSDateFormatter *)s_rzi_dateFormatter
{
    static NSDateFormatter *s_dateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_dateFormatter = [[NSDateFormatter alloc] init];
        s_dateFormatter.dateFormat = kRZImportISO8601DateFormat;
        
        // !!!: The time zone is mandated to be GMT for parsing string dates.
        //      Any timezone offsets should be encoded into the date string or handled on the display level.
        s_dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        
        // !!!: The locale is mandated to be US, so JSON API responses will parse correctly regardless of locality.
        //      If other localization is required, custom import blocks must be used.
        s_dateFormatter.locale   = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    });
    return s_dateFormatter;
}

#pragma mark - Public

+ (instancetype)rzi_objectFromDictionary:(NSDictionary *)dict
{
    return [self rzi_objectFromDictionary:dict withMappings:nil];
}

+ (instancetype)rzi_objectFromDictionary:(NSDictionary *)dict withMappings:(NSDictionary *)mappings
{
    NSParameterAssert(dict);
    
    id object = nil;
    
    if ( [self respondsToSelector:@selector( rzi_existingObjectForDict: )] ) {
        Class <RZImportable> thisClass = [self class];
        object = [thisClass rzi_existingObjectForDict:dict];
    }
    
    if ( object == nil ) {
        object = [[self alloc] init];
    }
    
    [object rzi_importValuesFromDict:dict withMappings:mappings];
    
    return object;
}

+ (NSArray *)rzi_objectsFromArray:(NSArray *)array
{
    return [self rzi_objectsFromArray:array withMappings:nil];
}

+ (NSArray *)rzi_objectsFromArray:(NSArray *)array withMappings:(NSDictionary *)mappings
{
    NSParameterAssert(array);
    
    NSMutableArray *objects = [NSMutableArray array];
    [array enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSAssert([obj isKindOfClass:[NSDictionary class]], @"Array passed to rzi_objectsFromArray: must only contain NSDictionary instances");
        if ( [obj isKindOfClass:[NSDictionary class]] ) {
            id importedObj = [self rzi_objectFromDictionary:obj withMappings:mappings];
            if ( importedObj ) {
                [objects addObject:importedObj];
            }
        }
    }];
    
    return [NSArray arrayWithArray:objects];
}

- (void)rzi_importValuesFromDict:(NSDictionary *)dict
{
    [self rzi_importValuesFromDict:dict withMappings:nil];
}

- (void)rzi_importValuesFromDict:(NSDictionary *)dict withMappings:(NSDictionary *)mappings
{
    BOOL canOverrideImports = [self respondsToSelector:@selector( rzi_shouldImportValue:forKey: )];
    
    [dict enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        
        if ( canOverrideImports ) {
            if ( ![(id<RZImportable>)self rzi_shouldImportValue:value forKey:key] ) {
                return;
            }
        }
        
        RZIPropertyInfo *propDescriptor = [[self class] rzi_propertyInfoForExternalKey:key withMappings:mappings];

        if ( propDescriptor != nil ) {
            value = RZINSNullToNil(value);
            [self rzi_setValue:value fromKey:key forPropertyDescriptor:propDescriptor];
        }
        else {
            RZILogDebug(@"No property found in class %@ for key %@. Create a custom mapping to import a value for this key.", NSStringFromClass([self class]), key);
        }
    }];
}

#pragma mark - Private Header


// For runtime locating of property info
+ (RZIPropertyInfo *)rzi_propertyInfoForExternalKey:(NSString *)key withMappings:(NSDictionary *)extraMappings
{
    __block RZIPropertyInfo *propInfo = nil;
    [self rzi_performBlockAtomically:^{
        
        // First check overridden mappings
        NSString *propName = [extraMappings objectForKey:key];
        if ( propName ) {
            propInfo = [self rzi_cachedPropertyInfoForPropertyName:propName];
        }
        else {
            NSDictionary *importMappings = [self rzi_importMappings];
            
            // check cache for raw key
            propInfo = [importMappings objectForKey:key];
            
            // check cache for normalized key
            if ( propInfo == nil ) {
                propInfo = [importMappings objectForKey:rzi_normalizedKey(key)];
            }
        }
    }];
    
    return propInfo;
}

#pragma mark - Private

+ (void)rzi_performBlockAtomically:(void(^)())block
{
    static dispatch_queue_t s_serialQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_serialQueue = dispatch_queue_create("com.rzimport.syncQueue", DISPATCH_QUEUE_SERIAL);
    });
    
    if ( block ) {
        dispatch_sync(s_serialQueue, block);
    }
}

// !!!: this method is not threadsafe
+ (NSDictionary *)rzi_importMappings
{
    static void * kRZIImportMappingAssocKey = &kRZIImportMappingAssocKey;
    __block NSDictionary *mapping = objc_getAssociatedObject(self, kRZIImportMappingAssocKey);
    
    if ( mapping == nil ) {
        
        NSMutableDictionary *mutableMapping = [NSMutableDictionary dictionary];
        
        // Get mappings from the normalized property names
        [mutableMapping addEntriesFromDictionary:[self rzi_normalizedPropertyMappings]];
        
        // Get any mappings from the RZImportable protocol
        if ( [[self class] respondsToSelector:@selector( rzi_customMappings )] ) {
            
            Class <RZImportable> thisClass = [self class];
            NSDictionary *customMappings = [thisClass rzi_customMappings];
            
            [customMappings enumerateKeysAndObjectsUsingBlock:^( NSString *key, NSString *propName, BOOL *stop ) {
                RZIPropertyInfo *propInfo = [self rzi_cachedPropertyInfoForPropertyName:propName];
                if ( propInfo ) {
                    [mutableMapping setObject:propInfo forKey:key];
                }
            }];
        }
        
        mapping = [NSDictionary dictionaryWithDictionary:mutableMapping];
        objc_setAssociatedObject(self, kRZIImportMappingAssocKey, mapping, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    return mapping;
}

// !!!: this method is not threadsafe
+ (NSDictionary *)rzi_normalizedPropertyMappings
{
    NSMutableDictionary *mappings = [NSMutableDictionary dictionary];
    
    Class currentClass = [self class];
    while ( currentClass != Nil ) {
        
        NSString *className = NSStringFromClass(currentClass);
        
        if ( ![[[self class] s_rzi_ignoredClasses] containsObject:className] ) {
            NSArray *classPropNames = rzi_propertyNamesForClass(currentClass);
            [classPropNames enumerateObjectsUsingBlock:^(NSString *classPropName, NSUInteger idx, BOOL *stop) {
                RZIPropertyInfo *propInfo = [self rzi_cachedPropertyInfoForPropertyName:classPropName];
                if ( propInfo != nil ) {
                    [mappings setObject:propInfo forKey:rzi_normalizedKey(classPropName)];
                }
            }];
        }
        
        currentClass = class_getSuperclass( currentClass );
    }
    
    return [NSDictionary dictionaryWithDictionary:mappings];
}

// For cache management
// !!!: this method is not threadsafe
+ (RZIPropertyInfo *)rzi_cachedPropertyInfoForPropertyName:(NSString *)propName
{
    static void * kRZIClassPropInfoAssocKey = &kRZIClassPropInfoAssocKey;
    NSMutableDictionary *classPropInfo = objc_getAssociatedObject(self, kRZIClassPropInfoAssocKey);
    if ( classPropInfo == nil ) {
        classPropInfo = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, kRZIClassPropInfoAssocKey, classPropInfo, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    RZIPropertyInfo *propInfo = [classPropInfo objectForKey:propName];
    if ( propInfo == nil ) {
        propInfo = [[RZIPropertyInfo alloc] init];
        propInfo.propertyName = propName;
        propInfo.dataType = rzi_dataTypeForProperty(propName, self);
        [classPropInfo setObject:propInfo forKey:propName];
    }
    
    return propInfo;
}

- (void)rzi_setNilForPropertyNamed:(NSString *)propName
{
    SEL setter = rzi_setterForProperty([self class], propName);
    if ( setter == nil ) {
        RZILogError(@"Setter not available for property named %@", propName);
        return;
    }
    
    NSMethodSignature *methodSig  = [self methodSignatureForSelector:setter];
    NSInvocation      *invocation = [NSInvocation invocationWithMethodSignature:methodSig];
    
    [invocation setTarget:self];
    [invocation setSelector:setter];
    
    // The buffer is copied so this is OK even though it will go out of scope
    id nilValue = nil;
    [invocation setArgument:&nilValue atIndex:2];
    [invocation invoke];
}

- (void)rzi_setValue:(id)value fromKey:(NSString *)originalKey forPropertyDescriptor:(RZIPropertyInfo *)propDescriptor
{
    @try {
        if ( value == nil ) {
            [self rzi_setNilForPropertyNamed:propDescriptor.propertyName];
        }
        else {
            
            id convertedValue = nil;
            
            if ( [value isKindOfClass:[NSNumber class]] ) {
                
                switch (propDescriptor.dataType) {
                        
                    case RZImportDataTypeNSNumber:
                    case RZImportDataTypePrimitive:
                        convertedValue = value;
                        break;
                        
                    case RZImportDataTypeNSString:
                        convertedValue = [value stringValue];
                        break;
                        
                    case RZImportDataTypeNSDate: {
                        // Assume it's a unix timestamp
                        convertedValue = [NSDate dateWithTimeIntervalSince1970:[value doubleValue]];
                        
                        RZILogDebug(@"Received a number for key [%@] matching property [%@] of class [%@]. Assuming unix timestamp.",
                                     originalKey,
                                     propDescriptor.propertyName,
                                     NSStringFromClass([self class]));
                    }
                        break;
                        
                    default:
                        break;
                }
                
            }
            else if ( [value isKindOfClass:[NSString class]] ) {
                
                switch (propDescriptor.dataType) {
                        
                    case RZImportDataTypePrimitive:
                    case RZImportDataTypeNSNumber: {
                        __block NSNumber *number = nil;
                        [[self class] rzi_performBlockAtomically:^{
                            number = [[[self class] s_rzi_numberFormatter] numberFromString:value];
                        }];
                        convertedValue = number;
                    }
                        break;
                        
                    case RZImportDataTypeNSString:
                        convertedValue = value;
                        break;
                        
                    case RZImportDataTypeNSDate: {
                        // Check for a date format from the object. If not provided, use ISO-8601.
                        __block NSDate *date = nil;
                        [[self class] rzi_performBlockAtomically:^{
                            
                            NSString        *dateFormat     = nil;
                            NSDateFormatter *dateFormatter  = [[self class] s_rzi_dateFormatter];
                            
                            if ( [[self class] respondsToSelector:@selector(rzi_dateFormatForKey:)] ) {
                                Class <RZImportable> thisClass = [self class];
                                dateFormat = [thisClass rzi_dateFormatForKey:originalKey];
                            }
                            
                            if ( dateFormat == nil ) {
                                dateFormat = kRZImportISO8601DateFormat;
                            }
                            
                            dateFormatter.dateFormat = dateFormat;
                            date = [dateFormatter dateFromString:value];
                        }];
                        convertedValue = date;
                        
                    }
                        break;
                        
                    default:
                        break;
                }
                
            }
            else if ( [value isKindOfClass:[NSDate class]] ) {
                
                // This will not occur in raw JSON deserialization,
                // but the conversion may have already happened in an external method.
                if ( propDescriptor.dataType == RZImportDataTypeNSDate ) {
                    convertedValue = value;
                }
            }
            
            if ( convertedValue ) {
                [self setValue:convertedValue forKey:propDescriptor.propertyName];
            }
            else {
                RZILogError(@"Could not convert value of type %@ for key \"%@\" to correct type for property \"%@\" of class %@",
                             NSStringFromClass([value class]),
                             originalKey,
                             propDescriptor.propertyName,
                             NSStringFromClass([self class]));
            }
        }
    }
    @catch ( NSException *exception ) {
        RZILogError(@"Could not set value %@ for property %@ of class %@", value, propDescriptor.propertyName, NSStringFromClass([self class]));
    }
}

@end
