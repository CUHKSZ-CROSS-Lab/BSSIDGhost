/*
 * ios/tests/objc-stub/Foundation/Foundation.h
 *
 * BSSIDGhost —— 用于在**非 macOS 主机**上给 hooks 下的 ObjC 源码做语法检查的最小 Foundation 桩。
 *
 * 这是什么东西：
 *   clang 的 -fsyntax-only 不需要真实实现，只需要「声明」。本文件把 hooks 里用到的
 *   Foundation 接口声明出来，于是 ios/tests/host/check-objc-syntax.sh 可以在 Linux 上
 *   对 ObjC 源码做真正的编译器检查（语法、类型、ARC 归属规则、隐式声明、格式化参数）。
 *
 * 这不是什么东西：
 *   - 不是 Foundation 实现，链接不了，也没有任何运行时语义；
 *   - 不校验方法在真实 iOS SDK 上是否存在 / 是否可用（可用性标注、弃用、私有 API 都查不到）；
 *   - 不启用格式串检查（NS_FORMAT_FUNCTION 被定义为空）。
 *   因此它只能把「编译期错误」提前暴露，不能替代真机/真 SDK 编译。
 *
 * 维护方式：hooks 用到新的 Foundation 接口时，在这里补声明即可。
 */

#ifndef BG_STUB_FOUNDATION_H
#define BG_STUB_FOUNDATION_H

#include <stdarg.h>
#include <stddef.h>

/* --- 基础类型（对齐 Apple 的定义）----------------------------------------- */

typedef signed char BOOL;
typedef unsigned long NSUInteger;
typedef long NSInteger;

#define YES ((BOOL)1)
#define NO ((BOOL)0)

#ifndef nil
#define nil ((id)0)
#endif
#ifndef Nil
#define Nil ((Class)0)
#endif

/// 与真实 Foundation 一致：让 clang 检查 `%@/%s/...` 与实参类型是否匹配。
/// 这条检查很关键 —— 我们自己日志函数的格式串错误就是靠它提前暴露的。
#define NS_FORMAT_FUNCTION(formatIdx, firstArgIdx) \
    __attribute__((format(__NSString__, formatIdx, firstArgIdx)))
#define NS_FORMAT_ARGUMENT(type) __attribute__((ns_consumed))

/* --- 协议 ---------------------------------------------------------------- */

@class NSString;

@protocol NSCopying
@end

@protocol NSObject
- (BOOL)isKindOfClass:(Class)aClass;
- (NSUInteger)hash;
- (BOOL)isEqual:(id)object;
@end

typedef struct {
    unsigned long state;
    id __unsafe_unretained *itemsPtr;
    unsigned long *mutationsPtr;
    unsigned long extra[5];
} NSFastEnumerationState;

@protocol NSFastEnumeration
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(id *)buffer
                                    count:(NSUInteger)len;
@end

/* --- 根类与基本对象 ------------------------------------------------------ */

@interface NSObject <NSObject>
+ (id)alloc;
+ (Class)class;
+ (instancetype)new;
- (instancetype)init;
- (Class)class;
- (instancetype)self;
- (id)copy;
- (NSString *)description;
@end

/* --- 字符串 -------------------------------------------------------------- */

@interface NSString : NSObject <NSCopying>
@property (readonly) NSUInteger length;
@property (readonly) const char *UTF8String;
@property (readonly) NSString *pathExtension;
+ (instancetype)string;
+ (instancetype)stringWithUTF8String:(const char *)nullTerminatedCString;
+ (instancetype)stringWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);
- (instancetype)initWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);
- (instancetype)initWithFormat:(NSString *)format arguments:(va_list)argList;
- (BOOL)hasPrefix:(NSString *)aString;
- (BOOL)hasSuffix:(NSString *)aString;
- (BOOL)isEqualToString:(NSString *)aString;
- (NSString *)stringByAppendingPathComponent:(NSString *)component;
- (NSString *)stringByAppendingString:(NSString *)aString;
- (NSString *)stringByDeletingLastPathComponent;
- (NSString *)stringByDeletingPathExtension;
- (NSString *)substringFromIndex:(NSUInteger)from;
@end

