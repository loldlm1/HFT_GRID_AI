//+------------------------------------------------------------------+
#include "JsonParser.mqh"
#include "core/addon_catalog.mqh"
CBcrypt BCrypt;

string primary_ci_key = "D3B634B92BDBC9D80BC84ED4F2640644929A5E0DA153FD7D471AF9B5A416B5FE";
string base_secret_key = "loldlm-1994-Slayert1";
string source_secret_key = "trading_sniper_floor";
string license_addons = "";
const string base_ea_id_key = "sniper_advanced_panel";

const string license_api_base_url = "https://tradingsniperpanel.com";
const string license_api_path = "/api/v1/licenses/verify";
const int license_request_timeout_ms = 5000;
const int license_refresh_seconds = 86400;

string license_email = "";
string license_ea_id = "";
datetime license_expire = 0;
datetime last_validation_time = 0;
bool license_payload_ok = false;
bool is_testing = false;
bool license_trial = false;
string license_plan_interval = "";
string license_last_error = "";
int license_last_http_status = 0;
string license_broker_name = "";
string license_broker_company = "";
long license_broker_account_number = 0;
string license_broker_account_type = "";
bool license_broker_account_synced = false;
string license_granted_addons[];

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

void LicenseSetRequestedAddonsCsv(const string addons_csv)
{
  license_addons = Trim(addons_csv);
}

string LicenseGetRequestedAddonsCsv()
{
  return license_addons;
}

void LicenseClearGrantedAddons()
{
  ArrayResize(license_granted_addons, 0);
}

void LicenseAppendGrantedAddon(const string addon_key)
{
  string normalized_key = AddonCatalogNormalizeKey(addon_key);
  if(normalized_key == "")
    return;

  int total = ArraySize(license_granted_addons);
  for(int i = 0; i < total; i++)
  {
    if(AddonCatalogKeysEqual(license_granted_addons[i], normalized_key))
      return;
  }

  ArrayResize(license_granted_addons, total + 1);
  license_granted_addons[total] = normalized_key;
}

int LicenseGrantedAddonCount()
{
  return ArraySize(license_granted_addons);
}

bool LicenseIsTestingMode()
{
  return is_testing;
}

bool LicenseHasAddon(const string addon_key)
{
  if(LicenseIsTestingMode())
    return true;

  string normalized_key = AddonCatalogNormalizeKey(addon_key);
  if(normalized_key == "")
    return false;

  int total = ArraySize(license_granted_addons);
  for(int i = 0; i < total; i++)
  {
    if(AddonCatalogKeysEqual(license_granted_addons[i], normalized_key))
      return true;
  }

  return false;
}

bool LicenseHasAnyCompoundFamilyAddon()
{
  string compound_families[];
  AddonCatalogAllCompoundFamilies(compound_families);

  int total = ArraySize(compound_families);
  for(int i = 0; i < total; i++)
  {
    if(LicenseHasAddon(compound_families[i]))
      return true;
  }
  return false;
}

void LicenseCopyGrantedAddons(string &addons_out[])
{
  int total = ArraySize(license_granted_addons);
  ArrayResize(addons_out, total);
  for(int i = 0; i < total; i++)
    addons_out[i] = license_granted_addons[i];
}

bool LicenseParseGrantedAddonsFromResponse(JSON::Object &response)
{
  LicenseClearGrantedAddons();

  if(!response.isArray("granted_addons"))
    return false;

  JSON::Array *addons = response.getArray("granted_addons");
  if(addons == NULL)
    return false;

  int total = addons.getLength();
  for(int i = 0; i < total; i++)
  {
    if(!addons.isString(i))
      continue;
    LicenseAppendGrantedAddon(addons.getString(i));
  }

  return true;
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

string AccountTypeToString()
{
  if(is_testing) return "testing";

  ENUM_ACCOUNT_TRADE_MODE trade_mode = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
  if(trade_mode == ACCOUNT_TRADE_MODE_REAL) return "real";
  if(trade_mode == ACCOUNT_TRADE_MODE_DEMO) return "demo";

  return "unknown";
}

string BuildLicensePayload()
{
  JSON::Object payload;
  payload.setProperty("source", source_secret_key);
  payload.setProperty("email", license_email);
  payload.setProperty("ea_id", license_ea_id);
  payload.setProperty("license_key", EA_License_Key);
  if(StringLen(Trim(license_addons)) > 0)
    payload.setProperty("addons", Trim(license_addons));

  JSON::Object* broker_account = new JSON::Object();
  broker_account.setProperty("name", AccountInfoString(ACCOUNT_NAME));
  broker_account.setProperty("company", AccountInfoString(ACCOUNT_COMPANY));
  broker_account.setProperty("account_number", (long)AccountInfoInteger(ACCOUNT_LOGIN));
  broker_account.setProperty("account_type", AccountTypeToString());
  payload.setProperty("broker_account", broker_account);

  return payload.toString();
}

bool HttpPostJson(const string url, const string payload, string &response_body, int &status_code)
{
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
    PrintFormat("LICENSE REQUEST FAILED (error %d).", err);
    return false;
  }

  response_body = CharArrayToString(result, 0, -1, CP_UTF8);
  status_code = res;
  return true;
}

