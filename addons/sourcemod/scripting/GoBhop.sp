#include <sourcemod>
#include <clientprefs>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <devzones>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
	name = "GoBhop", 
	author = "ByDexter", 
	description = "Ölü oyuncuların parkur yapmasını sağlar", 
	version = "1.0", 
	url = "https://steamcommunity.com/id/ByDexterTR - ByDexter#5494"
};

int g_PlayerResourceAlive = -1, GoZone[65] = { -1, ... };
bool CloseBhop = false, Block[65] = { false, ... }, GoBanned[65] = { false, ... };
Cookie goban = null;

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	
	goban = new Cookie("GoBhop-Ban", "", CookieAccess_Protected);
	RegAdminCmd("sm_goban", Command_goban, ADMFLAG_ROOT);
	RegAdminCmd("sm_gounban", Command_gounban, ADMFLAG_ROOT);
	
	RegConsoleCmd("sm_gobhop", Command_GoBhop);
	RegConsoleCmd("sm_nobhop", Command_nobhop);
	
	
	RegConsoleCmd("sm_r", Command_restart);
	RegConsoleCmd("sm_b", Command_bhopmenu);
	
	RegAdminCmd("sm_bhopiptal", Command_bhopiptal, ADMFLAG_BAN | ADMFLAG_RCON);
	RegAdminCmd("sm_bhopkov", Command_bhopkapat, ADMFLAG_BAN | ADMFLAG_RCON);
	
	//AddCommandListener(Block_Cmd, "sm_noclip");
	AddCommandListener(Block_Cmd, "sm_git");
	AddCommandListener(Block_Cmd, "sm_gel");
	AddCommandListener(Block_Cmd, "+hook");
	AddCommandListener(Block_Cmd, "+grab");
	AddCommandListener(Block_Cmd, "+rope");
	AddCommandListener(Block_Cmd, "hook_toggle");
	AddCommandListener(Block_Cmd, "grab_toggle");
	AddCommandListener(Block_Cmd, "rope_toggle");
	
	HookEvent("round_start", OnRound);
	HookEvent("round_end", OnRound);
	HookEvent("player_team", OnControl);
	HookEvent("player_death", OnControl);
	HookEvent("player_disconnect", OnControl, EventHookMode_Pre);
	HookEvent("player_death", OnClientDeadPre, EventHookMode_Pre);
	HookEvent("weapon_fire", WeaponFire);
	
	g_PlayerResourceAlive = FindSendPropInfo("CCSPlayerResource", "m_bAlive");
	
	HookEntityOutput("func_button", "OnDamaged", OnButton);
	HookEntityOutput("func_button", "OnPressed", OnButton);
	HookEntityOutput("func_button", "OnIn", OnButton);
	HookEntityOutput("func_button", "OnOut", OnButton);
	
	AddNormalSoundHook(SoundHook);
	
	for (int i = 1; i <= MaxClients; i++)if (IsValidClient(i))
	{
		OnClientPostAdminCheck(i);
	}
}

