//+------------------------------------------------------------------+
#include "JsonParser.mqh"
CBcrypt BCrypt;

string primary_ci_key = "D3B634B92BDBC9D80BC84ED4F2640644929A5E0DA153FD7D471AF9B5A416B5FE";
string base_secret_key = "loldlm-1994-Slayert1";
string source_secret_key = "trading_sniper_floor";
const string base_ea_id_key = "pandora_box";

const string license_api_base_url = "http://127.0.0.1:3000";
const string license_api_path = "/api/v1/licenses/verify";
const string daily_results_api_path = "/api/v1/broker_accounts/daily_results";
const int license_request_timeout_ms = 5000;
const int license_refresh_seconds = 86400;
const int license_timer_seconds = 60;
const int daily_results_max_retry_attempts = 5;

string license_email = "";
string license_ea_id = "";
datetime license_expire = 0;
datetime last_validation_time = 0;
bool license_payload_ok = false;
bool is_testing = false;
bool license_trial = false;
string license_plan_interval = "";
string license_broker_name = "";
string license_broker_company = "";
long license_broker_account_number = 0;
string license_broker_account_type = "";
string license_addons_csv = "";

string SidToString(const uchar &sid[])
{
  string sidString;
  int sidLength = ArraySize(sid);

  for (int i = 0; i < sidLength; i++)
  {
    sidString += StringFormat("%02X", sid[i]);
    if (i < sidLength - 1) sidString += "-";
  }

  return sidString;
}

string Trim(string value)
{
  StringTrimLeft(value);
  StringTrimRight(value);
  return value;
}

bool IsValidEmail(const string email)
{
  int at_pos = StringFind(email, "@");
  if(at_pos <= 0) return false;
  if(at_pos >= StringLen(email) - 1) return false;
  return true;
}

int ParseHttpStatus(const string headers)
{
  int pos = StringFind(headers, "HTTP/");
  if(pos < 0) return 0;
  int space = StringFind(headers, " ", pos);
  if(space < 0) return 0;
  int end = StringFind(headers, " ", space + 1);
  if(end < 0)
    end = StringFind(headers, "\r", space + 1);
  if(end < 0)
    end = StringLen(headers);

  string code_str = StringSubstr(headers, space + 1, end - (space + 1));
  return (int)StringToInteger(code_str);
}

string ToLowerCopy(string value)
{
  StringToLower(value);
  return value;
}

string AccountTypeToString()
{
  if(is_testing) return "testing";

  ENUM_ACCOUNT_TRADE_MODE trade_mode = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
  if(trade_mode == ACCOUNT_TRADE_MODE_REAL) return "real";
  if(trade_mode == ACCOUNT_TRADE_MODE_DEMO) return "demo";

  return "unknown";
}

JSON::Object* BuildBrokerAccountObject(const bool include_name)
{
  JSON::Object* broker_account = new JSON::Object();
  if(include_name)
    broker_account.setProperty("name", AccountInfoString(ACCOUNT_NAME));

  broker_account.setProperty("company", AccountInfoString(ACCOUNT_COMPANY));
  broker_account.setProperty("account_number", (long)AccountInfoInteger(ACCOUNT_LOGIN));
  broker_account.setProperty("account_type", AccountTypeToString());
  return broker_account;
}

JSON::Object* BuildDailyResultsBrokerAccountObject()
{
  string broker_company = license_broker_company;
  if(StringLen(broker_company) <= 0)
    broker_company = AccountInfoString(ACCOUNT_COMPANY);

  long broker_account_number = license_broker_account_number;
  if(broker_account_number <= 0)
    broker_account_number = (long)AccountInfoInteger(ACCOUNT_LOGIN);

  string broker_account_type = license_broker_account_type;
  if(StringLen(broker_account_type) <= 0)
    broker_account_type = AccountTypeToString();

  JSON::Object* broker_account = new JSON::Object();
  broker_account.setProperty("company", broker_company);
  broker_account.setProperty("account_number", broker_account_number);
  broker_account.setProperty("account_type", broker_account_type);
  return broker_account;
}