bool License_IsAuthError(const string error_code)
{
  if(error_code=="invalid_source") return true;
  if(error_code=="invalid_key") return true;
  if(error_code=="addons_required") return true;
  if(error_code=="trial_disabled") return true;
  return false;
}

void License_ClearRuntimeDetails()
{
  license_trial=false;
  license_plan_interval="";
  license_last_error="";
  license_last_http_status=0;
  license_broker_name="";
  license_broker_company="";
  license_broker_account_number=0;
  license_broker_account_type="";
  license_broker_account_synced=false;
  LicenseClearGrantedAddons();
}

void License_ParseBrokerAccountFromResponse(JSON::Object &response)
{
  license_broker_name="";
  license_broker_company="";
  license_broker_account_number=0;
  license_broker_account_type="";
  license_broker_account_synced=false;

  if(!response.isObject("broker_account"))
    return;

  JSON::Object *broker=response.getObject("broker_account");
  if(broker==NULL)
    return;

  if(broker.isString("name"))
    license_broker_name=broker.getString("name");
  if(broker.isString("company"))
    license_broker_company=broker.getString("company");
  if(broker.isNumber("account_number"))
    license_broker_account_number=(long)broker.getNumber("account_number");
  if(broker.isString("account_type"))
    license_broker_account_type=broker.getString("account_type");

  license_broker_account_synced=(license_broker_company!="" &&
                                 license_broker_account_number>0 &&
                                 (license_broker_account_type=="real" || license_broker_account_type=="demo"));
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
  License_ClearRuntimeDetails();
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
  license_last_error="";
  license_last_http_status=0;

  string url = license_api_base_url + license_api_path;
  string payload = BuildLicensePayload();
  string response_body = "";
  int status_code = 0;

  if(!HttpPostJson(url, payload, response_body, status_code))
  {
    license_last_error="request_failed";
    Print("LICENSE SERVER REQUEST FAILED.");
    return false;
  }

  license_last_http_status=status_code;
  string response_copy = response_body;
  JSON::Object response(response_copy);
  if(response.isString("error"))
    license_last_error=response.getString("error");

  if(status_code < 200 || status_code >= 300)
  {
    if(license_last_error!="")
      PrintFormat("LICENSE REJECTED (HTTP %d): %s",status_code,license_last_error);
    else
      PrintFormat("LICENSE SERVER ERROR (HTTP %d).",status_code);
    return false;
  }

  bool ok = response.isBoolean("ok") ? response.getBoolean("ok") : false;
  if(!ok)
  {
    if(license_last_error!="")
      Print("LICENSE REJECTED: " + license_last_error);
    else
      Print("LICENSE REJECTED.");
    return false;
  }

  license_trial=response.isBoolean("trial") ? response.getBoolean("trial") : false;
  license_plan_interval=response.isString("plan_interval") ? response.getString("plan_interval") : "";
  License_ParseBrokerAccountFromResponse(response);
  if(!LicenseParseGrantedAddonsFromResponse(response))
  {
    license_last_error="invalid_granted_addons";
    Print("LICENSE RESPONSE MISSING granted_addons.");
    return false;
  }

  long expires_at = 0;
  if(response.isNumber("expires_at"))
    expires_at = (long)response.getNumber("expires_at");
  if(expires_at <= 0)
  {
    license_last_error="invalid_expires_at";
    Print("LICENSE EXPIRATION INVALID.");
    return false;
  }

  license_expire = (datetime)expires_at;
  if(license_expire <= TimeCurrent())
  {
    Print("LICENSE TIME HAS EXPIRED, CONTACT SUPPORT.");
    return false;
  }

  last_validation_time = TimeCurrent();
  if(license_last_error!="" && License_IsAuthError(license_last_error))
    PrintFormat("VALID EA LICENSE (auth warning ignored: %s).",license_last_error);
  else
    PrintFormat("VALID EA LICENSE! trial=%s plan_interval=%s broker_synced=%s addons=%d",
                (license_trial?"true":"false"),
                (license_plan_interval==""?"n/a":license_plan_interval),
                (license_broker_account_synced?"true":"false"),
                LicenseGrantedAddonCount());
  license_last_error="";
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
  if((now - last_validation_time) < license_refresh_seconds) return;

  if(!VerifyLicense())
  {
    if(license_last_http_status>0)
      PrintFormat("LICENSE REFRESH FAILED (HTTP %d, error=%s). EA REMOVED.",
                  license_last_http_status,
                  (license_last_error==""?"unknown":license_last_error));
    else
      PrintFormat("LICENSE REFRESH FAILED (error=%s). EA REMOVED.",
                  (license_last_error==""?"request_failed":license_last_error));
    ExpertRemove();
  }
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
