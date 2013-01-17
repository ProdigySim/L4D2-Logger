#pragma semicolon 1

#include <sourcemod>
#include <socket>

public Plugin:myinfo =
{
	name = "L4D2 Logger",
	author = "CanadaRox",
	description = "A plugin that logs the number of survivors that survive to a central server.  Collects map name, config name, and number of survivors that survived.",
	version = "1-A",
	url = ""
}

new bool:isRealRoundEnd = false;
new String:mapName[64];

public OnPluginStart()
{
	HookEvent("door_close", DoorClose_Event);
	HookEvent("player_death", PlayerDeath_Event);
	HookEvent("finale_vehicle_leaving", VehicleLeaving_Event);
	HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);
}

public OnMapStart()
{
	GetCurrentMap(mapName, sizeof(mapName));
}

RealRoundEnd()
{
	isRealRoundEnd = true;
	CreateTimer(0.5, PossibleEndTimer, TIMER_FLAG_NO_MAPCHANGE);
}

public OnSocketError(Handle:socket, const errorType, const errorNum, any:arg)
{
	LogError("[L4D2 Logger] errorType: %d, errorNum: %d", errorType, errorNum);
}

public Action:PossibleEndTimer(Handle:timer)
{
	isRealRoundEnd = false;
}

public Action:RoundEnd_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (isRealRoundEnd && GetConVarBool(FindConVar("l4d_ready_enable")))
	{
		new Handle:socket = SocketCreate(SOCKET_UDP, OnSocketError);
		new String:message[100], String:configName[50];
		GetConVarString(FindConVar("l4d_ready_cfg_name"), configName, sizeof(configName));
		Format(message, sizeof(message), "%s,%s,%d", mapName, configName, GetSurvivorCount());
		SocketSendTo(socket, message, -1, "bonerbox.canadarox.com", 55555);
	}
}

public Action:DoorClose_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetEventBool(event, "checkpoint"))
	{
		RealRoundEnd();
	}
}

public Action:PlayerDeath_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsClientInGame(client) && IsSurvivor(client) && GetSurvivorCount() == 0)
	{
		RealRoundEnd();
	}

}

public Action:VehicleLeaving_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	RealRoundEnd();
}

stock IsSurvivor(client)
{
	return IsClientInGame(client) && GetClientTeam(client) == 2;
}

stock GetSurvivorCount()
{
	new survCount = 0;

	for (new i = 0; i < MaxClients; i++)
	{
		if (IsSurvivor(i)) survCount++;
	}
	return survCount;
}
