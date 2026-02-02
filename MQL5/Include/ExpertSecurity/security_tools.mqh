#include <Bcrypt.mqh>
CBcrypt BCrypt;

string   base_secret_key  = "loldlm1";
string   current_account  = "";
string   license_type     = "";
string   license_name     = "";
datetime license_expire   = 0;

void GetWUserID()
{
  /*
  HANDLE hToken;
  OpenProcessToken(GetCurrentProcess(), 0x0008, hToken);

  PVOID tokenInfo;
  int returnLength;
  //HANDLE hToken = TerminalInfoInteger(TERMINAL_X64) ? GetCurrentProcess64() : GetCurrentProcess();
  int tokenInfoSize = 68;

  int result = GetTokenInformation(hToken, 1, tokenInfo, tokenInfoSize, returnLength);

  //uchar userSidSize = ((uchar)tokenInfo + 1); // Tamaño del SID (sin incluir los dos primeros bytes)
  //uchar userSid[];
  //ArrayResize(userSid, userSidSize);
  //ArrayCopy(userSid, (uchar)tokenInfo + 2, 0, userSidSize);

  Print(result, " - ", tokenInfo, " - ", returnLength);
  */
}

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

string EncryptEA(string account = "", string type = "Testing", string name = "", int days = 30)
{
  if(account == "") account = (string)AccountInfoInteger(ACCOUNT_LOGIN);
  account = account + "," + type + "," + (string)(TimeCurrent() + (60 * 60 * 24 * days)) + "," + name;

  BCrypt.Init("D3B634B92BDBC9D80BC84ED4F2640644929A5E0DA153FD7D471AF9B5A416B5FE", base_secret_key, account);
  string encrypted_account = BCrypt.Encrypt();

  Print("NEW LICENSE KEY= ", encrypted_account);

  return encrypted_account;
}

bool DecryptEA()
{
  string license_privileges[];
  ushort u_sep = StringGetCharacter(",", 0);
  BCrypt.Init("D3B634B92BDBC9D80BC84ED4F2640644929A5E0DA153FD7D471AF9B5A416B5FE", base_secret_key);
  string decrypted_account = BCrypt.Decrypt(EA_License_Key);

  int license_ok = StringSplit(decrypted_account, u_sep, license_privileges);

  if(license_ok < 3) { Print("Could not Decrypt the current License."); return false; }

  current_account  = license_privileges[0];
  license_type     = license_privileges[1];
  license_expire   = (datetime)license_privileges[2];
  license_name     = license_privileges[3];

  //Print(current_account, " - ", license_type, " - ", license_expire, " - ", license_name, " - ", AllowDemo(), " - ", AllowLive());

  Print("LICENSE DECRYPTED= ", current_account);

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

bool VerifyLicense()
{
  if(current_account == AccountInfoString(ACCOUNT_NAME))
  {
    Print("VALID EA LICENSE!");
    return true;
  }

  if(current_account == (string)AccountInfoInteger(ACCOUNT_LOGIN))
  {
    Print("VALID EA LICENSE!");
    return true;
  }

  Print("LICENSE NAME/LOGIN DOES NOT MATCH WITH YOUR MT5 ACCOUNT, CONTACT SUPPORT.");

  return false;
}

bool VerifyLicenseType()
{
  ENUM_ACCOUNT_TRADE_MODE trade_mode = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);

  if(IsAdmin()) 																					 								return true;
  if(is_testing && CanBacktest()) 	   										 								return true;
  if(!is_testing && trade_mode == ACCOUNT_TRADE_MODE_DEMO && AllowDemo()) return true;
  if(!is_testing && trade_mode == ACCOUNT_TRADE_MODE_REAL && AllowLive()) return true;

  return false;
}

bool VerifyValidLicenseTime()
{
  if(IsAdmin()) 										 return true;
  if(is_testing && CanBacktest())    return true;
  if(license_expire > TimeCurrent()) return true;

  if(license_expire < TimeCurrent()) Print("LICENSE TIME HAS EXPIRED, CONTACT SUPPORT.");

  return false;
}

bool IsAdmin()
{
  if(StringFind(license_type, "Admin") >= 0) return true;
  //if(EA_License_Key == "SnVzdFByb2ZpdEZyYW1ld29yayB3aXRoIDwz") return true;

  return false;
}

bool CanBacktest()
{
  if(StringFind(license_type, "Testing") >= 0) return true;

  if(IsAdmin()) return true;

  Print("BACKTESTING IS NOT ALLOWED");

  return false;
}

bool AllowDemo()
{
  if(StringFind(license_type, "Demo") >= 0) return true;

  if(IsAdmin()) return true;

  Print("DEMO IS NOT ALLOWED");

  return false;
}

bool AllowLive()
{
  if(StringFind(license_type, "Live") >= 0) return true;

  if(IsAdmin()) return true;

  Print("LIVE IS NOT ALLOWED");

  return false;
}
