#include <sourcemod>
#include <sdktools>
#include <geoip>
#include <clientprefs>
#include <multicolors>
#include <smlib/strings>

#include "include/globals"
#include "include/client"

#pragma newdecls required
#pragma semicolon 1

#define LoopClients(%1) for(int %1 = 1;%1 <= MaxClients;%1++) if(IsValidClient(%1))

#if (!defined MAX_AUTHID_LENGTH)
#define MAX_AUTHID_LENGTH 64 /**< Maximum buffer required to store any AuthID type */
#endif // !MAX_AUTHID_LENGTH

#include "include/misc"

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	version = PLUGIN_VERSION,
	author = PLUGIN_AUTHOR,
	description = "Server Advertisement",
	url = "https://forums.alliedmods.net/showthread.php?t=248314"
};

StringMap gGreetedAuthIds;

public void OnPluginStart()
{
	AutoExecConfig(true, "ServerAdvertisements");

	RegAdminCmd("sm_SAr", Command_SAr, ADMFLAG_ROOT, "Message reload");

	RegConsoleCmd("sm_SAlang", Command_ChangeLanguage);

	BuildPath(Path_SM, sConfigPath, sizeof(sConfigPath), "configs/ServerAdvertisements.cfg");

	g_cV_Enabled = CreateConVar("sm_SA_enable", "1", "Enable/Disable ServerAdvertisements");
	g_b_Enabled = g_cV_Enabled.BoolValue;
	g_cV_Enabled.AddChangeHook(OnConVarChanged);

	SetCookieMenuItem(CookieHandler, 0, "Server Advertisements Settings");

	g_hSACustomLanguage = RegClientCookie("SA_customlanguage", "Custom language for SA", CookieAccess_Private);

	gLanguages = new StringMap();
	gMessageGroups = new StringMap();
	gGreetedAuthIds = new StringMap();

	HookEvent("player_disconnect", OnPlayerDisconnect);
}

public void OnMapStart()
{
	char sTempMap[PLATFORM_MAX_PATH];
	GetCurrentMap(sTempMap, sizeof(sTempMap));
	GetMapDisplayName(sTempMap, sMapName,sizeof(sMapName));
	LoadConfig();
}

void ClearMessageEntry(SMessageEntry message)
{
	delete message.mTextByLanguage;
	delete message.mHUDParams;
}

public void OnMapEnd()
{
	StringMapSnapshot periods = gMessageGroups.Snapshot();

	for (int i; i < periods.Length; ++i)
	{
		char period[32];
		periods.GetKey(i, period, sizeof(period));
		SMessageGroup group;
		gMessageGroups.GetArray(period, group, sizeof(group));
		KillTimer(group.mhTimer);

		for (int j; j < group.mMessages.Length; ++j)
		{
			SMessageEntry message;
			group.mMessages.GetArray(j, message, sizeof(message));
			ClearMessageEntry(message);
		}

		delete group.mMessages;
	}

	delete periods;

	delete gMessageGroups;
	gMessageGroups = new StringMap();

	delete gGreetedAuthIds;
	gGreetedAuthIds = new StringMap();
}

