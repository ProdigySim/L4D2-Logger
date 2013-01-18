#pragma semicolon 1

#include <sourcemod>
#include <socket>

#define ENDCHECKDELAY 2.0

public Plugin:myinfo =
{
	name = "L4D2 Logger",
	author = "CanadaRox",
	description = "A plugin that logs the number of survivors that survive to a central server.  Collects map name, config name, and number of survivors that survived.",
	version = "1",
	url = "https://github.com/CanadaRox/L4D2-Logger"
}

new bool:isRealRoundEnd = false;
new String:mapName[64];
new Handle:gSocket;

public OnPluginStart()
{
	HookEvent("door_close", DoorClose_Event);
	HookEvent("player_death", PlayerDeath_Event);
	HookEvent("player_incapacitated", PlayerIncap_Event);
	HookEvent("finale_vehicle_leaving", VehicleLeaving_Event);
	HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);

	gSocket = SocketCreate(SOCKET_UDP, OnSocketError);
	SocketConnect(gSocket, OnSocketConnect, OnSocketRecv, OnSocketDisconnect, "bonerbox.canadarox.com", 55555);
}

public OnMapStart()
{
	GetCurrentMap(mapName, sizeof(mapName));
}

PrepRealRoundEnd()
{
	isRealRoundEnd = true;
	CreateTimer(ENDCHECKDELAY, PossibleEndTimer, TIMER_FLAG_NO_MAPCHANGE);
}

public OnSocketError(Handle:socket, const errorType, const errorNum, any:arg)
{
	LogError("[L4D2 Logger] errorType: %d, errorNum: %d", errorType, errorNum);
}

public OnSocketConnect(Handle:socket, any:arg) { }
public OnSocketRecv(Handle:socket, const String:recvData[], const dataSize, any:arg) { }
public OnSocketDisconnect(Handle:socket, any:arg) { }

public Action:PossibleEndTimer(Handle:timer)
{
	isRealRoundEnd = false;
}

public Action:RoundEnd_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (isRealRoundEnd && GetConVarBool(FindConVar("l4d_ready_enabled")))
	{
		new String:message[100], String:configName[50];
		GetConVarString(FindConVar("l4d_ready_cfg_name"), configName, sizeof(configName));
		Format(message, sizeof(message), "%s,%s,%d", mapName, configName, GetSurvivorCount());
		SocketSend(gSocket, message, -1);
	}
}

public Action:DoorClose_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetEventBool(event, "checkpoint"))
	{
		PrepRealRoundEnd();
	}
}

public Action:PlayerDeath_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client && IsSurvivor(client) && GetSurvivorCount() == 0)
	{
		PrepRealRoundEnd();
	}
}

public Action:PlayerIncap_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client && IsSurvivor(client) && GetSurvivorCount() == 0)
	{
		PrepRealRoundEnd();
	}
}

public Action:VehicleLeaving_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrepRealRoundEnd();
}

stock IsSurvivor(client)
{
	return IsClientInGame(client) && GetClientTeam(client) == 2;
}

stock GetSurvivorCount()
{
	new survCount = 0;

	for (new i = 1; i < MaxClients; i++)
	{
		if (IsSurvivor(i)) survCount++;
	}
	return survCount;
}
