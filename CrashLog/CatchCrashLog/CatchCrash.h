//
//  CatchCrash.h
//  GGTextView
//
//  Created by 丁华超 on 16/7/11.
//  Copyright © 2016年 __无邪_. All rights reserved.
//

//单例对象定义的宏
#define SINGLETON_DEFINE(className) +(className *)shareInstance;

#define SINGLETON_IMPLEMENT(className) \
static className* _instance = nil; \
+ (className *) shareInstance{\
static dispatch_once_t onceToken; \
dispatch_once(&onceToken, ^{ _instance = [[self alloc] init];}); return _instance;\
}\


#import <Foundation/Foundation.h>


extern NSString *const UncaughtExceptionHandlerSignalKey;
extern NSString *const SingalExceptionHandlerAddressesKey;
extern NSString *const ExceptionHandlerAddressesKey;

@interface CatchCrash : NSObject

+(CatchCrash *)shareInstance;

/**
 *  得到所有的crash文件目录
 *
 *  @return 返回所有的crash文件目录
 */
-(NSArray *)getAllCrashLogPath;

/**
 *  得到最近的一次crash
 *
 *  @return 得到最近的一次crash
 */
-(NSString *)getCurrentCrashLog;


//得到指定路径的crash信息
-(NSString *)getCrashLogForPath:(NSString *)path;



@end