public Action OnButton(const char[] output, int caller, int activator, float delay)
{
	if (IsValidClient(activator) && GoZone[activator] != -1)
	{
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public Action Command_goban(int client, int args)
{
	char arg[256];
	GetCmdArgString(arg, 256);
	int Target = FindTarget(client, arg, true, true);
	if (!IsValidClient(Target) || Target == -1)
	{
		ReplyToCommand(client, "[SM] Geçersiz kullanıcı.");
		return Plugin_Handled;
	}
	
	if (GoZone[Target] != -1)
		ForcePlayerSuicide(Target);
	
	goban.Set(Target, "1");
	GoBanned[Target] = true;
	PrintToChatAll("[SM] \x10%N, \x10%N \x01tarafından \x0EGoBhop'tan banladı.", Target, client);
	return Plugin_Handled;
}

public Action Command_gounban(int client, int args)
{
	char arg[256];
	GetCmdArgString(arg, 256);
	int Target = FindTarget(client, arg, true, true);
	if (!IsValidClient(Target) || Target == -1)
	{
		ReplyToCommand(client, "[SM] Geçersiz kullanıcı.");
		return Plugin_Handled;
	}
	
	goban.Set(Target, "0");
	GoBanned[Target] = false;
	PrintToChatAll("[SM] \x10%N, \x10%N \x01tarafından \x0EGoBhop'tan banı kaldırıldı.", Target, client);
	return Plugin_Handled;
}

public Action Block_Cmd(int client, const char[] command, int argc)
{
	if (GoZone[client] != -1)
	{
		PrintToChat(client, "[SM] GoBhopta bu komutu \x02kullanamazsın.");
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public Action Command_restart(int client, int args)
{
	if (!IsPlayerAlive(client) || GoZone[client] == -1)
	{
		ReplyToCommand(client, "[SM] Bu komutu sadece GoBhop'ta kullanabilirsin.");
		return Plugin_Handled;
	}
	
	if (GetEntityMoveType(client) == MOVETYPE_NONE)
	{
		ServerCommand("sm_freeze #%d 1", GetClientUserId(client));
		return Plugin_Handled;
	}
	else
	{
		CS_RespawnPlayer(client);
		SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
		SetEntProp(client, Prop_Data, "m_CollisionGroup", 2);
		StripAllWeapons(client);
		float Position[3];
		char zonename[8];
		Format(zonename, 8, "bhop%d", GoZone[client]);
		Zone_GetZonePosition(zonename, false, Position);
		TeleportEntity(client, Position, NULL_VECTOR, NULL_VECTOR);
		return Plugin_Handled;
	}
}

public Action Command_bhopmenu(int client, int args)
{
	if (!IsPlayerAlive(client) || GoZone[client] == -1)
	{
		ReplyToCommand(client, "[SM] Bu komutu sadece GoBhop'ta kullanabilirsin.");
		return Plugin_Handled;
	}
	
	Panel panel = new Panel();
	panel.SetTitle("★ GoBhop - Nereye Gitmek İstersin?\n ");
	if (Zone_CheckIfZoneExists("bhop1") && Zone_CheckIfZoneExists("bhopz1"))
		panel.DrawItem("➔ Bhop | 1");
	else
		panel.DrawItem("➔ Bhop | 1 [ Ayarlanmamış ]", ITEMDRAW_DISABLED);
	
	if (Zone_CheckIfZoneExists("bhop2") && Zone_CheckIfZoneExists("bhopz2"))
		panel.DrawItem("➔ Bhop | 2");
	else
		panel.DrawItem("➔ Bhop | 2 [ Ayarlanmamış ]", ITEMDRAW_DISABLED);
	
	if (Zone_CheckIfZoneExists("bhop3") && Zone_CheckIfZoneExists("bhopz3"))
		panel.DrawItem("➔ Bhop | 3");
	else
		panel.DrawItem("➔ Bhop | 3 [ Ayarlanmamış ]", ITEMDRAW_DISABLED);
	
	if (Zone_CheckIfZoneExists("bhop4") && Zone_CheckIfZoneExists("bhopz4"))
		panel.DrawItem("➔ Bhop | 4");
	else
		panel.DrawItem("➔ Bhop | 4 [ Ayarlanmamış ]", ITEMDRAW_DISABLED);
	
	if (Zone_CheckIfZoneExists("bhop5") && Zone_CheckIfZoneExists("bhopz5"))
		panel.DrawItem("➔ Bhop | 5");
	else
		panel.DrawItem("➔ Bhop | 5 [ Ayarlanmamış ]", ITEMDRAW_DISABLED);
	
	if (Zone_CheckIfZoneExists("bhop6") && Zone_CheckIfZoneExists("bhopz6"))
		panel.DrawItem("➔ Bhop | 6");
	else
		panel.DrawItem("➔ Bhop | 6 [ Ayarlanmamış ]", ITEMDRAW_DISABLED);
	
	if (Zone_CheckIfZoneExists("bhop7") && Zone_CheckIfZoneExists("bhopz7"))
		panel.DrawItem("➔ Bhop | 7");
	else
		panel.DrawItem("➔ Bhop | 7 [ Ayarlanmamış ]", ITEMDRAW_DISABLED);
	
	if (Zone_CheckIfZoneExists("bhop8") && Zone_CheckIfZoneExists("bhopz8"))
		panel.DrawItem("➔ Bhop | 8\n ");
	else
		panel.DrawItem("➔ Bhop | 8 [ Ayarlanmamış ]\n ", ITEMDRAW_DISABLED);
	
	panel.DrawItem("➔ Kapat");
	panel.Send(client, Panel_CallBack2, 10);
	delete panel;
	return Plugin_Handled;
}

public int Panel_CallBack2(Menu panel, MenuAction action, int client, int position)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (GoZone[client] != -1)
			{
				if (position != 9)
				{
					char zonename[8];
					Format(zonename, 8, "bhop%d", position);
					float Pos[3];
					Zone_GetZonePosition(zonename, false, Pos);
					GoZone[client] = position;
					TeleportEntity(client, Pos, NULL_VECTOR, NULL_VECTOR);
				}
			}
		}
	}
}

public Action Command_GoBhop(int client, int args)
{
	if (GoBanned[client])
	{
		ReplyToCommand(client, "[SM] \x04GoBhop\x01'tan yasaklanmışsın.");
		return Plugin_Handled;
	}
	if (CloseBhop)
	{
		ReplyToCommand(client, "[SM] \x04GoBhop\x01 kapalı şuan.");
		return Plugin_Handled;
	}
	if (Block[client])
	{
		ReplyToCommand(client, "[SM] Bu komutu kullanmak için biraz beklemelisin.");
		return Plugin_Handled;
	}
	if (GoZone[client] != -1)
	{
		ReplyToCommand(client, "[SM] GoBhop'tasın zaten bölge değişmek için \x10!b\x01 yaz.");
		return Plugin_Handled;
	}
	if (IsPlayerAlive(client))
	{
		ReplyToCommand(client, "[SM] Canlı oyuncular GoBhop'a gidemez.");
		return Plugin_Handled;
	}
	if (GetClientTeam(client) != 2)
	{
		ReplyToCommand(client, "[SM] GoBhop'a sadece teröristler gider.");
		return Plugin_Handled;
	}
	
	Panel panel = new Panel();
	panel.SetTitle("★ GoBhop - Nereye Gitmek İstersin?\n ");
	
	if (Zone_CheckIfZoneExists("bhop1") && Zone_CheckIfZoneExists("bhopz1"))
		panel.DrawItem("➔ Bhop | 1");
	else
		panel.DrawItem("➔ Bhop | 1 [ Ayarlanmamış ]", ITEMDRAW_DISABLED);
	
	if (Zone_CheckIfZoneExists("bhop2") && Zone_CheckIfZoneExists("bhopz2"))
		panel.DrawItem("➔ Bhop | 2");
	else
		panel.DrawItem("➔ Bhop | 2 [ Ayarlanmamış ]", ITEMDRAW_DISABLED);
	
	if (Zone_CheckIfZoneExists("bhop3") && Zone_CheckIfZoneExists("bhopz3"))
		panel.DrawItem("➔ Bhop | 3");
	else
		panel.DrawItem("➔ Bhop | 3 [ Ayarlanmamış ]", ITEMDRAW_DISABLED);
	
	if (Zone_CheckIfZoneExists("bhop4") && Zone_CheckIfZoneExists("bhopz4"))
		panel.DrawItem("➔ Bhop | 4");
	else
		panel.DrawItem("➔ Bhop | 4 [ Ayarlanmamış ]", ITEMDRAW_DISABLED);
	
	if (Zone_CheckIfZoneExists("bhop5") && Zone_CheckIfZoneExists("bhopz5"))
		panel.DrawItem("➔ Bhop | 5");
	else
		panel.DrawItem("➔ Bhop | 5 [ Ayarlanmamış ]", ITEMDRAW_DISABLED);
	
	if (Zone_CheckIfZoneExists("bhop6") && Zone_CheckIfZoneExists("bhopz6"))
		panel.DrawItem("➔ Bhop | 6");
	else
		panel.DrawItem("➔ Bhop | 6 [ Ayarlanmamış ]", ITEMDRAW_DISABLED);
	
	if (Zone_CheckIfZoneExists("bhop7") && Zone_CheckIfZoneExists("bhopz7"))
		panel.DrawItem("➔ Bhop | 7");
	else
		panel.DrawItem("➔ Bhop | 7 [ Ayarlanmamış ]", ITEMDRAW_DISABLED);
	
	if (Zone_CheckIfZoneExists("bhop8") && Zone_CheckIfZoneExists("bhopz8"))
		panel.DrawItem("➔ Bhop | 8\n ");
	else
		panel.DrawItem("➔ Bhop | 8 [ Ayarlanmamış ]\n ", ITEMDRAW_DISABLED);
	
	panel.DrawItem("➔ Kapat");
	panel.Send(client, Panel_CallBack, 20);
	delete panel;
	return Plugin_Handled;
}

public int Panel_CallBack(Menu panel, MenuAction action, int client, int position)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!CloseBhop && !IsPlayerAlive(client) && !GoBanned[client] && GoZone[client] == -1 && GetClientTeam(client) == 2 && !Block[client])
			{
				if (position != 9)
				{
					Block[client] = true;
					CreateTimer(5.0, BlockKaldir, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
					GoZone[client] = position;
					SDKHook(client, SDKHook_PostThink, Hook_Think);
					SDKHook(client, SDKHook_WeaponDropPost, OnWeaponDrop);
					SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
					CreateTimer(1.5, Timer_RespawnOnDG, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
					PrintToChat(client, "[SM] Bölge hazırlanıyor, lütfen bekleyin...");
				}
			}
		}
	}
}

