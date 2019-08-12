//
//  CatchCrash.m
//  GGTextView
//
//  Created by 丁华超 on 16/7/11.
//  Copyright © 2016年 __无邪_. All rights reserved.
//

#import "CatchCrash.h"
#include <libkern/OSAtomic.h>
#include <execinfo.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
NSString *const UncaughtExceptionHandlerSignalKey = @"UncaughtExceptionHandlerSignalKey";
NSString *const SingalExceptionHandlerAddressesKey = @"SingalExceptionHandlerAddressesKey";
NSString *const ExceptionHandlerAddressesKey = @"ExceptionHandlerAddressesKey";


const int32_t _uncaughtExceptionMaximum = 20;

//// 系统信号截获处理方法
//void signalHandler(int signal);
//
//// 异常截获处理方法
//void exceptionHandler(NSException *exception);

@interface CatchCrash ()

@property(nonatomic,strong)NSFileManager *fileManager;
@property(nonatomic,assign)long  slideAddress;
@property(nonatomic,copy)NSString *uuidString;

@end
static CatchCrash* _instance = nil;

@implementation CatchCrash



+ (CatchCrash *) shareInstance{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
        [_instance installExceptionHandler];
        [_instance deleteExceedTimeCrash];
    });
    return _instance;
}

#pragma mark public
-(NSArray *)getAllCrashLogPath{
    if (![self.fileManager fileExistsAtPath:[self getCrashDocumentPath]]) {
        [self.fileManager createDirectoryAtPath:[self getCrashDocumentPath] withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSArray *file = [self.fileManager subpathsOfDirectoryAtPath: [self getCrashDocumentPath] error:nil];
    return file;
}


-(NSString *)getCurrentCrashLog{
    
    NSString *content = @"";
    NSString *crashPath = [self getCurrentCrashLogPath];
    if (![crashPath isEqualToString:@""]&&crashPath) {
        content = [NSString stringWithContentsOfFile:crashPath encoding:NSUTF8StringEncoding error:nil];
    }
    return content;
}

-(NSString *)getCrashLogForPath:(NSString *)path{
    
    NSString *content = @"";
    NSString *crashPath = [NSString stringWithFormat:@"%@%@",[self getCrashDocumentPath],path];
    if (![crashPath isEqualToString:@""]&&crashPath) {
        content = [NSString stringWithContentsOfFile:crashPath encoding:NSUTF8StringEncoding error:nil];
    }
    return content?content:@"";
}

#pragma mark pri

// 系统信号截获处理方法
void signalHandler(int signal)
{
    return;
    volatile int32_t _uncaughtExceptionCount = 0;
    int32_t exceptionCount = OSAtomicIncrement32(&_uncaughtExceptionCount);
    
//     如果太多不用处理
    if (exceptionCount > _uncaughtExceptionMaximum) {
        return;
    }
    
    // 获取信息
     NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt:signal] forKey:UncaughtExceptionHandlerSignalKey];
    NSArray *callStack = [_instance backtrace];
    [userInfo  setObject:callStack  forKey:SingalExceptionHandlerAddressesKey];
    
    // 现在就可以保存信息到本地［］
    
    NSString *exceptionInfo = [NSString stringWithFormat:@"time :%@\nUUID %@\n Exception Invoked: %@\n slide address %ld",[_instance getCrashTime],_instance.uuidString,userInfo,_instance.slideAddress];
    [exceptionInfo writeToFile:[[CatchCrash shareInstance] getSignalCrashPath]  atomically:YES encoding:NSUTF8StringEncoding error:nil];
}
// 异常截获处理方法
void exceptionHandler(NSException *exception)
{
    volatile int32_t _uncaughtExceptionCount = 0;
    int32_t exceptionCount = OSAtomicIncrement32(&_uncaughtExceptionCount);
//
    // 如果太多不用处理
    if (exceptionCount > _uncaughtExceptionMaximum) {
        return;
    }
    
    //NSArray *callStack = [_instance backtrace];
    // NSMutableDictionary *userInfo =[NSMutableDictionary dictionaryWithDictionary:[exception userInfo]];
    // [userInfo setObject:callStack forKey:ExceptionHandlerAddressesKey];
    //NSLog(@"Exception Invoked: %@", userInfo);
    
    // 异常的堆栈信息
    
    NSMutableArray *saveStackArray = [NSMutableArray new];
    NSArray *stackArray = [exception callStackSymbols];//符号化信息
    NSArray *ReturnAddressesArray = [exception callStackReturnAddresses];//堆栈地址
    
    for (int i = 0; i<stackArray.count; i++) {
        long address = [[ReturnAddressesArray objectAtIndex:i] longValue];
        NSString *crashInfo = [NSString stringWithFormat:@"%@  0x%@",[stackArray objectAtIndex:i],[_instance ToHex:(address-_instance.slideAddress)]];
        [saveStackArray addObject:crashInfo];
    }
    // 出现异常的原因
    
    NSString *reason = [exception reason];
    
    // 异常名称
    
    NSString *name = [exception name];
    
    NSString *exceptionInfo = [NSString stringWithFormat:@"time :%@\n Exception name：%@\nUUID %@\nException reson：%@\nException stack：%@\n slide address = %ld",[_instance getCrashTime],name, _instance.uuidString, reason,saveStackArray,_instance.slideAddress];
    [exceptionInfo writeToFile:[[CatchCrash shareInstance] getCrashPath]  atomically:YES encoding:NSUTF8StringEncoding error:nil];
    // 现在就可以保存信息到本地［］
    
    
}
//获取调用堆栈
- (NSArray *)backtrace
{
    void* callstack[128];
    int frames                = backtrace(callstack, 128);
    char **strs               = backtrace_symbols(callstack,frames);

    NSMutableArray *backtrace = [NSMutableArray arrayWithCapacity:frames];
    for (int i=0;i<frames;i++) {
        [backtrace addObject:[NSString stringWithUTF8String:strs[i]]];
    }
    free(strs);
    return backtrace;
}