void AppendOptionalAddons(JSON::Object &payload)
{
  string addons_csv = Trim(license_addons_csv);
  if(StringLen(addons_csv) <= 0)
    return;

  string values[];
  int values_total = StringSplit(addons_csv, StringGetCharacter(",", 0), values);
  if(values_total <= 0)
    return;

  JSON::Array* addons = new JSON::Array();
  int added = 0;
  for(int i = 0; i < values_total; i++)
  {
    string addon = Trim(values[i]);
    if(StringLen(addon) <= 0)
      continue;
    addons.add(addon);
    added++;
  }

  if(added > 0)
    payload.setProperty("addons", addons);
  else
    delete addons;
}

string BuildLicensePayload()
{
  JSON::Object payload;
  payload.setProperty("source", source_secret_key);
  payload.setProperty("email", license_email);
  payload.setProperty("ea_id", license_ea_id);
  payload.setProperty("license_key", EA_License_Key);
  payload.setProperty("broker_account", BuildBrokerAccountObject(true));
  AppendOptionalAddons(payload);
  return payload.toString();
}

string BuildDailyResultsPayload(const datetime result_timestamp,
                                const string result_value)
{
  JSON::Object payload;
  payload.setProperty("source", source_secret_key);
  payload.setProperty("email", license_email);
  payload.setProperty("ea_id", license_ea_id);
  payload.setProperty("license_key", EA_License_Key);
  payload.setProperty("broker_account", BuildDailyResultsBrokerAccountObject());
  payload.setProperty("result_timestamp", (long)result_timestamp);
  payload.setProperty("result_value", result_value);
  return payload.toString();
}

string ExtractApiError(const string response_body)
{
  if(StringLen(response_body) <= 0)
    return "";

  string response_copy = response_body;
  JSON::Object response(response_copy);
  if(response.isString("error"))
    return response.getString("error");
  return "";
}

bool IsApiErrorMatch(const string actual_error,
                     const string expected_error)
{
  string actual = ToLowerCopy(Trim(actual_error));
  string expected = ToLowerCopy(Trim(expected_error));
  return (actual == expected);
}

bool HttpPostJson(const string request_tag,
                  const string url,
                  const string payload,
                  string &response_body,
                  int &status_code)
{
  status_code = 0;
  response_body = "";

  uchar data[];
  int data_len = StringToCharArray(payload, data, 0, WHOLE_ARRAY, CP_UTF8) - 1;
  if(data_len < 0) data_len = 0;
  ArrayResize(data, data_len);

  uchar result[];
  string result_headers;
  string headers = "Content-Type: application/json; charset=utf-8\r\n"
                   "Accept: application/json\r\n";

  ResetLastError();
  int res = WebRequest("POST", url, headers, license_request_timeout_ms, data, result, result_headers);
  if(res == -1)
  {
    int err = GetLastError();
    PrintFormat("%s REQUEST FAILED (error %d).", request_tag, err);
    return false;
  }

  response_body = CharArrayToString(result, 0, -1, CP_UTF8);
  status_code = res;
  return true;
}

void UpdateLicenseRuntimeContext(const JSON::Object &response)
{
  if(response.isBoolean("trial"))
    license_trial = response.getBoolean("trial");
  else
    license_trial = false;

  if(response.isString("plan_interval"))
    license_plan_interval = response.getString("plan_interval");
  else
    license_plan_interval = "";

  if(!response.isObject("broker_account"))
    return;

  JSON::Object* broker_account = response.getObject("broker_account");
  if(broker_account == NULL)
    return;

  if(broker_account.isString("name"))
    license_broker_name = broker_account.getString("name");
  else
    license_broker_name = "";

  if(broker_account.isString("company"))
    license_broker_company = broker_account.getString("company");
  else
    license_broker_company = "";

  if(broker_account.isNumber("account_number"))
    license_broker_account_number = (long)broker_account.getNumber("account_number");
  else
    license_broker_account_number = 0;

  if(broker_account.isString("account_type"))
    license_broker_account_type = broker_account.getString("account_type");
  else
    license_broker_account_type = "";
}