/* --- 数组 ---------------------------------------------------------------- */

@interface NSArray<__covariant ObjectType> : NSObject <NSFastEnumeration, NSCopying>
@property (readonly) NSUInteger count;
+ (instancetype)array;
+ (instancetype)arrayWithObjects:(const id [])objects count:(NSUInteger)count;
- (ObjectType)objectAtIndex:(NSUInteger)index;
- (ObjectType)objectAtIndexedSubscript:(NSUInteger)index;
@end

@interface NSMutableArray<ObjectType> : NSArray<ObjectType>
+ (instancetype)arrayWithCapacity:(NSUInteger)capacity;
- (void)addObject:(ObjectType)anObject;
@end

/* --- 字典 ---------------------------------------------------------------- */

@interface NSDictionary<__covariant KeyType, __covariant ObjectType>
    : NSObject <NSFastEnumeration, NSCopying>
@property (readonly) NSUInteger count;
+ (instancetype)dictionary;
+ (instancetype)dictionaryWithObjects:(const id [])objects
                              forKeys:(const id <NSCopying> [])keys
                                count:(NSUInteger)count;
- (ObjectType)objectForKey:(KeyType)aKey;
- (ObjectType)objectForKeyedSubscript:(KeyType)key;
- (NSArray<KeyType> *)allKeys;
@end

/* --- 数据与数字 ---------------------------------------------------------- */

@interface NSData : NSObject <NSCopying>
@property (readonly) NSUInteger length;
+ (instancetype)dataWithContentsOfFile:(NSString *)path;
@end

@interface NSNumber : NSObject <NSCopying>
@property (readonly) BOOL boolValue;
@property (readonly) int intValue;
@property (readonly) long longValue;
@property (readonly) unsigned long unsignedLongValue;
+ (NSNumber *)numberWithBool:(BOOL)value;
+ (NSNumber *)numberWithInt:(int)value;
+ (NSNumber *)numberWithLong:(long)value;
+ (NSNumber *)numberWithUnsignedLong:(unsigned long)value;
@end

/* --- 错误 ---------------------------------------------------------------- */

@interface NSError : NSObject <NSCopying>
@property (readonly, copy) NSString *localizedDescription;
@end

/* --- 文件与包 ------------------------------------------------------------ */

@interface NSFileManager : NSObject
+ (NSFileManager *)defaultManager;
- (BOOL)fileExistsAtPath:(NSString *)path;
- (BOOL)createDirectoryAtPath:(NSString *)path
  withIntermediateDirectories:(BOOL)createIntermediates
                   attributes:(NSDictionary *)attributes
                        error:(NSError **)error;
- (BOOL)removeItemAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)moveItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath error:(NSError **)error;
@end

@interface NSBundle : NSObject
+ (NSBundle *)mainBundle;
@property (readonly, copy) NSString *bundleIdentifier;
- (NSString *)pathForResource:(NSString *)name ofType:(NSString *)ext;
@end

/* --- JSON ---------------------------------------------------------------- */

typedef unsigned long NSJSONReadingOptions;
static const NSJSONReadingOptions NSJSONReadingMutableContainers = (1UL << 0);
static const NSJSONReadingOptions NSJSONReadingMutableLeaves = (1UL << 1);
static const NSJSONReadingOptions NSJSONReadingFragmentsAllowed = (1UL << 2);

@interface NSJSONSerialization : NSObject
+ (id)JSONObjectWithData:(NSData *)data
                 options:(NSJSONReadingOptions)opt
                   error:(NSError **)error;
@end

/* --- 日志 ---------------------------------------------------------------- */

void NSLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);

#endif /* BG_STUB_FOUNDATION_H */
