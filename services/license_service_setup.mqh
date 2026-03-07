//+------------------------------------------------------------------+
//|                       services/license_service_setup.mqh          |
//+------------------------------------------------------------------+
#ifndef _SERVICES_LICENSE_SERVICE_SETUP_MQH_
#define _SERVICES_LICENSE_SERVICE_SETUP_MQH_

// EA profile configuration for the shared license guard service.
#ifndef LICENSE_SHARED_PROFILE_NAME
#define LICENSE_SHARED_PROFILE_NAME "Fibonacci EA"
#endif

#ifndef LICENSE_SHARED_SOURCE_KEY
#define LICENSE_SHARED_SOURCE_KEY "trading_sniper_floor"
#endif

#ifndef LICENSE_SHARED_BASE_EA_ID
#define LICENSE_SHARED_BASE_EA_ID "fibonacci_elite"
#endif

#ifndef LICENSE_SHARED_API_BASE_URL
#define LICENSE_SHARED_API_BASE_URL "https://tradingsniperpanel.com"
#endif

#ifndef LICENSE_SHARED_PRIMARY_CI_KEY
#define LICENSE_SHARED_PRIMARY_CI_KEY "D3B634B92BDBC9D80BC84ED4F2640644929A5E0DA153FD7D471AF9B5A416B5FE"
#endif

#ifndef LICENSE_SHARED_BASE_SECRET_KEY
#define LICENSE_SHARED_BASE_SECRET_KEY "loldlm-1994-Slayert1"
#endif

#ifndef LICENSE_SHARED_ENFORCEMENT_ENABLED
#define LICENSE_SHARED_ENFORCEMENT_ENABLED 1
#endif

#ifndef LICENSE_SHARED_DAILY_RESULTS_ENABLED
#define LICENSE_SHARED_DAILY_RESULTS_ENABLED 1
#endif

#ifndef LICENSE_SHARED_ENABLE_ADDON_ENTITLEMENTS
#define LICENSE_SHARED_ENABLE_ADDON_ENTITLEMENTS 1
#endif

#ifndef LICENSE_SHARED_COLLECT_REQUESTED_ADDONS
#define LICENSE_SHARED_COLLECT_REQUESTED_ADDONS CollectRequestedAddonsForCurrentInputs
#endif

void CollectRequestedAddonsForCurrentInputs(string &addons_out[]);

#ifndef LICENSE_SHARED_REQUIRED_ADDONS_CSV
#define LICENSE_SHARED_REQUIRED_ADDONS_CSV ""
#endif

#include "shared/license_guard_v1/license_service.mqh"

#endif // _SERVICES_LICENSE_SERVICE_SETUP_MQH_
