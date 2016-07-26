//
//  SavedTableViewController.h
//  Speech
//
//  Created by Ankit Gupta on 7/21/16.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface SavedTableViewController : UITableViewController

@property (nonatomic, retain) NSFetchedResultsController *fetchedResultsController;

@end
