#import <Foundation/Foundation.h>
#import "sqlite3.h"
#import "FMResultSet.h"

#define FMDatabase_DEBUG

@interface FMDatabase : NSObject
{
    sqlite3 *db;
    NSString *databasePath;
    BOOL logsErrors;
    BOOL crashOnErrors;
    BOOL inUse;
    BOOL traceExecution;
    BOOL checkedOut;
    int busyRetryTimeout;
    BOOL shouldCacheStatements;
    NSMutableDictionary *cachedStatements;
}

#ifdef FMDatabase_DEBUG
+ (void)logOpenDatabases;
+ (int)countOfOpenDatabases;
#endif

+ (id)databaseWithPath: (NSString *)inPath;
- (id)initWithPath: (NSString *)inPath;

- (BOOL)open;
#if SQLITE_VERSION_NUMBER >= 3005000
- (BOOL)openWithFlags: (int)flags;
#endif
- (BOOL)close;
- (BOOL)goodConnection;
- (void)clearCachedStatements;

// encryption methods.  You need to have purchased the sqlite encryption extensions for these to work.
- (BOOL)setKey: (NSString *)key;
- (BOOL)rekey: (NSString *)key;


- (NSString *)databasePath;

- (NSString *)lastErrorMessage;

- (int)lastErrorCode;
- (BOOL)hadError;
- (sqlite_int64)lastInsertRowId;
- (int)changes;

- (sqlite3 *)sqliteHandle;

- (BOOL)executeUpdate: (NSString *)sql, ...;
- (BOOL)executeUpdate: (NSString *)sql withArgumentsInArray: (NSArray *)arguments;
- (BOOL)executeUpdate: (NSString *)sql
 withArgumentsInArray: (NSArray *)arrayArgs
             orVAList: (va_list)args; // you shouldn't ever need to call this.  use the previous two instead.

- (FMResultSet *)executeQuery: (NSString *)sql, ...;
- (FMResultSet *)executeQuery: (NSString *)sql withArgumentsInArray: (NSArray *)arguments;
- (FMResultSet *)executeQuery: (NSString *)sql
         withArgumentsInArray: (NSArray *)arrayArgs
                     orVAList: (va_list)args; // you shouldn't ever need to call this.  use the previous two instead.

- (BOOL)rollback;
- (BOOL)commit;
- (BOOL)beginTransaction;
- (BOOL)beginDeferredTransaction;

- (BOOL)savepoint: (NSString *)aName;
- (BOOL)releaseSavepoint: (NSString *)aName;
- (BOOL)rollbackToSavepoint: (NSString *)aName;

- (BOOL)logsErrors;
- (void)setLogsErrors: (BOOL)flag;

- (BOOL)crashOnErrors;
- (void)setCrashOnErrors: (BOOL)flag;

- (BOOL)inUse;
- (void)setInUse: (BOOL)value;

- (BOOL)inTransaction;

- (BOOL)traceExecution;
- (void)setTraceExecution: (BOOL)flag;

- (BOOL)checkedOut;
- (void)setCheckedOut: (BOOL)flag;

- (int)busyRetryTimeout;
- (void)setBusyRetryTimeout: (int)newBusyRetryTimeout;

- (BOOL)shouldCacheStatements;
- (void)setShouldCacheStatements: (BOOL)value;

- (NSMutableDictionary *)cachedStatements;
- (void)setCachedStatements: (NSMutableDictionary *)value;


+ (NSString *)sqliteLibVersion;

@end

@interface FMStatement : NSObject
{
    sqlite3_stmt *statement;
    NSString *query;
    long useCount;
}

- (void)close;
- (void)reset;

- (sqlite3_stmt *)statement;
- (void)setStatement: (sqlite3_stmt *)value;

- (NSString *)query;
- (void)setQuery: (NSString *)value;

- (long)useCount;
- (void)setUseCount: (long)value;


@end

