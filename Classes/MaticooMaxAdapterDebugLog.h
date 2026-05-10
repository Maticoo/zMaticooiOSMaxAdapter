//
//  MaticooMaxAdapterDebugLog.h
//  Optional NSLog-style traces for MaticooMaxAdapter (off unless MATICOO_MAX_ADAPTER_LOG is set).
//

#ifndef MaticooMaxAdapterDebugLog_h
#define MaticooMaxAdapterDebugLog_h

#ifdef MATICOO_MAX_ADAPTER_LOG
#define MaticooMaxAdapterDebugLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#else
#define MaticooMaxAdapterDebugLog(...)
#endif

#endif /* MaticooMaxAdapterDebugLog_h */