public Action Timer_RespawnOnDG(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!CloseBhop && IsValidClient(client) && GetClientTeam(client) == 2 && GoZone[client] != -1 && !IsPlayerAlive(client))
	{
		PrintToChat(client, " ");
		PrintToChat(client, " \x04__________________");
		PrintToChat(client, " \x0CGoBhop Komutları:");
		PrintToChat(client, " ");
		PrintToChat(client, " \x10!nobhop \x01: GoBhoptan ayrılmak için.");
		PrintToChat(client, " \x10!r \x01: Hareket edemiyorken veya başa dönmek için.");
		PrintToChat(client, " \x10!b \x01: Diğer bhoplara gitmek için.");
		PrintToChat(client, " ");
		PrintToChat(client, " \x04￣￣￣￣￣￣￣￣￣￣");
		CS_RespawnPlayer(client);
		SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
		SetEntProp(client, Prop_Data, "m_CollisionGroup", 2);
		StripAllWeapons(client);
		float Position[3];
		char zonename[8];
		Format(zonename, 8, "bhop%d", GoZone[client]);
		Zone_GetZonePosition(zonename, false, Position);
		TeleportEntity(client, Position, NULL_VECTOR, NULL_VECTOR);
	}
	return Plugin_Stop;
}

public void Zone_OnClientEntry(int client, const char[] zone)
{
	if (!CloseBhop && IsValidClient(client) && GoZone[client] != -1 && strcmp(zone, "nobhop", false) == 0)
	{
		float Position[3];
		char zonename[8];
		Format(zonename, 8, "bhop%d", GoZone[client]);
		Zone_GetZonePosition(zonename, false, Position);
		TeleportEntity(client, Position, NULL_VECTOR, NULL_VECTOR);
	}
}

