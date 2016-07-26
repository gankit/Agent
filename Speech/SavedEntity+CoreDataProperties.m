//
//  SavedEntity+CoreDataProperties.m
//  Speech
//
//  Created by Ankit Gupta on 7/22/16.
//  Copyright © 2016 Google. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "SavedEntity+CoreDataProperties.h"

@implementation SavedEntity (CoreDataProperties)

@dynamic transcript;
@dynamic title;
@dynamic url;
@dynamic author;
@dynamic alternatives;
@dynamic dateAdded;
@dynamic type;
@dynamic imageUrl;
@dynamic mediaType;
@dynamic placeMetadata;
@dynamic productMetadata;

@end
