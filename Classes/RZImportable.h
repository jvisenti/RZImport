//
//  RZImportable.h
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

#import <Foundation/Foundation.h>

/**
 *  Optional protocol for model objects to import in order to customize
 *  the behavior of RZImport.
 */
@protocol RZImportable <NSObject>

@optional

/**
 *  Implement to provide dictionary of custom mappings from dictionary keys to properties.
 *
 *  @return A dictionary containing mappings from dictionary keys to property names.
 */
+ (NSDictionary *)rzi_customMappings;

/**
 *  Implement to provide a custom date format string for a particular key or keys.
 *  Will only be called if the inferred property is an NSDate type and the dict value is a string.
 *
 *  @param key Unmodified key from the dictionary being imported.
 *
 *  @return A date format to use for importing this key, otherwise nil to use the default (ISO-8601).
 */
+ (NSString *)rzi_dateFormatForKey:(NSString *)key;

/**
 *  Implement to return an existing object for the provided dictionary representation. 
 *  Use this method to enforce object uniqueness.
 *
 *  @param dict Dictionary representation of object being imported.
 *
 *  @return An existing object instance represented by the dict, or nil if one does not exist.
 */
+ (id)rzi_existingObjectForDict:(NSDictionary *)dict;

/**
 *  Implement to optionally prevent import for particular key/value pairs.
 *  Can be used to validate imported value or override automatic import to perform custom logic.
 *  In order to support custom import logic for certain attributes, his is called by @p RZImport
 *  prior to mapping the dictionary key to a property name, so the key here may not match a property 
 *  name in this class.
 *
 *  @param value Unmodified value from dictionary being imported
 *  @param key   Unmodified key from dictionary being imported
 *
 *  @return YES if RZImport should proceed with automatic import for the key/value pair
 *          NO if the key/value pair should not be imported or will be handled within this method.
 */
- (BOOL)rzi_shouldImportValue:(id)value forKey:(NSString *)key;

@end