string DailyResultsKeyPrefix()
{
  string ea_key = license_ea_id;
  if(StringLen(ea_key) <= 0)
    ea_key = base_ea_id_key;
  return "PB_DRES_" + ea_key + "_" + (string)AccountInfoInteger(ACCOUNT_LOGIN);
}

string DailyResultsKeySyncedDay()
{
  return DailyResultsKeyPrefix() + "_SYNC_DAY";
}

string DailyResultsKeyBlockedDay()
{
  return DailyResultsKeyPrefix() + "_BLOCK_DAY";
}

string DailyResultsKeyRetryDay()
{
  return DailyResultsKeyPrefix() + "_RETRY_DAY";
}

string DailyResultsKeyRetryCount()
{
  return DailyResultsKeyPrefix() + "_RETRY_COUNT";
}

string DailyResultsKeyNextRetry()
{
  return DailyResultsKeyPrefix() + "_NEXT_RETRY";
}

double ReadTerminalGlobalValue(const string key,
                               const double fallback_value)
{
  if(!GlobalVariableCheck(key))
    return fallback_value;
  return GlobalVariableGet(key);
}

void WriteTerminalGlobalValue(const string key,
                              const double value)
{
  GlobalVariableSet(key, value);
}

void DeleteTerminalGlobalValue(const string key)
{
  if(GlobalVariableCheck(key))
    GlobalVariableDel(key);
}

void DailyResultsClearRetryState()
{
  DeleteTerminalGlobalValue(DailyResultsKeyRetryDay());
  DeleteTerminalGlobalValue(DailyResultsKeyRetryCount());
  DeleteTerminalGlobalValue(DailyResultsKeyNextRetry());
}

void DailyResultsMarkSynced(const datetime report_day_start_utc)
{
  WriteTerminalGlobalValue(DailyResultsKeySyncedDay(), (double)report_day_start_utc);
  DeleteTerminalGlobalValue(DailyResultsKeyBlockedDay());
  DailyResultsClearRetryState();
}

void DailyResultsMarkBlocked(const datetime report_day_start_utc)
{
  WriteTerminalGlobalValue(DailyResultsKeyBlockedDay(), (double)report_day_start_utc);
  DailyResultsClearRetryState();
}

int DailyResultsResolveRetryDelaySeconds(const int retry_attempt)
{
  if(retry_attempt <= 1)
    return 300;
  if(retry_attempt == 2)
    return 900;
  if(retry_attempt == 3)
    return 1800;
  if(retry_attempt == 4)
    return 3600;
  return 7200;
}

void DailyResultsScheduleRetry(const datetime report_day_start_utc,
                               const int status_code,
                               const string api_error)
{
  int retry_count = (int)ReadTerminalGlobalValue(DailyResultsKeyRetryCount(), 0.0);
  if((datetime)ReadTerminalGlobalValue(DailyResultsKeyRetryDay(), 0.0) != report_day_start_utc)
    retry_count = 0;

  retry_count++;
  if(retry_count > daily_results_max_retry_attempts)
    retry_count = daily_results_max_retry_attempts;

  int delay_seconds = DailyResultsResolveRetryDelaySeconds(retry_count);
  datetime next_retry_time = TimeCurrent() + delay_seconds;

  WriteTerminalGlobalValue(DailyResultsKeyRetryDay(), (double)report_day_start_utc);
  WriteTerminalGlobalValue(DailyResultsKeyRetryCount(), (double)retry_count);
  WriteTerminalGlobalValue(DailyResultsKeyNextRetry(), (double)next_retry_time);

  PrintFormat("DAILY RESULTS RETRY SCHEDULED | day=%s | attempt=%d/%d | next_retry=%s | http=%d | error=%s",
              TimeToString(report_day_start_utc, TIME_DATE | TIME_SECONDS),
              retry_count,
              daily_results_max_retry_attempts,
              TimeToString(next_retry_time, TIME_DATE | TIME_SECONDS),
              status_code,
              api_error);
}