// 注册崩溃拦截
- (void)installExceptionHandler
{
    calculate();
    ExecutableUUID();
    NSSetUncaughtExceptionHandler(&exceptionHandler);
//    signal(SIGHUP, signalHandler);
//    signal(SIGINT, signalHandler);
//    signal(SIGQUIT, signalHandler);
//    signal(SIGABRT, signalHandler);
//    signal(SIGILL, signalHandler);
//    signal(SIGSEGV, signalHandler);
//    signal(SIGFPE, signalHandler);
//    signal(SIGBUS, signalHandler);
//    signal(SIGPIPE, signalHandler);
}

-(NSString *)getCurrentCrashLogPath{
    //__block NSString *crashPath = @"";
    NSString *crashPath = @"";
    NSArray *allCrash = [self getAllCrashLogPath];
    if ([allCrash lastObject]&&[[allCrash lastObject] isKindOfClass:[NSString class]]) {
        crashPath = [NSString stringWithFormat:@"%@%@",[self getCrashDocumentPath],(NSString *)[allCrash lastObject]];
    }
    return crashPath;
}

//计算slide address
void calculate(void) {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        if (_dyld_get_image_header(i)->filetype == MH_EXECUTE) {
            long slide = _dyld_get_image_vmaddr_slide(i);
            [_instance startSetslideAddress:slide];
            break;
    }
    }
}
//查找DSYM UUID
 void ExecutableUUID(void)
{
    const struct mach_header *executableHeader = NULL;
    for (uint32_t i = 0; i < _dyld_image_count(); i++)
    {
        const struct mach_header *header = _dyld_get_image_header(i);
        if (header->filetype == MH_EXECUTE)
        {
            executableHeader = header;
            break;
        }
    }
    
    if (!executableHeader)
        return ;
    
    BOOL is64bit = executableHeader->magic == MH_MAGIC_64 || executableHeader->magic == MH_CIGAM_64;
    uintptr_t cursor = (uintptr_t)executableHeader + (is64bit ? sizeof(struct mach_header_64) : sizeof(struct mach_header));
    const struct segment_command *segmentCommand = NULL;
    for (uint32_t i = 0; i < executableHeader->ncmds; i++, cursor += segmentCommand->cmdsize)
    {
        segmentCommand = (struct segment_command *)cursor;
        if (segmentCommand->cmd == LC_UUID)
        {
            const struct uuid_command *uuidCommand = (const struct uuid_command *)segmentCommand;
           NSUUID *uuid =  [[NSUUID alloc] initWithUUIDBytes:uuidCommand->uuid];
            _instance.uuidString = [uuid UUIDString];//查找到DSYM UUID，保存起来
            return;
        }
    }
    
    return ;
}


-(void)startSetslideAddress:(long)slide{

    self.slideAddress = slide;
}
-(NSString *)ToHex:(long long int)tmpid

