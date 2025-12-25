//+------------------------------------------------------------------+
#include "JsonParser.mqh"
CBcrypt BCrypt;

string primary_ci_key = "D3B634B92BDBC9D80BC84ED4F2640644929A5E0DA153FD7D471AF9B5A416B5FE";
string base_secret_key = "loldlm-1994-Slayert1";
string source_secret_key = "trading_sniper_floor";
const string base_ea_id_key = "pandora_box";

const string license_api_base_url = "http://127.0.0.1:3000";
const string license_api_path = "/api/v1/licenses/verify";
const int license_request_timeout_ms = 5000;
const int license_refresh_seconds = 86400;

string license_email = "";
string license_ea_id = "";
datetime license_expire = 0;
datetime last_validation_time = 0;
bool license_payload_ok = false;
bool is_testing = false;

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

  if(!HttpPostJson(url, payload, response_body, status_code))
  {
    Print("LICENSE SERVER REQUEST FAILED.");
    return false;
  }

  if(status_code < 200 || status_code >= 300)
  {
    string response_copy = response_body;
    JSON::Object response(response_copy);
    if(response.isString("error"))
      Print("LICENSE REJECTED: " + response.getString("error"));
    else
      PrintFormat("LICENSE SERVER ERROR (HTTP %d).", status_code);
    return false;
  }

  string response_copy = response_body;
  JSON::Object response(response_copy);
  bool ok = response.isBoolean("ok") ? response.getBoolean("ok") : false;
  if(!ok)
  {
    if(response.isString("error"))
      Print("LICENSE REJECTED: " + response.getString("error"));
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
  if((now - last_validation_time) < license_refresh_seconds) return;

  if(!VerifyLicense())
  {
    Print("LICENSE REFRESH FAILED. EA REMOVED.");
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