datetime ResolveUtcDayStart(const datetime utc_time)
{
  if(utc_time <= 0)
    return 0;
  return utc_time - (utc_time % 86400);
}

datetime ResolveLatestCompletedUtcDayStart()
{
  datetime utc_now = TimeGMT();
  datetime current_day_start = ResolveUtcDayStart(utc_now);
  if(current_day_start < 86400)
    return 0;
  return current_day_start - 86400;
}

int ResolveServerUtcOffsetSeconds()
{
  datetime server_now = TimeTradeServer();
  datetime utc_now = TimeGMT();
  if(server_now <= 0 || utc_now <= 0)
    return 0;
  return (int)(server_now - utc_now);
}

bool IsClosingTradeDeal(const ulong deal_ticket)
{
  long entry_type = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
  if(entry_type != DEAL_ENTRY_OUT &&
     entry_type != DEAL_ENTRY_INOUT &&
     entry_type != DEAL_ENTRY_OUT_BY)
  {
    return false;
  }

  long deal_type = HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
  return (deal_type == DEAL_TYPE_BUY || deal_type == DEAL_TYPE_SELL);
}

bool ComputeDailyClosedResult(const datetime report_day_start_utc,
                              double &result_value)
{
  result_value = 0.0;
  if(report_day_start_utc <= 0)
    return false;

  int server_offset_seconds = ResolveServerUtcOffsetSeconds();
  datetime history_from_server = report_day_start_utc + server_offset_seconds;
  datetime history_to_server = history_from_server + 86400;
  if(history_to_server <= history_from_server)
    return false;

  if(!HistorySelect(history_from_server, history_to_server))
  {
    Print("DAILY RESULTS HISTORY SELECT FAILED.");
    return false;
  }

  int deals_total = HistoryDealsTotal();
  for(int i = 0; i < deals_total; i++)
  {
    ulong deal_ticket = HistoryDealGetTicket(i);
    if(deal_ticket <= 0)
      continue;
    if(!IsClosingTradeDeal(deal_ticket))
      continue;

    datetime deal_server_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
    datetime deal_utc_time = deal_server_time - server_offset_seconds;
    if(deal_utc_time < report_day_start_utc || deal_utc_time >= (report_day_start_utc + 86400))
      continue;

    double deal_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
    double deal_swap = HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
    double deal_commission = HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
    double deal_fee = HistoryDealGetDouble(deal_ticket, DEAL_FEE);
    result_value += (deal_profit + deal_swap + deal_commission + deal_fee);
  }

  return true;
}

bool SendDailyResults(const datetime report_day_start_utc,
                      const string result_value,
                      int &status_code,
                      string &api_error)
{
  string url = license_api_base_url + daily_results_api_path;
  string payload = BuildDailyResultsPayload(report_day_start_utc, result_value);
  string response_body = "";
  status_code = 0;
  api_error = "";

  if(!HttpPostJson("DAILY_RESULTS", url, payload, response_body, status_code))
  {
    api_error = "network_error";
    return false;
  }

  api_error = ExtractApiError(response_body);
  return true;
}

