//
//  SavedTableViewCell.h
//  Speech
//
//  Created by Ankit Gupta on 7/21/16.
//  Copyright © 2016 Google. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SavedTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *authorLabel;
@property (weak, nonatomic) IBOutlet UILabel *transcriptLabel;

@end
