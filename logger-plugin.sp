#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <l4d2_direct>
#include <socket>

#define ENDCHECKDELAY 2.0
#define BUFFERSIZE 512

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
new Handle:hVsBossBuffer;

public OnPluginStart()
{
	HookEvent("door_close", DoorClose_Event);
	HookEvent("player_death", PlayerDeath_Event);
	HookEvent("player_incapacitated", PlayerIncap_Event);
	HookEvent("finale_vehicle_leaving", VehicleLeaving_Event);
	HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);

	hVsBossBuffer = FindConVar("versus_boss_buffer");

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
		decl String:message[BUFFERSIZE];
		new length = PrepMessage(message);

		SocketSend(gSocket, message, length);
		isRealRoundEnd = false;
	}
}

PrepMessage(String:message[BUFFERSIZE])
{
	decl String:configName[50];
	GetConVarString(FindConVar("l4d_ready_cfg_name"), configName, sizeof(configName));

	new aliveSurvs = GameRules_GetProp("m_iVersusSurvivalMultiplier", _, GameRules_GetProp("m_bAreTeamsFlipped"));

	new survCompletion[4] = { -1, ... };
	GetPerSurvFlows(survCompletion);

	new survHealth[4] = { -1, ... };
	GetPerSurvHealth(survHealth);

	new bossFlow[2] = { -1, ... };
	GetPerBossFlow(bossFlow);
	
	new offset;
	offset += 1 + strcopy(message[offset], sizeof(message) - offset, mapName); // string
	offset += 1 + strcopy(message[offset], sizeof(message) - offset, configName); // string
	offset += WriteToStringBuffer(message[offset], aliveSurvs); // 1 integer
	offset += WriteArrayToStringBuffer(message[offset], survCompletion, sizeof(survCompletion)); // 4 integers
	offset += WriteArrayToStringBuffer(message[offset], survHealth, sizeof(survHealth)); // 4 integers
	offset += WriteArrayToStringBuffer(message[offset], bossFlow, sizeof(bossFlow)); // 2 integers

	return offset;
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
	if (client && IsClientInGame(client) && IsSurvivor(client) && GetStandingSurvivorCount() == 0)
	{
		PrepRealRoundEnd();
	}
}

public Action:PlayerIncap_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client && IsClientInGame(client) && IsSurvivor(client) && GetStandingSurvivorCount() == 0)
	{
		PrepRealRoundEnd();
	}
}

public Action:VehicleLeaving_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrepRealRoundEnd();
}

stock GetPerSurvFlows(survFlows[4])
{
	new survCount = 0;
	new curTeam = GameRules_GetProp("m_bAreTeamsFlipped");

	for (new client = 1; client <= MaxClients && survCount < 4; client++)
	{
		if(IsClientInGame(client) && IsSurvivor(client))
		{
			survFlows[survCount] = GameRules_GetProp("m_iVersusDistancePerSurvivor", _, survCount + 4 * curTeam);
			survFlows[survCount] = survFlows[survCount] & 0xff; /* bug work around y'all! */
			survCount++;
		}
	}
}

stock GetStandingSurvivorCount()
{
	new survCount = 0;

	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsSurvivor(client) && IsPlayerAlive(client) && !IsIncapacitated(client)) survCount++;
	}
	return survCount;
}

stock GetPerSurvHealth(survHealth[4])
{
	new survCount = 0;
	for (new client = 1; client <= MaxClients && survCount < 4; client++)
	{
		if (IsClientInGame(client) && IsSurvivor(client))
		{
			if (IsPlayerAlive(client))
			{
				survHealth[survCount] = GetSurvivorPermanentHealth(client) + GetSurvivorTempHealth(client);
			}
			else
			{
				survHealth[survCount] = 0;
			}
			survCount++;
		}
	}
}

stock GetPerBossFlow(bossFlow[2])
{
	bossFlow[0] = RoundToNearest(100*(L4D2Direct_GetVSTankFlowPercent(0) - (Float:GetConVarInt(hVsBossBuffer) / L4D2Direct_GetMapMaxFlowDistance())));
	bossFlow[1] = RoundToNearest(100*(L4D2Direct_GetVSWitchFlowPercent(0) - (Float:GetConVarInt(hVsBossBuffer) / L4D2Direct_GetMapMaxFlowDistance())));
}

stock WriteToStringBuffer(String:str[], any:num)
{
	str[0] = (_:num >>  0) & 0xff;
	str[1] = (_:num >>  8) & 0xff;
	str[2] = (_:num >> 16) & 0xff;
	str[3] = (_:num >> 24) & 0xff;
	return 4;
}

stock WriteArrayToStringBuffer(String:buf[], any:array[], length)
{
	new bytesWritten;
	for (new i; i < length; i++)
	{
		WriteToStringBuffer(buf[bytesWritten], array[i]);
		bytesWritten += 4;
	}
	return bytesWritten;
}

stock bool:IsSurvivor(client) return GetClientTeam(client) == 2;
stock bool:IsIncapacitated(client) return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated");
stock GetSurvivorPermanentHealth(client) return GetEntProp(client, Prop_Send, "m_iHealth");
stock GetSurvivorTempHealth(client)
{
	new temphp = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(FindConVar("pain_pills_decay_rate")))) - 1;
	return (temphp > 0 ? temphp : 0);
}