public void Zone_OnClientLeave(int client, const char[] zone)
{
	if (!CloseBhop && IsValidClient(client) && GoZone[client] != -1)
	{
		char zonename[8];
		Format(zonename, 8, "bhopz%d", GoZone[client]);
		if (strcmp(zone, zonename, false) == 0)
		{
			Format(zonename, 8, "bhop%d", GoZone[client]);
			float Position[3];
			Zone_GetZonePosition(zonename, false, Position);
			TeleportEntity(client, Position, NULL_VECTOR, NULL_VECTOR);
		}
	}
}

public Action Command_nobhop(int client, int args)
{
	if (GoZone[client] == -1)
	{
		ReplyToCommand(client, "[SM] Zaten GoBhop'ta değilsin.");
		return Plugin_Handled;
	}
	if (Block[client])
	{
		ReplyToCommand(client, "[SM] Bu komutu kullanmak için biraz beklemelisin.");
		return Plugin_Handled;
	}
	
	Block[client] = true;
	CreateTimer(5.0, BlockKaldir, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	SafeKill(client);
	return Plugin_Handled;
}

public Action Command_bhopkapat(int client, int args)
{
	int olddeaths = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && GoZone[i] != -1)
		{
			GoZone[i] = -1;
			SetEntProp(i, Prop_Data, "m_takedamage", 2, 1);
			ForcePlayerSuicide(i);
			SetEntProp(i, Prop_Data, "m_iFrags", GetClientFrags(i) + 1);
			olddeaths = GetEntProp(i, Prop_Data, "m_iDeaths");
			SetEntProp(i, Prop_Data, "m_iDeaths", olddeaths - 1);
		}
	}
	PrintToChatAll("[SM] \x10%N\x01 herkesi \x06GoBhop\x01'tan kovdu", client);
	return Plugin_Handled;
}