void DailyResultsProcess()
{
  if(!license_payload_ok)
    return;
  if(!ValidateLicensePayload())
    return;

  datetime report_day_start_utc = ResolveLatestCompletedUtcDayStart();
  if(report_day_start_utc <= 0)
    return;

  datetime synced_day = (datetime)ReadTerminalGlobalValue(DailyResultsKeySyncedDay(), 0.0);
  if(synced_day == report_day_start_utc)
    return;

  datetime blocked_day = (datetime)ReadTerminalGlobalValue(DailyResultsKeyBlockedDay(), 0.0);
  if(blocked_day == report_day_start_utc)
    return;

  datetime retry_day = (datetime)ReadTerminalGlobalValue(DailyResultsKeyRetryDay(), 0.0);
  if(retry_day != report_day_start_utc)
    DailyResultsClearRetryState();

  int retry_count = (int)ReadTerminalGlobalValue(DailyResultsKeyRetryCount(), 0.0);
  if(retry_count >= daily_results_max_retry_attempts)
    return;

  datetime next_retry_time = (datetime)ReadTerminalGlobalValue(DailyResultsKeyNextRetry(), 0.0);
  if(next_retry_time > TimeCurrent())
    return;

  double result_value = 0.0;
  if(!ComputeDailyClosedResult(report_day_start_utc, result_value))
  {
    DailyResultsScheduleRetry(report_day_start_utc, 0, "history_select_failed");
    return;
  }

  string result_value_str = DoubleToString(result_value, 2);
  int status_code = 0;
  string api_error = "";
  bool request_ok = SendDailyResults(report_day_start_utc,
                                     result_value_str,
                                     status_code,
                                     api_error);

  if(!request_ok)
  {
    DailyResultsScheduleRetry(report_day_start_utc, status_code, api_error);
    return;
  }

  if(status_code == 404 && IsApiErrorMatch(api_error, "broker_account_not_found"))
  {
    Print("DAILY RESULTS BROKER ACCOUNT MISSING. RUNNING ONE LICENSE RE-VERIFY.");
    if(VerifyLicenseOnline())
      request_ok = SendDailyResults(report_day_start_utc,
                                    result_value_str,
                                    status_code,
                                    api_error);
  }

  if(request_ok && (status_code == 201 || status_code == 409))
  {
    DailyResultsMarkSynced(report_day_start_utc);
    PrintFormat("DAILY RESULTS SYNCED | day=%s | value=%s | http=%d",
                TimeToString(report_day_start_utc, TIME_DATE | TIME_SECONDS),
                result_value_str,
                status_code);
    return;
  }

  if(status_code == 422 && IsApiErrorMatch(api_error, "invalid_payload"))
  {
    DailyResultsMarkBlocked(report_day_start_utc);
    PrintFormat("DAILY RESULTS BLOCKED FOR DAY | day=%s | http=%d | error=%s",
                TimeToString(report_day_start_utc, TIME_DATE | TIME_SECONDS),
                status_code,
                api_error);
    return;
  }

  DailyResultsScheduleRetry(report_day_start_utc, status_code, api_error);
}

bool ValidateLicensePayload()
{
  if(!IsValidEmail(license_email)) return false;
  if(StringLen(license_ea_id) == 0) return false;
  if(license_ea_id != base_ea_id_key)
  {
    Print("LICENSE EA ID DOES NOT MATCH.");
    return false;
  }
  if(license_expire <= 0) return false;
  return true;
}

string EncryptEA(string email = "", string ea_id = "", int days = 30)
{
  if(email == "") email = AccountInfoString(ACCOUNT_NAME);
  if(ea_id == "") ea_id = base_ea_id_key;

  string payload = email + "," + ea_id + "," + (string)(TimeCurrent() + (60 * 60 * 24 * days));
  BCrypt.Init(primary_ci_key, base_secret_key, payload);
  string encrypted_payload = BCrypt.Encrypt();

  Print("NEW LICENSE KEY= ", encrypted_payload);
  return encrypted_payload;
}

bool DecryptEA()
{
  license_payload_ok = false;
  if(StringLen(EA_License_Key) == 0)
  {
    Print("LICENSE KEY IS EMPTY.");
    return false;
  }

  string license_privileges[];
  ushort u_sep = StringGetCharacter(",", 0);
  BCrypt.Init(primary_ci_key, base_secret_key);
  string decrypted_payload = BCrypt.Decrypt(EA_License_Key);

  int license_ok = StringSplit(decrypted_payload, u_sep, license_privileges);
  if(license_ok != 3)
  {
    Print("Could not decrypt the current license.");
    return false;
  }

  license_email = Trim(license_privileges[0]);
  license_ea_id = Trim(license_privileges[1]);
  license_expire = (datetime)StringToInteger(Trim(license_privileges[2]));

  if(!ValidateLicensePayload())
  {
    Print("LICENSE PAYLOAD INVALID.");
    return false;
  }

  license_payload_ok = true;
  Print("LICENSE PAYLOAD OK.");
  return true;
}

