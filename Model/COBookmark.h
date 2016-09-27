/**
    Copyright (C) 2013 Quentin Mathe

    Date:  March 2013
    License:  MIT  (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <EtoileFoundation/EtoileFoundation.h>
#import <CoreObject/COObject.h>

/**
 * @group Built-in Object Types
 * @abstract COBookmark represents a URL-based link.
 *
 * COObject API includes the bookmark name, creation date and 
 * modification date. For example, see -[COObject name].
 */
@interface COBookmark : COObject
{
    @private
    NSURL *_URL;
    NSDate *_lastVisitedDate;
    NSData *_favIconData;
}


/** @taskunit Initialization */


/**
 * <init />
 * Intializes and returns a bookmark representing the URL.
 *
 * For a nil URL, raises an NSInvalidArgumentException.
 */
- (instancetype) initWithURL: (NSURL *)aURL NS_DESIGNATED_INITIALIZER;
/**
 * Intializes and returns a bookmark from the URL location file at the given 
 * path.
 *
 * Files using extensions such as .webloc or .url are URL location files.
 *
 * When no URL can be extracted from the URL location file, returns nil.
 *
 * For a nil URL, raises an NSInvalidArgumentException.
 */
- (instancetype) initWithURLFile: (NSString *)aFilePath;


/** @taskunit Bookmark Properties */


/**
 * The bookmark URL.
 *
 * This property is persistent and never nil.
 */
@property (nonatomic, readwrite, copy) NSURL *URL;
/**
 * The last time the URL was visited.
 *
 * For example, each time a web page is loaded, a browser can udpate this 
 * property.
 *
 * This property is persistent.
 */
@property (nonatomic, readwrite, copy) NSDate *lastVisitedDate;
/**
 * The image data for the fav icon bound to the URL.
 *
 * You would usually retrieve it from the URL. It is the small icon 
 * displayed in a web browser address bar.
 *
 * This property is persistent.
 */
@property (nonatomic, readwrite, strong) NSData *favIconData;

@end


/**
 * @group Utilities
 * @abstract CoreObject additions for NSURL.
 */
@interface NSURL (COBookmark)
/**
 * Returns the image data of the fav icon that symbolizes the given URL. 
 */
@property (nonatomic, readonly) NSData *favIconData;
@end
