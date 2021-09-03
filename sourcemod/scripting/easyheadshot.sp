#include <sourcemod>
#include <cstrike>
#include <dhooks>

bool g_bIsEnabled[MAXPLAYERS + 1];
Handle DHOOK_TraceAttack;

#define PLUGIN_NAME "Easy Headshot"
 
public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "ely",
	description = "Every shot is a headshot",
	version = "1.1",
	url = ""
};
 
public void OnPluginStart() 
{ 
	PrintToServer("%s plugin started.", PLUGIN_NAME);
	Handle gamedata = LoadGameConfigFile("sdkhooks.games/engine.csgo");
	if (gamedata == INVALID_HANDLE)
    {
        SetFailState("Failed to find gamedata");
    }
    
	int traceAttackOffset = GameConfGetOffset(gamedata, "TraceAttack");
	CloseHandle(gamedata);

	DHOOK_TraceAttack = DHookCreate(traceAttackOffset, HookType_Entity, ReturnType_Int, ThisPointer_CBaseEntity, TraceAttack);
	DHookAddParam(DHOOK_TraceAttack, HookParamType_ObjectPtr, -1, DHookPass_ByRef);	// const CTakeDamageInfo&
	DHookAddParam(DHOOK_TraceAttack, HookParamType_ObjectPtr, -1, DHookPass_ByRef);	// const Vector&
	DHookAddParam(DHOOK_TraceAttack, HookParamType_ObjectPtr, -1, DHookPass_ByVal);	// CGameTrace*

	RegConsoleCmd("+easyheadshot", EasyHeadshotEnable);
	RegConsoleCmd("-easyheadshot", EasyHeadshotDisable);
}


public void OnClientPutInServer(client)
{
	DHookEntity(DHOOK_TraceAttack, false, client);
	g_bIsEnabled[client] = false;
}

public Action:EasyHeadshotEnable(client, args)
{
	g_bIsEnabled[client] = true;
	return Plugin_Handled;
}

public Action:EasyHeadshotDisable(client, args)
{
	g_bIsEnabled[client] = false;
	return Plugin_Handled;
}

// TraceAttack(CTakeDamageInfo const&, Vector const&, CGameTrace*)
public MRESReturn TraceAttack(pThis, Handle:hReturn, Handle:hParams)
{
	int attacker = DHookGetParamObjectPtrVar(hParams, 1, 36, ObjectValueType_Ehandle);
	int ammotype = DHookGetParamObjectPtrVar(hParams, 1, 72, ObjectValueType_Int);
	
	if (IsValidClient(attacker, true) && g_bIsEnabled[attacker] && ammotype > 0)
	{
		int hitgroup = DHookGetParamObjectPtrVar(hParams, 3, 56+12, ObjectValueType_Int);

		// Already hitting HITGROUP_HEAD (1), avoid fiddling with the CGameTrace*.
		if (hitgroup == 1)
		{
			return MRES_Ignored;
		}

		// Set hitgroup to HITGROUP_HEAD (1)
		DHookSetParamObjectPtrVar(hParams, 3, 56+12, ObjectValueType_Int, 1);

		// Set CGameTrace::endpos to victim's eye position. Might revisit later to set it to victim's BONE_HEAD position instead.
		float eyePos[3];
		GetClientEyePosition(pThis, eyePos);
		DHookSetParamObjectPtrVarVector(hParams, 3, 12, ObjectValueType_Vector, eyePos);

		// Set CGameTrace::physicsbone to the head bone (14)
		DHookSetParamObjectPtrVar(hParams, 3, 56+16, ObjectValueType_Int, 14);
	}

	return MRES_Ignored;
}

bool IsValidClient(client, bool:noBots = true)
{ 
    if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (noBots && IsFakeClient(client)))
    {
        return false; 
    }

    return IsClientInGame(client); 
}

// classes & structs used, for reference
/* 

class CBaseTrace
{
	Vector			startpos;		// 12
	Vector			endpos;			// 12
	cplane_t		plane;			// 20
	float			fraction;		// 4
	int				contents;		// 4
	unsigned short	dispFlags;		// 2
	bool			allsolid;		// 1
	bool			startsolid;		// 1
}									// size = 56

class CGameTrace : CBaseTrace
{
	float		fractionleftsolid;	// 4
	csurface_t	surface;			// 8
	int			hitgroup;			// 4
	short		physicsbone			// 2
}									// size = 18

struct cplane_t 
{
	Vector normal;					// 12
	float dist						// 4
	byte type;						// 1
	byte signbits					// 1
	byte pad[2];					// 2
}									// size = 20

struct csurface_t
{
	const char*		name;			// 4
	short			surfaceProps;	// 2
	unsigned short	flags;			// 2
};									// size = 8

class CTakeDamageInfo
{
	Vector			m_vecDamageForce; 			// 12
	Vector			m_vecDamagePosition;		// 12
	Vector			m_vecReportedPosition;		// 12
	EHANDLE			m_hInflictor;				// 4
	EHANDLE			m_hAttacker;				// 4
	EHANDLE			m_hWeapon;					// 4
	float			m_flDamage;					// 4
	float			m_flMaxDamage;				// 4
	float			m_flBaseDamage;				// 4
	int				m_bitsDamageType;			// 4
	int				m_iDamageCustom;			// 4
	int				m_iDamageStats;				// 4
	int				m_iAmmoType;				// 4
	int				m_iDamagedOtherPlayers;		// 4
	int				m_iPlayerPenetrationCount;	// 4
	float			m_flDamageBonus;			// 4
	bool			m_bForceFriendlyFire;		// 1
}												// size = 89

https://github.com/ValveSoftware/source-sdk-2013/tree/master/sp/src/game/shared

*/