{
    
    NSString *nLetterValue;
    
    NSString *str =@"";
    
    long long int ttmpig;
    
    for (int i = 0; i<9; i++) {
        
        ttmpig=tmpid%16;
        
        tmpid=tmpid/16;
        
        switch (ttmpig)
        
        {
                
            case 10:
                
                nLetterValue =@"A";break;
                
            case 11:
                
                nLetterValue =@"B";break;
                
            case 12:
                
                nLetterValue =@"C";break;
                
            case 13:
                
                nLetterValue =@"D";break;
                
            case 14:
                
                nLetterValue =@"E";break;
                
            case 15:
                
                nLetterValue =@"F";break;
                
            default:nLetterValue=[[NSString alloc]initWithFormat:@"%lli",ttmpig];
                
                
                
        }
        
        str = [nLetterValue stringByAppendingString:str];
        
        if (tmpid == 0) {
            
            break;  
            
        }  
        
        
        
    }  
    
    return str;  
    
}


//删除过期的crash文件

-(void)deleteExceedTimeCrash{

    NSArray *allCrash = [self getAllCrashLogPath];
    [allCrash enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:[NSString class]]) {
            NSString *crashFullName = (NSString *)obj;
            NSArray *array = [crashFullName componentsSeparatedByString:@"."];
            if (array.count==2) {
                NSString *crashName = [array objectAtIndex:0];
                NSDate *date = [self fromatDate:crashName];
              NSInteger dayNumber =   [self getDaysFrom:date To:[NSDate new]];
                //NSLog(@"===========%ld",dayNumber);
                if (dayNumber>30) {
                   
                    NSString *crashPath = [NSString stringWithFormat:@"%@%@",[self getCrashDocumentPath],crashFullName];
                    [self.fileManager removeItemAtPath:crashPath error:nil];
                }
            }
            
        }
    }];

}
-(NSInteger)getDaysFrom:(NSDate *)crashDate To:(NSDate *)endDate
{
    NSCalendar *gregorian = [[NSCalendar alloc]
                             initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    
    [gregorian setFirstWeekday:2];
    
    //去掉时分秒信息
    NSDate *fromDate;
    NSDate *toDate;
    [gregorian rangeOfUnit:NSCalendarUnitDay startDate:&fromDate interval:NULL forDate:crashDate];
    [gregorian rangeOfUnit:NSCalendarUnitDay startDate:&toDate interval:NULL forDate:endDate];
    NSDateComponents *dayComponents = [gregorian components:NSCalendarUnitDay fromDate:fromDate toDate:toDate options:0];
    
    return dayComponents.day;
}


- (NSDate*) fromatDate:(NSString *)time
{
    NSString* trim = [time stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if ([@"" isEqualToString:trim]) {
        return [NSDate date];
    }
    
    static NSNumberFormatter* format = nil;
    if (!format) {
        format = [[NSNumberFormatter alloc] init];
    }
    if([format numberFromString:trim])
    {
        //为纯数字
        NSInteger sec = [trim integerValue];
        return [NSDate dateWithTimeIntervalSince1970:sec];
    }else{
        //不是纯数字
        static NSDateFormatter* dateFormat = nil;
        if (!dateFormat) {
            dateFormat = [[NSDateFormatter alloc] init];
            [dateFormat setDateFormat: @"yyyy-MM-dd HH:mm:ss"];
        }
        NSDate* date = nil;
        if ((date = [dateFormat dateFromString:trim])) {
            return date;
        }
    }
    return [NSDate date];
}

-(NSString *)getCrashDocumentPath{
    NSString * destRootPath    = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"crash"];
    
    return [NSString stringWithFormat:@"%@/",destRootPath];
}

//采用两个路径是因为，可能两个捕获的方法都可能触发，经测试时间是一样的，防止不详细的log覆盖详细的log，不同的捕获采用不同的后缀名
-(NSString *)getCrashPath{
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc]init];//格式化
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString* name = [formatter stringFromDate:[NSDate date]];
    return [NSString stringWithFormat:@"%@%@.text",[self getCrashDocumentPath],name];
}

-(NSString *)getSignalCrashPath{
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc]init];//格式化
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString* name = [formatter stringFromDate:[NSDate date]];
    return [NSString stringWithFormat:@"%@%@.log",[self getCrashDocumentPath],name];
}


-(NSString *)getCrashTime{
    NSDateFormatter *formatter = [[NSDateFormatter alloc]init];//格式化
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *time = [formatter stringFromDate:[NSDate date]];
    return time;
}


#pragma getter setter


-(NSFileManager *)fileManager{

    if (!_fileManager) {
        _fileManager = [NSFileManager defaultManager];
    }
    return _fileManager;
}
@end