bool VerifyOnlyValidEAs(string ea_name)
{
  if(IsAdmin()) return true;

  long 	 chartID 		 = ChartFirst();
  string expert_name = "";
  string script_name = "";

  while(chartID > 0)
  {
    expert_name = ChartGetString(chartID, CHART_EXPERT_NAME);
    script_name = ChartGetString(chartID, CHART_SCRIPT_NAME);

    if(StringLen(expert_name) > 0 && expert_name != ea_name) { Print("Only valid [", ea_name, "] system EAs."); return false; }
    if(StringLen(script_name) > 0 && expert_name != ea_name) { Print("Only valid [", ea_name, "] system EAs."); return false; }

    chartID = ChartNext(chartID);

    if(chartID <= 0) break;
  }

  return true;
}

bool VerifyLicenseTester()
{
  if(!license_payload_ok && !DecryptEA()) return false;
  if(!ValidateLicensePayload()) return false;
  if(license_expire <= TimeCurrent())
  {
    Print("LICENSE TIME HAS EXPIRED, CONTACT SUPPORT.");
    return false;
  }

  last_validation_time = TimeCurrent();
  Print("VALID EA LICENSE (TESTER)!");
  return true;
}

bool VerifyLicenseOnline()
{
  if(!license_payload_ok && !DecryptEA()) return false;

  string url = license_api_base_url + license_api_path;
  string payload = BuildLicensePayload();
  string response_body = "";
  int status_code = 0;

  if(!HttpPostJson("LICENSE_VERIFY", url, payload, response_body, status_code))
  {
    Print("LICENSE SERVER REQUEST FAILED (NETWORK).");
    return false;
  }

  string api_error = ExtractApiError(response_body);
  if(status_code < 200 || status_code >= 300)
  {
    if(StringLen(api_error) > 0)
      PrintFormat("LICENSE SERVER ERROR | http=%d | error=%s", status_code, api_error);
    else
      PrintFormat("LICENSE SERVER ERROR | http=%d", status_code);
    return false;
  }

  string response_copy = response_body;
  JSON::Object response(response_copy);
  bool ok = response.isBoolean("ok") ? response.getBoolean("ok") : false;
  if(!ok)
  {
    if(StringLen(api_error) > 0)
      Print("LICENSE REJECTED: " + api_error);
    else
      Print("LICENSE REJECTED.");
    return false;
  }

  long expires_at = 0;
  if(response.isNumber("expires_at"))
    expires_at = (long)response.getNumber("expires_at");
  if(expires_at <= 0)
  {
    Print("LICENSE EXPIRATION INVALID.");
    return false;
  }

  license_expire = (datetime)expires_at;
  UpdateLicenseRuntimeContext(response);
  if(license_expire <= TimeCurrent())
  {
    Print("LICENSE TIME HAS EXPIRED, CONTACT SUPPORT.");
    return false;
  }

  last_validation_time = TimeCurrent();
  Print("VALID EA LICENSE!");
  return true;
}

bool VerifyLicense()
{
  if(is_testing) return VerifyLicenseTester();
  return VerifyLicenseOnline();
}

bool VerifyLicenseType()
{
  return true;
}

bool VerifyValidLicenseTime()
{
  if(license_expire <= 0)
  {
    Print("LICENSE EXPIRATION INVALID.");
    return false;
  }
  if(license_expire > TimeCurrent()) return true;

  Print("LICENSE TIME HAS EXPIRED, CONTACT SUPPORT.");
  return false;
}

void LicenseOnline_OnTimer()
{
  if(is_testing) return;
  if(last_validation_time == 0) return;

  datetime now = TimeCurrent();
  if((now - last_validation_time) >= license_refresh_seconds && !VerifyLicense())
  {
    Print("LICENSE REFRESH FAILED. EA REMOVED.");
    ExpertRemove();
    return;
  }

  DailyResultsProcess();
}

bool IsAdmin()
{
  return false;
}

bool CanBacktest()
{
  return true;
}

bool AllowDemo()
{
  return true;
}

bool AllowLive()
{
  return true;
}