public void OnClientPostAdminCheck(int client)
{
	if (IsValidClient(client))
	{
		if (gWelcomeMessage.mTextByLanguage != null)
		{
			char authId[MAX_AUTHID_LENGTH];
			GetClientAuthId(client, AuthId_Engine, authId, sizeof(authId));

			if (gWelcomeMessage.HasAccess(client) && gGreetedAuthIds.SetValue(authId, true, false))
			{
				CreateTimer(g_fWM_Delay, Timer_WelcomeMessage, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
}

public void OnPlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (client > 0)
	{
		char authId[MAX_AUTHID_LENGTH];
		GetClientAuthId(client, AuthId_Engine, authId, sizeof(authId));
		gGreetedAuthIds.Remove(authId);
	}
}

public Action Command_ChangeLanguage(int client, int args)
{
	if (IsValidClient(client))
	{
		CreateServerAdvertMenu(client);
	}
	return Plugin_Handled;
}

public void CookieHandler(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	switch (action)
	{
		case CookieMenuAction_SelectOption:
		{
			CreateServerAdvertMenu(client);
		}
	}
}

public void CreateServerAdvertMenu(int client)
{
	CreateLanguageMenu(client, ServerAdvertSettingHandler, "[SA] Choose your language");
}

void CreateLanguageMenu(int client, MenuHandler handler, const char[] titleFormat)
{
	char sTempLang[12], sTempLangSelected[12], sBuffer[64];
	SA_GetInGameLanguage(client, sTempLang, sizeof(sTempLang));
	GetClientCookie(client, g_hSACustomLanguage, sTempLangSelected, sizeof(sTempLangSelected));
	String_ToLower(sTempLangSelected, sTempLangSelected, sizeof(sTempLangSelected));

	Menu menu = new Menu(handler, MENU_ACTIONS_ALL);
	menu.SetTitle(titleFormat, SA);

	FormatEx(sBuffer, sizeof(sBuffer), "By IP %s", StrEqual(sTempLangSelected, "geoip", false) ? "[*]" : NULL_STRING);
	menu.AddItem("geoip", sBuffer, StrEqual(sTempLangSelected, "geoip", false) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

	FormatEx(sBuffer, sizeof(sBuffer), "By game (%s) %s", sTempLang, StrEqual(sTempLangSelected, "ingame", false) ? "[*]" : NULL_STRING);
	menu.AddItem("ingame", sBuffer, StrEqual(sTempLangSelected, "ingame", false) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

	bool clientLangExists;
	if (gLanguages.GetValue(sTempLangSelected, clientLangExists))
	{
		gLanguages.Remove(sTempLangSelected);
		AddLanguageMenuItem(menu, sTempLangSelected, " [*]", ITEMDRAW_DISABLED);
	}

	StringMapSnapshot languages = gLanguages.Snapshot();
	for (int i = 0; i < languages.Length; ++i)
	{
		languages.GetKey(i, sTempLang, sizeof(sTempLang));
		AddLanguageMenuItem(menu, sTempLang, NULL_STRING, ITEMDRAW_DEFAULT);
	}

	if (clientLangExists)
	{
		gLanguages.SetValue(sTempLangSelected, true);
	}

	delete languages;
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void AddLanguageMenuItem(Menu menu, const char[] code, const char[] extra, int flags)
{
	char item[64];
	int index = GetLanguageByCode(code), len;

	if (index > -1)
	{
		GetLanguageInfo(index, "", 0, item, sizeof(item));
		item[0] = CharToUpper(item[0]);
	}
	else
	{
		len = strcopy(item, sizeof(item), code);
	}

	StrCat(item[len], sizeof(item) - len, extra);
	menu.AddItem(code, item, flags);
}

public int ServerAdvertSettingHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!IsValidClient(param1))
				return 0;

			char info[64];
			menu.GetItem(param2, info, sizeof(info));
			SetClientCookie(param1, g_hSACustomLanguage, info);

			CreateServerAdvertMenu(param1);
		}
		case MenuAction_Cancel:
			ShowCookieMenu(param1);
		case MenuAction_End:
			delete menu;
	}
	return 0;
}


public Action Timer_WelcomeMessage(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	if (IsValidClient(client))
	{
		PrintMessageEntry(client, gWelcomeMessage, true);
	}

	return Plugin_Stop;
}

public void OnConVarChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	if(cvar == g_cV_Enabled)
	{
		g_b_Enabled = view_as<bool>(StringToInt(newValue));

		if(g_b_Enabled)
		{
			LoadMessages();
		}
	}
}

public Action Command_SAr(int client, int args)
{
	LoadMessages();
	LogAction(-1, -1, "\"%L\" reloaded all messages from %s.", client, PLUGIN_NAME);
	CReplyToCommand(client, "{green}%s {default}Messages reloaded", SA);
	return Plugin_Handled;
}

public void LoadConfig()
{
	delete gLanguages;
	gLanguages = new StringMap();

	ClearMessageEntry(gWelcomeMessage);
	gWelcomeMessage.mTextByLanguage = null;
	gWelcomeMessage.mHUDParams = null;
	KeyValues kvConfig = new KeyValues("ServerAdvertisements");

	if (!kvConfig.ImportFromFile(sConfigPath))
	{
		delete kvConfig;
		SetFailState("%s Unable to find or load %s", SA, sConfigPath);
	}

	if(kvConfig.JumpToKey("Settings"))
	{
		kvConfig.GetString("ServerName", sServerName, sizeof(sServerName), "[ServerAdvertisements]");
		fTime = kvConfig.GetFloat("Time", 30.0);
		gRandomize = view_as<bool>(kvConfig.GetNum("Random"));
		char sLanguages[64], sLanguageList[64][12];
		kvConfig.GetString("Languages", sLanguages, sizeof(sLanguages));
		kvConfig.GetString("Default language", sDefaultLanguage, sizeof(sDefaultLanguage), "geoip");
		bExpiredMessagesDebug = view_as<bool>(kvConfig.GetNum("Log expired messages", 0));

		for (int i = ExplodeString(sLanguages, ";", sLanguageList, sizeof(sLanguageList), sizeof(sLanguageList[]));
			--i >= 0;)
		{
			String_ToLower(sLanguageList[i], sLanguageList[i], sizeof(sLanguageList[]));
			gLanguages.SetValue(sLanguageList[i], true);
		}

		if (gLanguages.Size < 1)
		{
			delete kvConfig;
			SetFailState("%s No language found! Please set languages in 'Settings' part in %s", SA, sConfigPath);
		}

		LoadMessages();
		kvConfig.GoBack();
	}
	else
	{
		delete kvConfig;
		SetFailState("%s Unable to find Settings in %s", SA, sConfigPath);
	}
	if(kvConfig.JumpToKey("Welcome Message"))
	{
		if (kvConfig.GetNum("Enabled", 1))
		{
			g_fWM_Delay = kvConfig.GetFloat("Delay", 5.0);
			AddMessagesToEntry(kvConfig, gWelcomeMessage);	
		}
	}

	delete kvConfig;
}

public void LoadMessages()
{
	OnMapEnd();
	KeyValues kvMessages = new KeyValues("ServerAdvertisements");

	if (!kvMessages.ImportFromFile(sConfigPath))
	{
		delete kvMessages;
		SetFailState("%s Unable to find or load %s", SA, sConfigPath);
	}

	if(kvMessages.JumpToKey("Messages"))
	{
		if (kvMessages.GotoFirstSubKey())
		{
			do
			{
				AddMessagesToArray(kvMessages);
			}
			while (kvMessages.GotoNextKey());
		}
	}
	else
	{
		delete kvMessages;
		SetFailState("%s Unable to find Messages in %s", SA, sConfigPath);
	}

	delete kvMessages;
}

public Action Timer_PrintMessage(Handle timer, float period)
{
	char periodBuf[32];
	FormatEx(periodBuf, sizeof(periodBuf), "%.2f", period);
	SMessageGroup group;
	gMessageGroups.GetArray(periodBuf, group, sizeof(group));
	int next;

	if (gRandomize)
	{
		next = GetRandomInt(0, group.mMessages.Length - 1);
	}
	else
	{
		next = group.mNextMsgIndex %= group.mMessages.Length;
		++group.mNextMsgIndex;
		gMessageGroups.SetArray(periodBuf, group, sizeof(group));
	}

	SMessageEntry message;
	group.mMessages.GetArray(next, message, sizeof(message));

	LoopClients(i)
	{
		if (message.HasAccess(i))
		{
			PrintMessageEntry(i, message, false);
		}
	}

	return Plugin_Continue;
}