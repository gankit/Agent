//
//  SavedEntity+CoreDataProperties.h
//  Speech
//
//  Created by Ankit Gupta on 7/22/16.
//  Copyright © 2016 Google. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "SavedEntity.h"

NS_ASSUME_NONNULL_BEGIN

@interface SavedEntity (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *transcript;
@property (nullable, nonatomic, retain) NSString *title;
@property (nullable, nonatomic, retain) NSString *url;
@property (nullable, nonatomic, retain) NSString *author;
@property (nullable, nonatomic, retain) NSData *alternatives;
@property (nullable, nonatomic, retain) NSDate *dateAdded;
@property (nullable, nonatomic, retain) NSString *type;
@property (nullable, nonatomic, retain) NSString *imageUrl;
@property (nullable, nonatomic, retain) NSString *mediaType;
@property (nullable, nonatomic, retain) NSString *placeMetadata;
@property (nullable, nonatomic, retain) NSString *productMetadata;

@end

NS_ASSUME_NONNULL_END