public Action Command_bhopiptal(int client, int args)
{
	CloseBhop = !CloseBhop;
	PrintToChatAll("[SM] \x10%N\x01 GoBhop'u %s", client, CloseBhop ? "\x07kapattı!":"\x04açtı!");
	if (CloseBhop)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && GoZone[i] != -1)
			{
				SafeKill(i);
			}
		}
	}
	return Plugin_Handled;
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && GoZone[i] != -1)
		{
			SafeKill(i);
		}
	}
}

public void OnMapStart()
{
	char mapname[256];
	GetCurrentMap(mapname, 256);
	if (strncmp(mapname, "jb_", 3, false) == -1 && strncmp(mapname, "ba_", 3, false) == -1 && strncmp(mapname, "jail_", 5, false) == -1)
	{
		char filename[256];
		GetPluginFilename(INVALID_HANDLE, filename, 256);
		ServerCommand("sm plugins unload %s.smx", filename);
	}
	int entity = FindEntityByClassname(0, "cs_player_manager");
	SDKHook(entity, SDKHook_ThinkPost, OnPlayerManager_ThinkPost);
}

public Action BlockKaldir(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (IsValidClient(client))
	{
		Block[client] = false;
	}
}

public Action OnPlayerManager_ThinkPost(int entity)
{
	for (int i = 1; i <= MaxClients; i++)if (IsValidClient(i))
	{
		if (GoZone[i] != -1)
			SetEntData(entity, (g_PlayerResourceAlive + i * 4), 0, 1, true);
	}
}

public void OnClientPostAdminCheck(int client)
{
	Block[client] = false;
	GoZone[client] = -1;
	SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmit);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	
	char sBuffer[4];
	goban.Get(client, sBuffer, 4);
	if (StringToInt(sBuffer) == 1)
	{
		GoBanned[client] = true;
	}
	else
	{
		goban.Set(client, "0");
		GoBanned[client] = false;
	}
}

