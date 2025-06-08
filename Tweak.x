#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface WAMutableChatSession : NSObject
@property NSString *lastMessageUniqueKey;
@property NSString *contactName;
@property NSString *subjectText;
@end

@interface WAWrappedFetchedResultsController : NSObject
@property NSArray <WAMutableChatSession *> *fetchedObjects;
@end

@interface WAChatListViewController : UIViewController
- (void)exportContacts;
@end

%hook WAChatListViewController
- (void)markChatSession:(id)session read:(BOOL)read {
    %orig;

    [self exportContacts];
}

%new
- (void)exportContacts {
    if (class_getInstanceVariable([self class], "_fetchedResultsControllerForAllChats") == NULL) {
        return;
    }

    WAWrappedFetchedResultsController *allChats = [self valueForKey:@"_fetchedResultsControllerForAllChats"];
    NSMutableArray<NSString *> *vcfCards = [NSMutableArray array];

    for (WAMutableChatSession *chat in allChats.fetchedObjects) {
        NSArray *components = [chat.lastMessageUniqueKey componentsSeparatedByString:@"@"];
        if (components.count == 2) {
            NSString *number = components.firstObject;
            NSString *title = chat.contactName.length ? chat.contactName : chat.subjectText;
            if (!number.length) number = title;
            if (!number.length) continue;

            number = [[number componentsSeparatedByCharactersInSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]] componentsJoinedByString:@""];

            NSString *contact = [NSString stringWithFormat:
                @"BEGIN:VCARD\nVERSION:3.0\nFN:%@\nTEL;TYPE=CELL:%@\nEND:VCARD\n", title, number
            ];

            [vcfCards addObject:contact];
        }
    }

    if (vcfCards.count == 0) {
        NSLog(@"DVN --- no contacts found");
        return;
    }

    NSString *vcfContent = [vcfCards componentsJoinedByString:@"\n"];
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"whatsapp_contacts.vcf"];
    NSError *error = nil;
    [vcfContent writeToFile:tempPath atomically:YES encoding:NSUTF8StringEncoding error:&error];

    if (error) {
        NSLog(@"DVN --- writeToFile error: %@", error);
        return;
    }

    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:tempPath]] applicationActivities:nil];

    if (activityVC.popoverPresentationController) {
        activityVC.popoverPresentationController.sourceView = self.view;
        activityVC.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/4, 0, 0);
    }

    [self presentViewController:activityVC animated:YES completion:nil];
}
%end