public Action OnWeaponDrop(int client, int entity)
{
	if (IsValidClient(client) && GoZone[client] != -1)
	{
		if (IsValidEntity(entity))
			RemoveEntity(entity);
		if (IsValidEdict(entity))
			RemoveEdict(entity);
	}
	else
	{
		SDKUnhook(client, SDKHook_WeaponDropPost, OnWeaponDrop);
	}
}

public Action OnWeaponCanUse(int client, int weapon)
{
	if (IsValidClient(client) && GoZone[client] != -1)
	{
		return Plugin_Handled;
	}
	else
	{
		SDKUnhook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
		return Plugin_Continue;
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if ((IsValidClient(attacker) && GoZone[attacker] != -1) || (IsValidClient(victim) && GoZone[victim] != -1))
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (IsValidClient(client) && GoZone[client] != -1)
	{
		buttons &= ~IN_ATTACK;
		buttons &= ~IN_ATTACK2;
		buttons &= ~IN_ATTACK3;
	}
	return Plugin_Continue;
}

public Action Hook_Think(int client)
{
	if (GoZone[client] != -1)
	{
		if (IsPlayerAlive(client) && GetEntityFlags(client) & FL_ONGROUND)
		{
			int flags = GetEntityFlags(client);
			SetEntityFlags(client, flags & ~FL_ONGROUND);
		}
	}
	else SDKUnhook(client, SDKHook_PostThink, Hook_Think);
}

public Action Hook_SetTransmit(int entity, int client)
{
	if (entity == client)return Plugin_Continue;
	
	if (!IsValidClient(entity))
	{
		SDKUnhook(entity, SDKHook_SetTransmit, Hook_SetTransmit);
		return Plugin_Continue;
	}
	
	if (GoZone[client] != GoZone[entity])
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if (IsValidClient(client) && GoZone[client] != -1)
	{
		ReplyToCommand(client, "[SM] \x06GoBhop\x01'ta yazı \x0Fyazamazsın.");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action SoundHook(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (IsValidClient(entity) && GoZone[entity] != -1)
	{
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public void SafeKill(int client)
{
	GoZone[client] = -1;
	if (IsPlayerAlive(client))
	{
		SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
		ForcePlayerSuicide(client);
		SetEntProp(client, Prop_Data, "m_iFrags", GetClientFrags(client) + 1);
		int olddeaths = GetEntProp(client, Prop_Data, "m_iDeaths");
		SetEntProp(client, Prop_Data, "m_iDeaths", olddeaths - 1);
	}
}

bool IsValidClient(int client, bool nobots = false)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false;
	}
	return IsClientInGame(client);
}

void StripAllWeapons(int client)
{
	int wepIdx;
	for (int i; i <= 13; i++)
	{
		while ((wepIdx = GetPlayerWeaponSlot(client, i)) != -1)
		{
			RemovePlayerItem(client, wepIdx);
			RemoveEntity(wepIdx);
		}
	}
}

public Action WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(client) && GoZone[client] != -1)
	{
		StripAllWeapons(client);
	}
}

public Action OnRound(Event event, const char[] name, bool dontBroadcast)
{
	if (strcmp(name, "round_end") == 0)
		CloseBhop = true;
	else
		CloseBhop = false;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && GoZone[i] != -1)
		{
			SafeKill(i);
		}
	}
}

public Action OnControl(Event event, const char[] name, bool dontBroadcast)
{
	KontrolEt();
}

public Action OnClientDeadPre(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(client) && GoZone[client] != -1)
	{
		Block[client] = true;
		CreateTimer(5.0, BlockKaldir, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		SafeKill(client);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

void KontrolEt()
{
	int T = 0;
	int CT = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsPlayerAlive(i) && GoZone[i] == -1)
		{
			if (GetClientTeam(i) == 2)
				T++;
			else if (GetClientTeam(i) == 3)
				CT++;
		}
	}
	if (T <= 2 || CT <= 0)
	{
		CloseBhop = true;
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && GoZone[i] != -1)
			{
				SafeKill(i);
			}
		}
	}
} 