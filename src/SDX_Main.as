/*
	Survival DeluXe: Main Script
	Copyright (C) 2019  Julian Rodriguez
	
	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.
	
	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.
	
	You should have received a copy of the GNU General Public License
	along with this program. If not, see <https://www.gnu.org/licenses/>.
*/

#include "SDX_Checkpoint"
#include "SDX/items/base"
const uint MAX_ITEMS = 33;

// Configs
const string PATH_WEAPON_TYPES = "scripts/plugins/SDX/types.ini";
const string PATH_WEAPON_MEELES = "scripts/plugins/SDX/meeles/";
const string PATH_WEAPON_PISTOLS = "scripts/plugins/SDX/pistols/";
const string PATH_WEAPON_SHOTGUNS = "scripts/plugins/SDX/shotguns/";
const string PATH_WEAPON_RIFLES = "scripts/plugins/SDX/rifles/";
const string PATH_WEAPON_SNIPERS = "scripts/plugins/SDX/snipers/";
const string PATH_WEAPON_MEDKITS = "scripts/plugins/SDX/medkits/";
const string PATH_WEAPON_OTHERS = "scripts/plugins/SDX/others/";
const string PATH_MAPS_SETTINGS = "scripts/plugins/SDX/maps/";

// Data storage
const string PATH_DATA_PLAYERS = "scripts/plugins/store/sdx_plrdata/"; // Player perk data
const string PATH_DATA_ITEMS = "scripts/plugins/store/sdx_itemdata/"; // Player item data
const string PATH_DATA_DIFFICULTY = "scripts/plugins/temp/sdx_diff.sys"; // Map difficulty

enum e_iWeaponType
{
	INVALID = 0,
	MEELE,
	PISTOL,
	SHOTGUN,
	RIFLE,
	SNIPER,
	MEDKIT,
	OTHER
};

enum e_iPlayerPerk
{
	NONE = 0,
	FIELD_MEDIC,
	SUPPORT_SPECIALIST,
	SHARPSHOOTER,
	COMMANDO,
	BERSERKER,
	SURVIVALIST,
	DEMOLITIONS
};

enum e_iDifficulty
{
	UNDEFINED = 0,
	BEGINNER,
	NORMAL,
	HARD,
	SUICIDE,
	HELL
};

// Player vars
array< int > plPerk( 33 );
array< int > plLevel( 33 );

// Perk vars
array< int > iHPHealing( 33 ); // Medic
array< int > iMeeleDamage( 33 ); // Berserker
array< int > iHeadShots( 33 ); // Sharpshooter
array< int > iShotgunDamage( 33 ); // Support Specialist
array< int > iExplosiveDamage( 33 ); // Demolitions
array< int > iRifleDamage( 33 ); // Commando
array< int > iOtherDamage( 33 ); // Survivalist

array< int > iExtraHPHeal( 33 ); // Medic
array< int > iExtraHPSpeed( 33 ); // Medic
array< int > iPoisonResist( 33 ); // Medic - Berserker - Survivalist
array< int > iExtraAPGet( 33 ); // Medic - Survivalist
array< int > iExtraMaxAP( 33 ); // Medic - Survivalist
array< int > iExtraMoveSpeed( 33 ); // Medic - Berseker
array< int > iExtraHPAmmo( 33 ); // Medic
array< int > iDamageResist( 33 ); // Berserker - Support Specialist - Demolitions
array< int > iAttackSpeed( 33 ); // Berserker
array< int > iExtraBaseDamage( 33 ); // Berserker - Support Specialist - Sharpshooter - Demolitions - Commando - Survivalist
array< float > flExtraHSDamage( 33 ); // Support Specialist - Sharpshooter - Survivalist
array< int > iLowerRecoil( 33 ); // Sharpshooter - Commando - Survivalist
array< int > iReloadSpeed( 33 ); // Sharpshooter - Commando
array< int > iExtraSRAmmo( 33 ); // Support Specialist
array< int > iExtraHGAmmo( 33 ); // Support Specialist - Demolitions
array< int > iExtraHGDamage( 33 ); // Support Specialist
array< int > iDistanceHealth( 33 ); // Commando
array< int > iDistanceView( 33 ); // Commando

// Item vars
array< int > pl_iMaxItems( 33 ); // Max amount of items a player can carry
array< int > pl_iMaxStorage( 33 ); // Max amount of items a player can store in it's warehouse
array< array< int >> pl_iItemData( 33, array< int >( MAX_ITEMS ) ); // Player inventory data

// System vars
array< float > flNextHPRegen( 33 ); // Medic
float flMapMaxSpeed; // Map's sv_maxspeed
float flMapMaxHealth; // Map's maxhealth
float flMapMaxArmor; // Map's maxarmor
int iAutoStartTime; // When game should automatically start
CScheduledFunction@ CSF_AutoStartTask = null; // Pointer to the auto-start schedule
float flGameTime; // Map "start" time
int iDifficulty; // Map's difficulty
string szMapName; // Map's filename (excluding .bsp)
array< bool > bDoNotSave( 33 ); // Avoid saving a player's data?
bool bVoting; // A vote is in progress?
array< bool > bPLRDiffVoted( 33 ); // Has this player done a difficulty vote before?
bool bBeginnerWarn; // Should players be warned that beginner difficulty is frowned upon in this map?
array< int > bHasMGAccess( 33 ); // Whenever this player has access to Mystery Gift

// Effect vars
int iHPGrenadeIndex;
const string szHPGrenadeSound = "weapons/cs16/sg_explode.wav";

// System sounds
const string SND_LevelUp = "ecsc/sdx/levelup_v2.ogg";

dictionary pmenu_state;
class MenuHandler
{
	CTextMenu@ menu;
	
	void InitMenu( CBasePlayer@ pPlayer, TextMenuPlayerSlotCallback@ callback )
	{
		CTextMenu temp( @callback );
		@menu = @temp;
	}
	
	void OpenMenu( CBasePlayer@ pPlayer, int& in time, int& in page )
	{
		menu.Register();
		menu.Open( time, page, pPlayer );
	}
}

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor( "Julian \"Giegue\" Rodriguez" );
	g_Module.ScriptInfo.SetContactInfo( "www.steamcommunity.com/id/ngiegue" );
	
	g_Hooks.RegisterHook( Hooks::Weapon::WeaponPrimaryAttack, @WeaponPrimaryAttack );
	g_Hooks.RegisterHook( Hooks::Weapon::WeaponSecondaryAttack, @WeaponSecondaryAttack );
	g_Hooks.RegisterHook( Hooks::Weapon::WeaponTertiaryAttack, @WeaponTertiaryAttack );
	
	g_Hooks.RegisterHook( Hooks::Player::PlayerPostThink, @PlayerPostThink );
	g_Hooks.RegisterHook( Hooks::Player::PlayerSpawn, @PlayerSpawn );
	g_Hooks.RegisterHook( Hooks::Player::PlayerKilled, @PlayerKilled );
	
	g_Hooks.RegisterHook( Hooks::Player::ClientPutInServer, @ClientPutInServer );
	g_Hooks.RegisterHook( Hooks::Player::ClientDisconnect, @ClientDisconnect );
	g_Hooks.RegisterHook( Hooks::Player::ClientSay, @ClientSay );
	
	g_Scheduler.SetInterval( "SUB_GrenadeThink", 0.1, g_Scheduler.REPEAT_INFINITE_TIMES );
	g_Scheduler.SetInterval( "SUB_RenderThink", 0.1, g_Scheduler.REPEAT_INFINITE_TIMES );
	g_Scheduler.SetInterval( "HELPER_SetAlly", 0.2, g_Scheduler.REPEAT_INFINITE_TIMES );
	g_Scheduler.SetInterval( "HUDUpdate", 0.5, g_Scheduler.REPEAT_INFINITE_TIMES );
}

void MapInit()
{
	// Enable survival, but don't activate yet
	RegisterPointCheckPointEntity();
	g_SurvivalMode.EnableMapSupport();
	g_SurvivalMode.SetStartOn( false );
	
	// Precache and assign necessary stuff
	g_Game.PrecacheOther( "point_checkpoint" );
	iHPGrenadeIndex = g_Game.PrecacheModel( "sprites/ecsc/hpsmoke.spr" );
	g_Game.PrecacheGeneric( "sound/" + szHPGrenadeSound );
	g_Game.PrecacheGeneric( "sound/" + SND_LevelUp );
	g_SoundSystem.PrecacheSound( szHPGrenadeSound );
	g_SoundSystem.PrecacheSound( SND_LevelUp );
	
	// Get map's filename
	szMapName = g_Engine.mapname;
	
	// Reset vars
	for ( uint i = 0; i < 33; i++ )
	{
		plPerk[ i ] = NONE;
		plLevel[ i ] = -1;
		
		iHPHealing[ i ] = 0;
		iMeeleDamage[ i ] = 0;
		iHeadShots[ i ] = 0;
		iShotgunDamage[ i ] = 0;
		iExplosiveDamage[ i ] = 0;
		iRifleDamage[ i ] = 0;
		iOtherDamage[ i ] = 0;
		
		iExtraHPHeal[ i ] = 0;
		iExtraHPSpeed[ i ] = 0;
		iPoisonResist[ i ] = 0;
		iExtraAPGet[ i ] = 0;
		iExtraMaxAP[ i ] = 0;
		iExtraMoveSpeed[ i ] = 0;
		iExtraHPAmmo[ i ] = 0;
		iDamageResist[ i ] = 0;
		iAttackSpeed[ i ] = 0;
		iExtraBaseDamage[ i ] = 0;
		flExtraHSDamage[ i ] = 0.0;
		iLowerRecoil[ i ] = 0;
		iReloadSpeed[ i ] = 0;
		iExtraSRAmmo[ i ] = 0;
		iExtraHGAmmo[ i ] = 0;
		iExtraHGDamage[ i ] = 0;
		iDistanceHealth[ i ] = 0;
		iDistanceView[ i ] = 0;
		
		flNextHPRegen[ i ] = 0.0;
		bDoNotSave[ i ] = false;
		bPLRDiffVoted[ i ] = false;
		bHasMGAccess[ i ] = 0;
		
		pl_iMaxItems[ i ] = 7;
		pl_iMaxStorage[ i ] = 14;
		for ( uint j = 0; j < 33; j++ )
		{
			pl_iItemData[ i ][ j ] = 0;
		}
	}
	bVoting = false;
	bBeginnerWarn = false;
	BaseItem_Init();
	
	// Reset auto-start time
	if ( CSF_AutoStartTask !is null )
	{
		g_Scheduler.RemoveTimer( CSF_AutoStartTask );
		@CSF_AutoStartTask = @null;
	}
	iAutoStartTime = 20;
	
	// Get difficulty
	File@ fFile = g_FileSystem.OpenFile( PATH_DATA_DIFFICULTY, OpenFile::READ );
	if ( fFile !is null && fFile.IsOpen() )
	{
		string szLine;
		fFile.ReadLine( szLine );
		
		iDifficulty = atoi( szLine );
		fFile.Close();
	}
	else
		iDifficulty = NORMAL; // Default to normal if saved diff cannot be loaded
	
	// Reset menu data
	array< string >@ states = pmenu_state.getKeys();
	for ( uint i = 0; i < states.length(); i++ )
	{
		MenuHandler@ state = cast< MenuHandler@ >( pmenu_state[ states[ i ] ] );
		if ( state.menu !is null )
			@state.menu = null;
	}
	
	// Open map .ent config (if it exists) and see if there's anything to precache
	string szPath = "" + PATH_MAPS_SETTINGS + szMapName + ".ent";
	@fFile = g_FileSystem.OpenFile( szPath, OpenFile::READ );
	if ( fFile !is null && fFile.IsOpen() )
	{
		string szLine;
		while ( !fFile.EOFReached() )
		{
			fFile.ReadLine( szLine );
			
			// Blank line
			if ( szLine.Length() == 0 )
				continue;
			
			array< string >@ pre_data = szLine.Split( '=' );
			
			// ONLY THESE!
			if ( pre_data[ 0 ] == 'PRECACHE_ENTITY' )
				g_Game.PrecacheOther( pre_data[ 1 ] );
			else if ( pre_data[ 0 ] == 'PRECACHE_MODEL' )
				g_Game.PrecacheModel( pre_data[ 1 ] );
			else if ( pre_data[ 0 ] == 'PRECACHE_SOUND' )
			{
				g_Game.PrecacheGeneric( "sound/" + pre_data[ 1 ] );
				g_SoundSystem.PrecacheSound( pre_data[ 1 ] );
			}
			else if ( pre_data[ 0 ] == 'NO_BEGINNER_WARN' && pre_data[ 1 ] == '1' )
				bBeginnerWarn = true;
			else
				break; // Assume there's nothing else to do
		}
		
		fFile.Close();
	}
	
	// Items
	RegisterItem( "OranBerry" );
	RegisterItem( "SitrusBerry" );
	RegisterItem( "ReviverSeed" );
}

void MapActivate()
{
	// Get map maxspeed
	flMapMaxSpeed = g_EngineFuncs.CVarGetFloat( "sv_maxspeed" );
	
	// Remove map maxspeed limit, so players can go faster with movespeed bonus
	g_EngineFuncs.CVarSetFloat( "sv_maxspeed", 640.0 );
	
	// Determine whenever the game should start on it's own
	flGameTime = g_Engine.time;
	CheckAutoStart();
	
	// Create global env_render_individual for commando perk
	CBaseEntity@ pRender = g_EntityFuncs.Create( "env_render_individual", g_vecZero, g_vecZero, false );
	pRender.pev.spawnflags = 77; // No renderfx/mode/color + Affect activator
	pRender.pev.renderamt = 200;
	pRender.pev.target = "sdx_render_target";
	pRender.pev.targetname = "sdx_glb_render";
	
	// Get map maxhealth and maxarmor
	// AMXX needs a little time to properly update the internal CVars
	g_Scheduler.SetTimeout( "UpdateMapMaxs", 0.33 );
}

void UpdateMapMaxs()
{
	flMapMaxHealth = g_EngineFuncs.CVarGetFloat( "_sdx_map_maxhealth" );
	flMapMaxArmor = g_EngineFuncs.CVarGetFloat( "_sdx_map_maxarmor" );
}

MenuHandler@ MenuGetPlayer( CBasePlayer@ pPlayer )
{
	string steamid = g_EngineFuncs.GetPlayerAuthId( pPlayer.edict() );
	if ( steamid == 'STEAM_ID_LAN' )
	{
		steamid = pPlayer.pev.netname;
	}
	
	if ( !pmenu_state.exists( steamid ) )
	{
		MenuHandler state;
		pmenu_state[ steamid ] = state;
	}
	return cast< MenuHandler@ >( pmenu_state[ steamid ] );
}

// Calculate player level
int GetLevel( const int& in iPlayerIndex, const int& in iPerk, int& out iLevelNeed = 0 )
{
	int iLevel = -1;
	switch ( iPerk )
	{
		case FIELD_MEDIC:
		{
			if ( iHPHealing[ iPlayerIndex ] >= 750000 )
			{
				iLevelNeed = 1312500;
				iLevel = 6;
			}
			else if ( iHPHealing[ iPlayerIndex ] >= 225000 )
			{
				iLevelNeed = 750000;
				iLevel = 5;
			}
			else if ( iHPHealing[ iPlayerIndex ] >= 90000 )
			{
				iLevelNeed = 225000;
				iLevel = 4;
			}
			else if ( iHPHealing[ iPlayerIndex ] >= 30000 )
			{
				iLevelNeed = 90000;
				iLevel = 3;
			}
			else if ( iHPHealing[ iPlayerIndex ] >= 5625 )
			{
				iLevelNeed = 30000;
				iLevel = 2;
			}
			else if ( iHPHealing[ iPlayerIndex ] >= 1500 )
			{
				iLevelNeed = 5625;
				iLevel = 1;
			}
			else
			{
				iLevelNeed = 1500;
				iLevel = 0;
			}
			
			break;
		}
		case SUPPORT_SPECIALIST:
		{
			if ( iShotgunDamage[ iPlayerIndex ] >= 5000000 )
			{
				iLevelNeed = 9000000;
				iLevel = 6;
			}
			else if ( iShotgunDamage[ iPlayerIndex ] >= 2500000 )
			{
				iLevelNeed = 5000000;
				iLevel = 5;
			}
			else if ( iShotgunDamage[ iPlayerIndex ] >= 1000000 )
			{
				iLevelNeed = 2500000;
				iLevel = 4;
			}
			else if ( iShotgunDamage[ iPlayerIndex ] >= 500000 )
			{
				iLevelNeed = 1000000;
				iLevel = 3;
			}
			else if ( iShotgunDamage[ iPlayerIndex ] >= 100000 )
			{
				iLevelNeed = 500000;
				iLevel = 2;
			}
			else if ( iShotgunDamage[ iPlayerIndex ] >= 20000 )
			{
				iLevelNeed = 100000;
				iLevel = 1;
			}
			else
			{
				iLevelNeed = 20000;
				iLevel = 0;
			}
			
			break;
		}
		case SHARPSHOOTER:
		{
			if ( iHeadShots[ iPlayerIndex ] >= 17000 )
			{
				iLevelNeed = 25000;
				iLevel = 6;
			}
			else if ( iHeadShots[ iPlayerIndex ] >= 11000 )
			{
				iLevelNeed = 17000;
				iLevel = 5;
			}
			else if ( iHeadShots[ iPlayerIndex ] >= 5000 )
			{
				iLevelNeed = 11000;
				iLevel = 4;
			}
			else if ( iHeadShots[ iPlayerIndex ] >= 1400 )
			{
				iLevelNeed = 5000;
				iLevel = 3;
			}
			else if ( iHeadShots[ iPlayerIndex ] >= 200 )
			{
				iLevelNeed = 1400;
				iLevel = 2;
			}
			else if ( iHeadShots[ iPlayerIndex ] >= 60 )
			{
				iLevelNeed = 200;
				iLevel = 1;
			}
			else
			{
				iLevelNeed = 60;
				iLevel = 0;
			}
			
			break;
		}
		case COMMANDO:
		{
			if ( iRifleDamage[ iPlayerIndex ] >= 3000000 )
			{
				iLevelNeed = 5000000;
				iLevel = 6;
			}
			else if ( iRifleDamage[ iPlayerIndex ] >= 1500000 )
			{
				iLevelNeed = 3000000;
				iLevel = 5;
			}
			else if ( iRifleDamage[ iPlayerIndex ] >= 750000 )
			{
				iLevelNeed = 1500000;
				iLevel = 4;
			}
			else if ( iRifleDamage[ iPlayerIndex ] >= 250000 )
			{
				iLevelNeed = 750000;
				iLevel = 3;
			}
			else if ( iRifleDamage[ iPlayerIndex ] >= 50000 )
			{
				iLevelNeed = 250000;
				iLevel = 2;
			}
			else if ( iRifleDamage[ iPlayerIndex ] >= 10000 )
			{
				iLevelNeed = 50000;
				iLevel = 1;
			}
			else
			{
				iLevelNeed = 10000;
				iLevel = 0;
			}
			
			break;
		}
		case BERSERKER:
		{
			if ( iMeeleDamage[ iPlayerIndex ] >= 3000000 )
			{
				iLevelNeed = 7500000;
				iLevel = 6;
			}
			else if ( iMeeleDamage[ iPlayerIndex ] >= 1500000 )
			{
				iLevelNeed = 3000000;
				iLevel = 5;
			}
			else if ( iMeeleDamage[ iPlayerIndex ] >= 700000 )
			{
				iLevelNeed = 1500000;
				iLevel = 4;
			}
			else if ( iMeeleDamage[ iPlayerIndex ] >= 250000 )
			{
				iLevelNeed = 700000;
				iLevel = 3;
			}
			else if ( iMeeleDamage[ iPlayerIndex ] >= 40000 )
			{
				iLevelNeed = 250000;
				iLevel = 2;
			}
			else if ( iMeeleDamage[ iPlayerIndex ] >= 10000 )
			{
				iLevelNeed = 40000;
				iLevel = 1;
			}
			else
			{
				iLevelNeed = 10000;
				iLevel = 0;
			}
			
			break;
		}
		case SURVIVALIST:
		{
			if ( iOtherDamage[ iPlayerIndex ] >= 400000 )
			{
				iLevelNeed = 900000;
				iLevel = 6;
			}
			else if ( iOtherDamage[ iPlayerIndex ] >= 200000 )
			{
				iLevelNeed = 400000;
				iLevel = 5;
			}
			else if ( iOtherDamage[ iPlayerIndex ] >= 100000 )
			{
				iLevelNeed = 200000;
				iLevel = 4;
			}
			else if ( iOtherDamage[ iPlayerIndex ] >= 50000 )
			{
				iLevelNeed = 100000;
				iLevel = 3;
			}
			else if ( iOtherDamage[ iPlayerIndex ] >= 25000 )
			{
				iLevelNeed = 50000;
				iLevel = 2;
			}
			else if ( iOtherDamage[ iPlayerIndex ] >= 12500 )
			{
				iLevelNeed = 25000;
				iLevel = 1;
			}
			else
			{
				iLevelNeed = 12500;
				iLevel = 0;
			}
			
			break;
		}
		case DEMOLITIONS:
		{
			if ( iExplosiveDamage[ iPlayerIndex ] >= 700000 )
			{
				iLevelNeed = 1250000;
				iLevel = 6;
			}
			else if ( iExplosiveDamage[ iPlayerIndex ] >= 450000 )
			{
				iLevelNeed = 700000;
				iLevel = 5;
			}
			else if ( iExplosiveDamage[ iPlayerIndex ] >= 200000 )
			{
				iLevelNeed = 450000;
				iLevel = 4;
			}
			else if ( iExplosiveDamage[ iPlayerIndex ] >= 50000 )
			{
				iLevelNeed = 200000;
				iLevel = 3;
			}
			else if ( iExplosiveDamage[ iPlayerIndex ] >= 15000 )
			{
				iLevelNeed = 50000;
				iLevel = 2;
			}
			else if ( iExplosiveDamage[ iPlayerIndex ] >= 3000 )
			{
				iLevelNeed = 15000;
				iLevel = 1;
			}
			else
			{
				iLevelNeed = 3000;
				iLevel = 0;
			}
			
			break;
		}
	}
	
	return iLevel;
}

void CheckPerkStatus( CBasePlayer@ pPlayer, const int& in iPerk, const int& in iOldLevel )
{
	int iPlayerIndex = pPlayer.entindex();
	
	string szPerk = "";
	switch ( iPerk )
	{
		case FIELD_MEDIC: szPerk = "Field Medic"; break;
		case SUPPORT_SPECIALIST: szPerk = "Support Specialist"; break;
		case SHARPSHOOTER: szPerk = "Sharpshooter"; break;
		case COMMANDO: szPerk = "Commando"; break;
		case BERSERKER: szPerk = "Berserker"; break;
		case SURVIVALIST: szPerk = "???"; break;
		case DEMOLITIONS: szPerk = "Demolitions"; break;
	}
	
	int iNewLevel = GetLevel( iPlayerIndex, iPerk );
	if ( iNewLevel > iOldLevel )
	{
		// Level up!
		if ( iPerk == plPerk[ iPlayerIndex ] )
		{
			plLevel[ iPlayerIndex ] = iNewLevel;
			GetPerkBonus( iPlayerIndex, plPerk[ iPlayerIndex ], iNewLevel );
		}
		
		// Effects
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[SDX] Has mejorado tu Perk: " + szPerk + " a Level " + iNewLevel + "!\n" );
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCENTER, "Enhorabuena!\nTu " + szPerk + " es ahora Level " + iNewLevel + "!\n" );
		g_SoundSystem.EmitSoundDyn( pPlayer.edict(), CHAN_STATIC, SND_LevelUp, VOL_NORM, ATTN_NONE, SND_SKIP_ORIGIN_USE_ENT, PITCH_NORM, iPlayerIndex );
		g_Game.AlertMessage( at_logged, "[SDX] " + pPlayer.pev.netname + " (" + g_EngineFuncs.GetPlayerAuthId( pPlayer.edict() ) + ") alcanzo el Level " + iNewLevel + " (" + szPerk + ")\n" );
		
		// EVENT-DELETEME
		if ( iPerk == SURVIVALIST && iNewLevel == 6 )
		{
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[SDX] LO LOGRASTE! Guarda el siguiente codigo para redimir una recompensa especial en el futuro:\n" );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[SDX] E1VRI-JSIT1\n" );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[SDX] Anotalo bien! Este codigo NO SE REPETIRA!\n" );
		}
	}
}

HookReturnCode ClientSay( SayParameters@ pParams )
{
	// Game must have started
	if ( !g_SurvivalMode.IsActive() )
		return HOOK_CONTINUE;
	
	ClientSayType type = pParams.GetSayType();
	if ( type == CLIENTSAY_SAY )
	{
		CBasePlayer@ pPlayer = pParams.GetPlayer();
		string text = pParams.GetCommand();
		text.ToLowercase();
		
		if ( text == '/perks' )
		{
			pParams.ShouldHide = true;
			PlayerIntro( pPlayer.entindex(), true );
			return HOOK_HANDLED;
		}
		else if ( text == '/difficulty' || text == '/diff' )
		{
			pParams.ShouldHide = true;
			
			string szMessage = "[SDX] Dificultad del mapa: ";
			switch ( iDifficulty )
			{
				case BEGINNER: szMessage += "Beginner"; break;
				case NORMAL: szMessage += "Normal"; break;
				case HARD: szMessage += "Hard"; break;
				case SUICIDE: szMessage += "Suicidal"; break;
				case HELL: szMessage += "Hell"; break;
			}
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "" + szMessage + "\n" );
			
			return HOOK_HANDLED;
		}
		else if ( text == '/items' )
		{
			pParams.ShouldHide = true;
			ItemMenu( pPlayer.entindex() );
			return HOOK_HANDLED;
		}
		else
		{
			// Check for commands with arguments
			const CCommand@ args = pParams.GetArguments();
			if ( args[ 0 ] == '/mystery' )
			{
				pParams.ShouldHide = true;
				MysteryGift_CheckUnlock( pParams );
				return HOOK_HANDLED;
			}
		}
	}
	
	return HOOK_CONTINUE;
}

HookReturnCode PlayerPostThink( CBasePlayer@ pPlayer )
{
	// Gather some necessary data
	int iPlayerIndex = pPlayer.entindex();
	CustomKeyvalues@ pKVD = pPlayer.GetCustomKeyvalues();
	CBasePlayerItem@ pItem = cast< CBasePlayerItem@ >( pPlayer.m_hActiveItem.GetEntity() );
	CBasePlayerWeapon@ pWeapon = null;
	if ( pItem !is null )
		@pWeapon = pItem.GetWeaponPtr();
	
	// Send the weapon type to AMXX helper
	CustomKeyvalue iWeaponType_pre( pKVD.GetKeyvalue( "$i_sdx_wpn_type" ) );
	int iWeaponType = iWeaponType_pre.GetInteger();
	pPlayer.pev.noise2 = string( iWeaponType );
	
	// Get any system operation on player
	CustomKeyvalue iShouldReload_pre( pKVD.GetKeyvalue( "$i_sdx_wpn_doreload" ) );
	CustomKeyvalue iUpdateWPNData_pre( pKVD.GetKeyvalue( "$i_sdx_wpn_update" ) );
	CustomKeyvalue iAddMeleeDamage_pre( pKVD.GetKeyvalue( "$i_sdx_add_meeledmg" ) );
	CustomKeyvalue iAddHeadShot_pre( pKVD.GetKeyvalue( "$i_sdx_add_headshot" ) );
	CustomKeyvalue iAddShotgunDamage_pre( pKVD.GetKeyvalue( "$i_sdx_add_shotgundmg" ) );
	CustomKeyvalue iAddExplosiveDamage_pre( pKVD.GetKeyvalue( "$i_sdx_add_blastdmg" ) );
	CustomKeyvalue iAddRifleDamage_pre( pKVD.GetKeyvalue( "$i_sdx_add_rifledmg" ) );
	CustomKeyvalue iAddOtherDamage_pre( pKVD.GetKeyvalue( "$i_sdx_add_otherdmg" ) );
	CustomKeyvalue bReapplyPerk_pre( pKVD.GetKeyvalue( "$i_sdx_redo_perk" ) );
	
	int iShouldReload = iShouldReload_pre.GetInteger();
	int iUpdateWPNData = iUpdateWPNData_pre.GetInteger();
	int iAddMeeleDamage = iAddMeleeDamage_pre.GetInteger();
	int iAddHeadShot = iAddHeadShot_pre.GetInteger();
	int iAddShotgunDamage = iAddShotgunDamage_pre.GetInteger();
	int iAddExplosiveDamage = iAddExplosiveDamage_pre.GetInteger();
	int iAddRifleDamage = iAddRifleDamage_pre.GetInteger();
	int iAddOtherDamage = iAddOtherDamage_pre.GetInteger();
	int bReapplyPerk = bReapplyPerk_pre.GetInteger();
	
	if ( iShouldReload == 1 ) // Reload weapon?
	{
		if ( pWeapon !is null )
		{
			CustomKeyvalue flReloadTime_pre( pKVD.GetKeyvalue( "$f_sdx_wpn_reloadtime" ) );
			float flReloadTime = flReloadTime_pre.GetFloat();
			
			// This weapon is meant to be reloadable?
			if ( flReloadTime > 0.0 )
			{
				// Aren't we already reloading?
				if ( !pWeapon.m_fInReload )
				{
					// Initialize framerate
					float flFrameRate = 1.0;
					
					// Get neccesary values for reload
					int iClipSize = pWeapon.m_iClip;
					int iAnim;
					if ( iClipSize == 0 )
					{
						CustomKeyvalue iAnimEmpty_pre( pKVD.GetKeyvalue( "$i_sdx_wpn_reloadanim_e" ) );
						iAnim = iAnimEmpty_pre.GetInteger();
					}
					else
					{
						CustomKeyvalue iAnimDefault_pre( pKVD.GetKeyvalue( "$i_sdx_wpn_reloadanim_d" ) );
						iAnim = iAnimDefault_pre.GetInteger();
					}
					
					// Our perk allows faster reload time?
					if ( plPerk[ iPlayerIndex ] == SHARPSHOOTER )
					{
						// Sharpshooter only has faster reload time on these weapons
						if ( iWeaponType == PISTOL || iWeaponType == SNIPER )
						{
							// Calculate new reload time
							flReloadTime = flReloadTime * ( 100.0 - float( iReloadSpeed[ iPlayerIndex ] ) ) / 100.0;
							flFrameRate = flFrameRate * ( 100.0 + float( iReloadSpeed[ iPlayerIndex ] ) ) / 100.0;
						}
					}
					else if ( plPerk[ iPlayerIndex ] == COMMANDO )
					{
						// Commando can reload ANYTHING but shotguns faster
						flReloadTime = flReloadTime * ( 100.0 - float( iReloadSpeed[ iPlayerIndex ] ) ) / 100.0;
						flFrameRate = flFrameRate * ( 100.0 + float( iReloadSpeed[ iPlayerIndex ] ) ) / 100.0;
					}
					
					// Perform the reload
					DoReload( pPlayer, pWeapon.iMaxClip(), iAnim, flReloadTime, flFrameRate );
				}
			}
		}
		
		pPlayer.KeyValue( "$i_sdx_wpn_doreload", "0" );
	}
	
	if ( iUpdateWPNData == 1 ) // Update weapon data?
	{
		if ( pWeapon !is null )
		{
			// Update weapon data if needed
			CustomKeyvalue szWeapon_pre( pKVD.GetKeyvalue( "$s_sdx_wpn_classname" ) );
			string szWeapon = szWeapon_pre.GetString();
			
			if ( szWeapon != pWeapon.pev.classname )
			{
				// Get weapon data
				LoadWeaponData( pPlayer, pWeapon.pev.classname );
				pPlayer.KeyValue( "$s_sdx_wpn_classname", pWeapon.pev.classname );
				
				// Is this the SC ShockRifle?
				if ( pWeapon.pev.classname == 'weapon_shockrifle' )
				{
					// Using the perk?
					if ( plPerk[ iPlayerIndex ] == SUPPORT_SPECIALIST )
					{
						// Add extra ammo
						pPlayer.m_rgAmmo( pWeapon.m_iPrimaryAmmoType, int( float( pPlayer.m_rgAmmo( pWeapon.m_iPrimaryAmmoType ) ) * ( 100.0 + float( iExtraSRAmmo[ iPlayerIndex ] ) ) / 100.0 ) ); // dem casts BOI
					}
				}
			}
		}
		
		pPlayer.KeyValue( "$i_sdx_wpn_update", "0" );
	}
	
	if ( iAddMeeleDamage > 0 ) // Add accumulated meele damage?
	{
		// Only add to total if NORMAL or higher difficulty. Or if the player is a "new" one
		int iOldLevel = GetLevel( iPlayerIndex, BERSERKER );
		if ( iDifficulty >= NORMAL || iOldLevel == 0 )
		{
			// Just add to perk status regardless of current perk
			iMeeleDamage[ iPlayerIndex ] += iAddMeeleDamage;
			CheckPerkStatus( pPlayer, BERSERKER, iOldLevel );
			
			SaveData( pPlayer );
		}
		
		pPlayer.KeyValue( "$i_sdx_add_meeledmg", "0" );
	}
	
	if ( iAddHeadShot == 1 ) // Add accumulated headshots?
	{
		// Only add to total if NORMAL or higher difficulty. Or if the player is a "new" one
		int iOldLevel = GetLevel( iPlayerIndex, SHARPSHOOTER );
		if ( iDifficulty >= NORMAL || iOldLevel == 0 )
		{
			// Just add to perk status regardless of current perk
			iHeadShots[ iPlayerIndex ] += 1;
			CheckPerkStatus( pPlayer, SHARPSHOOTER, iOldLevel );
			
			SaveData( pPlayer );
		}
		
		pPlayer.KeyValue( "$i_sdx_add_headshot", "0" );
	}
	
	if ( iAddShotgunDamage > 0 ) // Add accumulated meele damage?
	{
		// Only add to total if NORMAL or higher difficulty. Or if the player is a "new" one
		int iOldLevel = GetLevel( iPlayerIndex, SUPPORT_SPECIALIST );
		if ( iDifficulty >= NORMAL || iOldLevel == 0 )
		{
			// Just add to perk status regardless of current perk
			iShotgunDamage[ iPlayerIndex ] += iAddShotgunDamage;
			CheckPerkStatus( pPlayer, SUPPORT_SPECIALIST, iOldLevel );
			
			SaveData( pPlayer );
		}
		
		pPlayer.KeyValue( "$i_sdx_add_shotgundmg", "0" );
	}
	
	if ( iAddExplosiveDamage > 0 ) // Add accumulated damage done with explosives?
	{
		// Only add to total if NORMAL or higher difficulty. Or if the player is a "new" one
		int iOldLevel = GetLevel( iPlayerIndex, DEMOLITIONS );
		if ( iDifficulty >= NORMAL || iOldLevel == 0 )
		{
			// Just add to perk status regardless of current perk
			iExplosiveDamage[ iPlayerIndex ] += iAddExplosiveDamage;
			CheckPerkStatus( pPlayer, DEMOLITIONS, iOldLevel );
			
			SaveData( pPlayer );
		}
		
		pPlayer.KeyValue( "$i_sdx_add_blastdmg", "0" );
	}
	
	if ( iAddRifleDamage > 0 ) // Add accumulated rifle damage?
	{
		// Only add to total if NORMAL or higher difficulty. Or if the player is a "new" one
		int iOldLevel = GetLevel( iPlayerIndex, COMMANDO );
		if ( iDifficulty >= NORMAL || iOldLevel == 0 )
		{
			// Just add to perk status regardless of current perk
			iRifleDamage[ iPlayerIndex ] += iAddRifleDamage;
			CheckPerkStatus( pPlayer, COMMANDO, iOldLevel );
			
			SaveData( pPlayer );
		}
		
		pPlayer.KeyValue( "$i_sdx_add_rifledmg", "0" );
	}
	
	if ( iAddOtherDamage > 0 ) // Add accumulated other damage?
	{
		// Only add to total if NORMAL or higher difficulty. Or if the player is a "new" one
		int iOldLevel = GetLevel( iPlayerIndex, SURVIVALIST );
		if ( iDifficulty >= NORMAL || iOldLevel == 0 )
		{
			// Just add to perk status regardless of current perk
			iOtherDamage[ iPlayerIndex ] += iAddOtherDamage;
			CheckPerkStatus( pPlayer, SURVIVALIST, iOldLevel );
			
			SaveData( pPlayer );
		}
		
		pPlayer.KeyValue( "$i_sdx_add_otherdmg", "0" );
	}
	
	if ( bReapplyPerk > 0 ) // Force the re-calculation of current perk bonuses?
	{
		// Re-apply the bonuses
		GetPerkBonus( iPlayerIndex, plPerk[ iPlayerIndex ], plLevel[ iPlayerIndex ] );
		PlayerSpawn( pPlayer );
		pPlayer.KeyValue( "$i_sdx_redo_perk", "0" );
	}
	
	/* Perk checking */
	switch ( plPerk[ iPlayerIndex ] )
	{
		case FIELD_MEDIC:
		{
			// Medkit ammo regeneration
			if ( g_Engine.time > flNextHPRegen[ iPlayerIndex ] )
			{
				// Add the extra ammo
				int iAmmoIndex = g_PlayerFuncs.GetAmmoIndex( "health" );
				pPlayer.m_rgAmmo( iAmmoIndex, pPlayer.m_rgAmmo( iAmmoIndex ) + 5 );
				
				// Clamp it to max
				pPlayer.RemoveExcessAmmo( iAmmoIndex );
				
				// Calculate next regen time
				float flTime = 3.0 - ( float( iExtraHPSpeed[ iPlayerIndex ] ) / 100.0 ) - ( 0.00125 * float( iExtraHPSpeed[ iPlayerIndex ] ) );
				flNextHPRegen[ iPlayerIndex ] = g_Engine.time + flTime;
			}
			
			// Update vars for AMXX retrieval
			pPlayer.pev.vuser2.x = float( iPoisonResist[ iPlayerIndex ] );
			pPlayer.pev.vuser2.y = float( iExtraAPGet[ iPlayerIndex ] );
			pPlayer.pev.vuser2.z = float( plPerk[ iPlayerIndex ] );
			
			break;
		}
		case BERSERKER:
		{
			// Update vars for AMXX retrieval
			pPlayer.pev.vuser2.x = float( iPoisonResist[ iPlayerIndex ] );
			pPlayer.pev.vuser2.y = float( iDamageResist[ iPlayerIndex ] );
			pPlayer.pev.vuser2.z = float( plPerk[ iPlayerIndex ] );
			pPlayer.pev.noise3 = string( iExtraBaseDamage[ iPlayerIndex ] );
			
			break;
		}
		case SHARPSHOOTER:
		{
			// Update vars for AMXX retrieval
			pPlayer.pev.vuser2.x = flExtraHSDamage[ iPlayerIndex ];
			pPlayer.pev.vuser2.z = float( plPerk[ iPlayerIndex ] );
			pPlayer.pev.noise3 = string( iExtraBaseDamage[ iPlayerIndex ] );
			
			break;
		}
		case SUPPORT_SPECIALIST:
		{
			// Update vars for AMXX retrieval
			pPlayer.pev.vuser2.x = flExtraHSDamage[ iPlayerIndex ];
			pPlayer.pev.vuser2.y = float( iDamageResist[ iPlayerIndex ] );
			pPlayer.pev.vuser2.z = float( plPerk[ iPlayerIndex ] );
			pPlayer.pev.noise3 = string( iExtraBaseDamage[ iPlayerIndex ] );
			pPlayer.pev.noise1 = string( iExtraHGDamage[ iPlayerIndex ] );
			
			break;
		}
		case DEMOLITIONS:
		{
			// Update vars for AMXX retrieval
			pPlayer.pev.vuser2.y = float( iDamageResist[ iPlayerIndex ] );
			pPlayer.pev.vuser2.z = float( plPerk[ iPlayerIndex ] );
			pPlayer.pev.noise3 = string( iExtraBaseDamage[ iPlayerIndex ] );
			
			break;
		}
		case COMMANDO:
		{
			// Update vars for AMXX retrieval
			pPlayer.pev.vuser2.y = float( iDistanceHealth[ iPlayerIndex ] );
			pPlayer.pev.vuser2.z = float( plPerk[ iPlayerIndex ] );
			pPlayer.pev.noise3 = string( iExtraBaseDamage[ iPlayerIndex ] );
			
			break;
		}
		case SURVIVALIST:
		{
			// Update vars for AMXX retrieval
			pPlayer.pev.vuser2.x = flExtraHSDamage[ iPlayerIndex ];
			pPlayer.pev.vuser2.y = float( iExtraAPGet[ iPlayerIndex ] );
			pPlayer.pev.vuser2.z = float( plPerk[ iPlayerIndex ] );
			pPlayer.pev.noise3 = string( iExtraBaseDamage[ iPlayerIndex ] );
			pPlayer.pev.noise1 = string( iPoisonResist[ iPlayerIndex ] );
			
			break;
		}
	}
	
	// Calculate movement speed
	if ( pWeapon !is null )
	{
		if ( pWeapon.pev.classname != 'weapon_minigun' ) // Ignore movement calculations if carrying minigun
		{
			// Perk?
			float flNewMoveSpeed = 1.0;
			if ( plPerk[ iPlayerIndex ] == FIELD_MEDIC )
			{
				if ( pPlayer.pev.maxspeed == 0 || pPlayer.pev.maxspeed >= flMapMaxSpeed ) // Reset
					flNewMoveSpeed = flMapMaxSpeed * ( 100.0 + float( iExtraMoveSpeed[ iPlayerIndex ] ) ) / 100.0;
				else // Weapon is forcing speed to "this" value
					flNewMoveSpeed = pPlayer.pev.maxspeed * ( 100.0 + float( iExtraMoveSpeed[ iPlayerIndex ] ) ) / 100.0;
			}
			else if ( plPerk[ iPlayerIndex ] == BERSERKER )
			{
				if ( pPlayer.pev.maxspeed == 0 || pPlayer.pev.maxspeed >= flMapMaxSpeed ) // Reset
				{
					// Player must be holding a meele weapon for the movement boost to happen
					if ( iWeaponType == MEELE )
						flNewMoveSpeed = flMapMaxSpeed * ( 100.0 + float( iExtraMoveSpeed[ iPlayerIndex ] ) ) / 100.0;
					else // Any other weapon
						flNewMoveSpeed = flMapMaxSpeed;
				}
				else // Weapon is forcing speed to "this" value
				{
					// Player must be holding a meele weapon for the movement boost to happen
					if ( iWeaponType == MEELE )
						flNewMoveSpeed = pPlayer.pev.maxspeed * ( 100.0 + float( iExtraMoveSpeed[ iPlayerIndex ] ) ) / 100.0;
					else // Any other weapon
						flNewMoveSpeed = pPlayer.pev.maxspeed;
				}
			}
			else
				flNewMoveSpeed = flMapMaxSpeed;
			
			// Do the update
			pPlayer.pev.maxspeed = flNewMoveSpeed;
		}
		else
			pPlayer.pev.maxspeed = flMapMaxSpeed / 2.0;
	}
	else
	{
		// Perk?
		float flNewMoveSpeed = 1.0;
		if ( plPerk[ iPlayerIndex ] == FIELD_MEDIC )
		{
			if ( pPlayer.pev.maxspeed == 0 || pPlayer.pev.maxspeed >= flMapMaxSpeed ) // Reset
				flNewMoveSpeed = flMapMaxSpeed * ( 100.0 + float( iExtraMoveSpeed[ iPlayerIndex ] ) ) / 100.0;
			else // Weapon is forcing speed to "this" value
				flNewMoveSpeed = pPlayer.pev.maxspeed * ( 100.0 + float( iExtraMoveSpeed[ iPlayerIndex ] ) ) / 100.0;
		}
		else
			flNewMoveSpeed = flMapMaxSpeed;
		
		// Do the update
		pPlayer.pev.maxspeed = flNewMoveSpeed;
	}
	
	// Update medkit ammo
	if ( pWeapon !is null )
	{
		// Medkit weapon type?
		if ( iWeaponType == MEDKIT )
		{
			// Save "old" ammo amount ( "new" amount is checked on PrimaryWeaponAttack() )
			pPlayer.KeyValue( "$i_sdx_hpmedic_ammo", string( pPlayer.m_rgAmmo( pWeapon.m_iPrimaryAmmoType ) ) );
		}
	}
	
	return HOOK_CONTINUE;
}

HookReturnCode PlayerSpawn( CBasePlayer@ pPlayer )
{
	int iPlayerIndex = pPlayer.entindex();
	CustomKeyvalues@ pKVD = pPlayer.GetCustomKeyvalues();
	
	// Get current perk
	switch ( plPerk[ iPlayerIndex ] )
	{
		case FIELD_MEDIC:
		{
			// Extra max armor
			pPlayer.pev.armortype = flMapMaxArmor * ( 100.0 + float( iExtraMaxAP[ iPlayerIndex ] ) ) / 100.0;
			
			// Extra medkit ammo
			int iHPIndex = g_PlayerFuncs.GetAmmoIndex( "health" );
			int iHPAmmo = int( 100.0 * ( 100.0 + float( iExtraHPAmmo[ iPlayerIndex ] ) ) / 100.0 );
			pPlayer.SetMaxAmmo( iHPIndex, iHPAmmo );
			
			// Level 5+?
			if ( plLevel[ iPlayerIndex ] >= 5 )
			{
				// Spawn with body armor
				pPlayer.TakeArmor( 9999, DMG_MEDKITHEAL, int( flMapMaxArmor ) );
			}
			
			// Level 6+?
			if ( plLevel[ iPlayerIndex ] >= 6 )
			{
				// Always spawn with medkit, if the player does not have it
				if ( pPlayer.HasNamedPlayerItem( "weapon_medkit" ) is null )
					pPlayer.GiveNamedItem( "weapon_medkit" );
			}
			
			break;
		}
		case BERSERKER:
		{
			// Level 5?
			if ( plLevel[ iPlayerIndex ] == 5 )
			{
				// Always spawn with crowbar, if the player does not have it
				if ( pPlayer.HasNamedPlayerItem( "weapon_crowbar" ) is null )
					pPlayer.GiveNamedItem( "weapon_crowbar" );
			}
			else if ( plLevel[ iPlayerIndex ] >= 6 ) // Level 6+?
			{
				// Always spawn with pipewrench, if the player does not have it
				if ( pPlayer.HasNamedPlayerItem( "weapon_pipewrench" ) is null )
					pPlayer.GiveNamedItem( "weapon_pipewrench" );
				
				// Spawn with body armor
				pPlayer.TakeArmor( 9999, DMG_MEDKITHEAL, int( flMapMaxArmor ) );
			}
			
			break;
		}
		case SHARPSHOOTER:
		{
			// Level 5?
			if ( plLevel[ iPlayerIndex ] == 5 )
			{
				// Always spawn with crossbow, if the player does not have it
				if ( pPlayer.HasNamedPlayerItem( "weapon_crossbow" ) is null )
					pPlayer.GiveNamedItem( "weapon_crossbow" );
			}
			else if ( plLevel[ iPlayerIndex ] >= 6 ) // Level 6+?
			{
				// Always spawn with sniper rifle, if the player does not have it
				if ( pPlayer.HasNamedPlayerItem( "weapon_sniperrifle" ) is null )
					pPlayer.GiveNamedItem( "weapon_sniperrifle" );
			}
			
			break;
		}
		case SUPPORT_SPECIALIST:
		{
			// Add extra Hand Grenade capacity
			int iHGIndex = g_PlayerFuncs.GetAmmoIndex( "Hand Grenade" );
			int iHGAmmo = int( 10.0 * ( 100.0 + float( iExtraHGAmmo[ iPlayerIndex ] ) ) / 100.0 );
			pPlayer.SetMaxAmmo( iHGIndex, iHGAmmo );
			
			// Support for HLC ShockRifle
			int iSRIndex = g_PlayerFuncs.GetAmmoIndex( "opfor_shocks" );
			if ( iSRIndex != -1 ) // HLC ShockRifle is active
			{
				int iSRAmmo = int( 10.0 * ( 100.0 + float( iExtraSRAmmo[ iPlayerIndex ] ) ) / 100.0 );
				pPlayer.SetMaxAmmo( iSRIndex, iSRAmmo );
			}
			
			// Level 5+?
			if ( plLevel[ iPlayerIndex ] >= 5 )
			{
				// Always spawn with shotgun, if the player does not have it
				if ( pPlayer.HasNamedPlayerItem( "weapon_shotgun" ) is null )
					pPlayer.GiveNamedItem( "weapon_shotgun" );
			}
			
			// Level 6+?
			if ( plLevel[ iPlayerIndex ] >= 6 )
			{
				// Always spawn with shock rifle, if the player does not have it
				if ( pPlayer.HasNamedPlayerItem( "weapon_shockrifle" ) is null )
					pPlayer.GiveNamedItem( "weapon_shockrifle" );
			}
			
			break;
		}
		case SURVIVALIST:
		{
			// Extra max health
			pPlayer.pev.max_health = flMapMaxHealth * ( 100.0 + float( iExtraMaxAP[ iPlayerIndex ] ) ) / 100.0;
			
			// Level 5+?
			if ( plLevel[ iPlayerIndex ] >= 5 )
			{
				// Spawn with a random weapon, no duplicates
				switch ( Math.RandomLong( 1, 6 ) )
				{
					case 1:
					{
						if ( pPlayer.HasNamedPlayerItem( "weapon_357" ) is null )
							pPlayer.GiveNamedItem( "weapon_357" );
						break;
					}
					case 2:
					{
						if ( pPlayer.HasNamedPlayerItem( "weapon_shotgun" ) is null )
							pPlayer.GiveNamedItem( "weapon_shotgun" );
						break;
					}
					case 3:
					{
						if ( pPlayer.HasNamedPlayerItem( "weapon_uzi" ) is null )
							pPlayer.GiveNamedItem( "weapon_uzi" );
						break;
					}
					case 4:
					{
						if ( pPlayer.HasNamedPlayerItem( "weapon_handgrenade" ) is null )
							pPlayer.GiveNamedItem( "weapon_handgrenade" );
						break;
					}
					case 5:
					{
						if ( pPlayer.HasNamedPlayerItem( "weapon_pipewrench" ) is null )
							pPlayer.GiveNamedItem( "weapon_pipewrench" );
						break;
					}
					case 6:
					{
						if ( pPlayer.HasNamedPlayerItem( "weapon_medkit" ) is null )
							pPlayer.GiveNamedItem( "weapon_medkit" );
						break;
					}
				}
			}
			
			// Level 6+?
			if ( plLevel[ iPlayerIndex ] >= 6 )
			{
				// Always spawn with snarks, if the player does not have it
				if ( pPlayer.HasNamedPlayerItem( "weapon_snark" ) is null )
					pPlayer.GiveNamedItem( "weapon_snark" );
			}
			
			break;
		}
		case DEMOLITIONS:
		{
			// Add extra Hand Grenade capacity
			int iHGIndex = g_PlayerFuncs.GetAmmoIndex( "Hand Grenade" );
			int iHGAmmo = int( 10.0 * ( 100.0 + float( iExtraHGAmmo[ iPlayerIndex ] ) ) / 100.0 );
			pPlayer.SetMaxAmmo( iHGIndex, iHGAmmo );
			
			// Satchel charge capacity
			int iSCIndex = g_PlayerFuncs.GetAmmoIndex( "Satchel Charge" );
			int iSCAmmo = 5;
			if ( plLevel[ iPlayerIndex ] >= 1 )
				iSCAmmo = 7 + plLevel[ iPlayerIndex ];
			pPlayer.SetMaxAmmo( iSCIndex, iSCAmmo );
			
			// Level 5+?
			if ( plLevel[ iPlayerIndex ] >= 5 )
			{
				// Always spawn with M16, if the player does not have it
				if ( pPlayer.HasNamedPlayerItem( "weapon_m16" ) is null )
					pPlayer.GiveNamedItem( "weapon_m16" );
				
				// Always give AT LEAST 2 M16 grenades, if the player does not have it
				int iGLIndex = g_PlayerFuncs.GetAmmoIndex( "ARgrenades" );
				int iGLAmmo = pPlayer.m_rgAmmo( iGLIndex );
				if ( iGLAmmo < 2 )
					pPlayer.m_rgAmmo( iGLIndex, 2 );
			}
			
			// Level 6+?
			if ( plLevel[ iPlayerIndex ] >= 6 )
			{
				// Always spawn with AT LEAST 1 satchel charge, if the player does not have it
				if ( pPlayer.HasNamedPlayerItem( "weapon_satchel" ) is null )
					pPlayer.GiveNamedItem( "weapon_satchel" );
			}
			
			break;
		}
		case COMMANDO:
		{
			// Level 5?
			if ( plLevel[ iPlayerIndex ] == 5 )
			{
				// Always spawn with MP5, if the player does not have it
				if ( pPlayer.HasNamedPlayerItem( "weapon_mp5" ) is null )
					pPlayer.GiveNamedItem( "weapon_mp5" );
			}
			else if ( plLevel[ iPlayerIndex ] >= 6 ) // Level 6+?
			{
				// Always spawn with uzi, if the player does not have it
				if ( pPlayer.HasNamedPlayerItem( "weapon_uzi" ) is null )
					pPlayer.GiveNamedItem( "weapon_uzi" );
			}
		}
	}
	
	return HOOK_CONTINUE;
}

HookReturnCode PlayerKilled( CBasePlayer@ pPlayer, CBaseEntity@ pAttacker, int iGib )
{
	int iPlayerIndex = pPlayer.entindex();
	
	// If applicable, revive the player
	if ( HasItem( iPlayerIndex, "ReviverSeed" ) )
	{
		// Force use!
		BaseItem_Use( iPlayerIndex, "ReviverSeed" );
		RemoveItem( iPlayerIndex, "ReviverSeed" );
	}
	
	return HOOK_CONTINUE;
}

HookReturnCode WeaponPrimaryAttack( CBasePlayer@ pPlayer, CBasePlayerWeapon@ pWeapon )
{
	CustomKeyvalues@ pWeaponData = pPlayer.GetCustomKeyvalues();
	CustomKeyvalues@ pSwitchData = pWeapon.GetCustomKeyvalues();
	int iPlayerIndex = pPlayer.entindex();
	
	// Don't bother with data and mod if the weapon has no ammo (if it uses ammo, that is)
	if ( pWeapon.iMaxClip() != WEAPON_NOCLIP && pWeapon.m_iClip == 0 )
		return HOOK_CONTINUE;
	
	// Gather all the mod values
	CustomKeyvalue flPunchXmin_pre( pWeaponData.GetKeyvalue( "$f_sdx_wpn_punchxmin" ) );
	CustomKeyvalue flPunchXmax_pre( pWeaponData.GetKeyvalue( "$f_sdx_wpn_punchxmax" ) );
	CustomKeyvalue flPunchYmin_pre( pWeaponData.GetKeyvalue( "$f_sdx_wpn_punchymin" ) );
	CustomKeyvalue flPunchYmax_pre( pWeaponData.GetKeyvalue( "$f_sdx_wpn_punchymax" ) );
	CustomKeyvalue flPrimaryRate_pre( pWeaponData.GetKeyvalue( "$f_sdx_wpn_primaryrate" ) );
	CustomKeyvalue iPrimaryMode_pre( pWeaponData.GetKeyvalue( "$i_sdx_wpn_primarymode" ) );
	CustomKeyvalue iIsSemiAuto_pre( pSwitchData.GetKeyvalue( "$i_sdx_wpn_issemiauto" ) );
	CustomKeyvalue iWeaponType_pre( pWeaponData.GetKeyvalue( "$i_sdx_wpn_type" ) );
	
	float flPunchXmin = flPunchXmin_pre.GetFloat();
	float flPunchXmax = flPunchXmax_pre.GetFloat();
	float flPunchYmin = flPunchYmin_pre.GetFloat();
	float flPunchYmax = flPunchYmax_pre.GetFloat();
	float flPrimaryRate = flPrimaryRate_pre.GetFloat();
	int iPrimaryMode = iPrimaryMode_pre.GetInteger();
	int iIsSemiAuto = iIsSemiAuto_pre.GetInteger();
	int iWeaponType = iWeaponType_pre.GetInteger();
	
	// Alter weapon behaviour, if we are allowed to
	if ( iPrimaryMode == 1 )
	{
		// RNG the PunchAngle, first
		float flPA_X = Math.RandomFloat( flPunchXmin, flPunchXmax );
		float flPA_Y = Math.RandomFloat( flPunchYmin, flPunchYmax );
		
		// Calculate new punchangle if perk allows it
		if ( plPerk[ iPlayerIndex ] == SHARPSHOOTER )
		{
			// Only these weapons can be "recoil reduced"
			if ( iWeaponType == PISTOL || iWeaponType == SNIPER )
			{
				flPA_X = flPA_X * ( 100.0 - float( iLowerRecoil[ iPlayerIndex ] ) ) / 100.0;
				flPA_Y = flPA_Y * ( 100.0 - float( iLowerRecoil[ iPlayerIndex ] ) ) / 100.0;
			}
		}
		else if ( plPerk[ iPlayerIndex ] == COMMANDO )
		{
			// Only these weapons can be "recoil reduced"
			if ( iWeaponType == RIFLE )
			{
				flPA_X = flPA_X * ( 100.0 - float( iLowerRecoil[ iPlayerIndex ] ) ) / 100.0;
				flPA_Y = flPA_Y * ( 100.0 - float( iLowerRecoil[ iPlayerIndex ] ) ) / 100.0;
			}
		}
		else if ( plPerk[ iPlayerIndex ] == SURVIVALIST )
		{
			// ALL weapons can be "recoil reduced"
			flPA_X = flPA_X * ( 100.0 - float( iLowerRecoil[ iPlayerIndex ] ) ) / 100.0;
			flPA_Y = flPA_Y * ( 100.0 - float( iLowerRecoil[ iPlayerIndex ] ) ) / 100.0;
		}
		
		// Now, add the extra weapon punchangle
		pPlayer.pev.punchangle.x += flPA_X;
		pPlayer.pev.punchangle.y += flPA_Y;
	}
	
	// Weapon is semi-auto?
	if ( iIsSemiAuto == 1 )
	{
		// Block nextfire until rate time, then check for button release
		pWeapon.m_flNextPrimaryAttack = pWeapon.m_flNextSecondaryAttack = pWeapon.m_flNextTertiaryAttack = g_Engine.time + 99999.0;
		
		// Calculate extra attack speed if berserker
		if ( plPerk[ iPlayerIndex ] == BERSERKER )
			flPrimaryRate = flPrimaryRate * ( 100.0 - float( iAttackSpeed[ iPlayerIndex ] ) ) / 100.0;
		
		// Don't glitch out...
		if ( flPrimaryRate < 0.06 )
			flPrimaryRate = 0.06;
		
		g_Scheduler.SetTimeout( "WeaponSemiUnlock", flPrimaryRate - 0.05, iPlayerIndex, pWeapon.entindex() );
	}
	else
	{
		// This makes me dizzy. NON-meele weapons uses ABSOLUTE values for delay (just "0.3")
		// While meele weapons uses RELATIVE values for delay (g_Engine.time + 0.3)
		// It WILL GLITCH WEAPONS if the map ends up running for too long! (3+ hours?)
		
		// Berserker perk?
		if ( plPerk[ iPlayerIndex ] == BERSERKER )
		{
			// Is this a meele weapon?
			if ( iWeaponType == MEELE )
			{
				// Calculate next attack time
				flPrimaryRate = pWeapon.m_flNextPrimaryAttack - g_Engine.time; // Remember, relative
				flPrimaryRate = flPrimaryRate * ( 100.0 - float( iAttackSpeed[ iPlayerIndex ] ) ) / 100.0;
				
				// Don't glitch out...
				if ( flPrimaryRate < 0.05 )
					flPrimaryRate = 0.05;
				
				// Set next attack time
				pWeapon.m_flNextPrimaryAttack = g_Engine.time + flPrimaryRate;
			}
		}
	}
	
	// Medic perk checking
	CustomKeyvalue iRunHeal_pre( pWeaponData.GetKeyvalue( "$i_sdx_wpn_runheal" ) );
	int iRunHeal = iRunHeal_pre.GetInteger();
	if ( iRunHeal == 1 )
	{
		int iTotalHPHeal = 0;
		
		CustomKeyvalue iOldAmmo_pre( pWeaponData.GetKeyvalue( "$i_sdx_hpmedic_ammo" ) );
		
		// Get "old" and "new" ammo amount
		int iNewAmmo = pPlayer.m_rgAmmo( pWeapon.m_iPrimaryAmmoType );
		int iOldAmmo = iOldAmmo_pre.GetInteger();
		
		// Calculate difference
		int iHealing = iNewAmmo - iOldAmmo;
		
		// If it is negative, an actual healing was involved
		if ( iHealing < 0 )
		{
			iHealing = int( abs( iHealing ) ); // why
			
			// Add total healing to perk status
			iTotalHPHeal += iHealing;
			
			// Are we using Field Medic perk?
			if ( plPerk[ iPlayerIndex ] == FIELD_MEDIC )
			{
				// Attempt to locate healing target
				TraceResult tr;
				g_EngineFuncs.MakeVectors( pPlayer.pev.v_angle );
				g_Utility.TraceHull( pPlayer.pev.origin + pPlayer.pev.view_ofs, pPlayer.pev.origin + g_Engine.v_forward * 64, dont_ignore_monsters, ( pPlayer.pev.FlagBitSet( FL_DUCKING ) ? head_hull : human_hull ), pPlayer.edict(), tr );
				if ( tr.flFraction != 1.0 && !FNullEnt( tr.pHit ) ) // "is null" does not EXCLUDE worldspawn
				{
					// Found it
					CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
					
					// Calculate extra healing
					int iExtraHealing = int( float( iHealing ) * ( 100.0 + float( iExtraHPHeal[ iPlayerIndex ] ) ) / 100.0 ) - iHealing;
					
					// Heal the target again, with the new HP
					pHit.TakeHealth( float( iExtraHealing ), DMG_MEDKITHEAL );
					
					// Also add this extra to the perk status
					iTotalHPHeal += iExtraHealing;
				}
			}
		}
		
		int iOldLevel = GetLevel( iPlayerIndex, FIELD_MEDIC );
		if ( iDifficulty >= NORMAL || iOldLevel == 0 )
		{
			iHPHealing[ iPlayerIndex ] += iTotalHPHeal;
			CheckPerkStatus( pPlayer, FIELD_MEDIC, iOldLevel );
			
			SaveData( pPlayer );
		}
		
		pPlayer.KeyValue( "$i_sdx_wpn_runheal", "0" );
	}
	
	return HOOK_CONTINUE;
}

HookReturnCode WeaponSecondaryAttack( CBasePlayer@ pPlayer, CBasePlayerWeapon@ pWeapon )
{
	CustomKeyvalues@ pWeaponData = pPlayer.GetCustomKeyvalues();
	CustomKeyvalues@ pSwitchData = pWeapon.GetCustomKeyvalues();
	int iPlayerIndex = pPlayer.entindex();
	
	// Don't bother with data and mod if the weapon has no ammo (if it uses ammo, that is)
	if ( pWeapon.iMaxClip() != WEAPON_NOCLIP && pWeapon.m_iClip == 0 )
		return HOOK_CONTINUE;
	
	// Gather all the mod values
	CustomKeyvalue flPunchXmin_pre( pWeaponData.GetKeyvalue( "$f_sdx_wpn_punchxmin" ) );
	CustomKeyvalue flPunchXmax_pre( pWeaponData.GetKeyvalue( "$f_sdx_wpn_punchxmax" ) );
	CustomKeyvalue flPunchYmin_pre( pWeaponData.GetKeyvalue( "$f_sdx_wpn_punchymin" ) );
	CustomKeyvalue flPunchYmax_pre( pWeaponData.GetKeyvalue( "$f_sdx_wpn_punchymax" ) );
	CustomKeyvalue flSecondaryRate_pre( pWeaponData.GetKeyvalue( "$f_sdx_wpn_secondaryrate" ) );
	CustomKeyvalue iSecondaryMode_pre( pWeaponData.GetKeyvalue( "$i_sdx_wpn_secondarymode" ) );
	CustomKeyvalue iIsSemiAuto_pre( pSwitchData.GetKeyvalue( "$i_sdx_wpn_issemiauto" ) );
	CustomKeyvalue iWeaponType_pre( pWeaponData.GetKeyvalue( "$i_sdx_wpn_type" ) );
	
	float flPunchXmin = flPunchXmin_pre.GetFloat();
	float flPunchXmax = flPunchXmax_pre.GetFloat();
	float flPunchYmin = flPunchYmin_pre.GetFloat();
	float flPunchYmax = flPunchYmax_pre.GetFloat();
	float flSecondaryRate = flSecondaryRate_pre.GetFloat();
	int iSecondaryMode = iSecondaryMode_pre.GetInteger();
	int iIsSemiAuto = iIsSemiAuto_pre.GetInteger();
	int iWeaponType = iWeaponType_pre.GetInteger();
	
	// Alter weapon behaviour, if we are allowed to
	if ( iSecondaryMode == 1 )
	{
		// RNG the PunchAngle, first
		float flPA_X = Math.RandomFloat( flPunchXmin, flPunchXmax );
		float flPA_Y = Math.RandomFloat( flPunchYmin, flPunchYmax );
		
		// Calculate new punchangle if perk allows it
		if ( plPerk[ iPlayerIndex ] == SHARPSHOOTER )
		{
			// Only these weapons can be "recoil reduced"
			if ( iWeaponType == PISTOL || iWeaponType == SNIPER )
			{
				flPA_X = flPA_X * ( 100.0 - float( iLowerRecoil[ iPlayerIndex ] ) ) / 100.0;
				flPA_Y = flPA_Y * ( 100.0 - float( iLowerRecoil[ iPlayerIndex ] ) ) / 100.0;
			}
		}
		else if ( plPerk[ iPlayerIndex ] == COMMANDO )
		{
			// Only these weapons can be "recoil reduced"
			if ( iWeaponType == RIFLE )
			{
				flPA_X = flPA_X * ( 100.0 - float( iLowerRecoil[ iPlayerIndex ] ) ) / 100.0;
				flPA_Y = flPA_Y * ( 100.0 - float( iLowerRecoil[ iPlayerIndex ] ) ) / 100.0;
			}
		}
		else if ( plPerk[ iPlayerIndex ] == SURVIVALIST )
		{
			// ALL weapons can be "recoil reduced"
			flPA_X = flPA_X * ( 100.0 - float( iLowerRecoil[ iPlayerIndex ] ) ) / 100.0;
			flPA_Y = flPA_Y * ( 100.0 - float( iLowerRecoil[ iPlayerIndex ] ) ) / 100.0;
		}
		
		// Now, add the extra weapon punchangle
		pPlayer.pev.punchangle.x += flPA_X;
		pPlayer.pev.punchangle.y += flPA_Y;
	}
	
	// Weapon is semi-auto?
	if ( iIsSemiAuto == 1 )
	{
		// Block nextfire until rate time, then check for button release
		pWeapon.m_flNextPrimaryAttack = pWeapon.m_flNextSecondaryAttack = pWeapon.m_flNextTertiaryAttack = g_Engine.time + 99999.0;
		
		// Calculate extra attack speed if berserker
		if ( plPerk[ iPlayerIndex ] == BERSERKER )
			flSecondaryRate = flSecondaryRate * ( 100.0 - float( iAttackSpeed[ iPlayerIndex ] ) ) / 100.0;
		
		// Don't glitch out...
		if ( flSecondaryRate < 0.06 )
			flSecondaryRate = 0.06;
		
		g_Scheduler.SetTimeout( "WeaponSemiUnlock", flSecondaryRate - 0.05, iPlayerIndex, pWeapon.entindex() );
	}
	else
	{
		// This makes me dizzy. NON-meele weapons uses ABSOLUTE values for delay (just "0.3")
		// While meele weapons uses RELATIVE values for delay (g_Engine.time + 0.3)
		// It WILL GLITCH WEAPONS if the map ends up running for too long! (3+ hours?)
		
		// Berserker perk?
		if ( plPerk[ iPlayerIndex ] == BERSERKER )
		{
			// Is this a meele weapon?
			if ( iWeaponType == MEELE )
			{
				// Calculate next attack time
				flSecondaryRate = pWeapon.m_flNextSecondaryAttack - g_Engine.time; // Remember, relative
				flSecondaryRate = flSecondaryRate * ( 100.0 - float( iAttackSpeed[ iPlayerIndex ] ) ) / 100.0;
				
				// Don't glitch out...
				if ( flSecondaryRate < 0.05 )
					flSecondaryRate = 0.05;
				
				// Set next attack time
				pWeapon.m_flNextSecondaryAttack = g_Engine.time + flSecondaryRate;
			}
		}
	}
	
	return HOOK_CONTINUE;
}

HookReturnCode WeaponTertiaryAttack( CBasePlayer@ pPlayer, CBasePlayerWeapon@ pWeapon )
{
	CustomKeyvalues@ pWeaponData = pPlayer.GetCustomKeyvalues();
	CustomKeyvalues@ pSwitchData = pWeapon.GetCustomKeyvalues();
	int iPlayerIndex = pPlayer.entindex();
	
	// Gather all the mod values
	CustomKeyvalue flPunchXmin_pre( pWeaponData.GetKeyvalue( "$f_sdx_wpn_punchxmin" ) );
	CustomKeyvalue flPunchXmax_pre( pWeaponData.GetKeyvalue( "$f_sdx_wpn_punchxmax" ) );
	CustomKeyvalue flPunchYmin_pre( pWeaponData.GetKeyvalue( "$f_sdx_wpn_punchymin" ) );
	CustomKeyvalue flPunchYmax_pre( pWeaponData.GetKeyvalue( "$f_sdx_wpn_punchymax" ) );
	CustomKeyvalue iTertiaryMode_pre( pWeaponData.GetKeyvalue( "$i_sdx_wpn_tertiarymode" ) );
	CustomKeyvalue iIsSemiAuto_pre( pSwitchData.GetKeyvalue( "$i_sdx_wpn_issemiauto" ) );
	CustomKeyvalue iWeaponType_pre( pWeaponData.GetKeyvalue( "$i_sdx_wpn_type" ) );
	
	float flPunchXmin = flPunchXmin_pre.GetFloat();
	float flPunchXmax = flPunchXmax_pre.GetFloat();
	float flPunchYmin = flPunchYmin_pre.GetFloat();
	float flPunchYmax = flPunchYmax_pre.GetFloat();
	int iTertiaryMode = iTertiaryMode_pre.GetInteger();
	int iIsSemiAuto = iIsSemiAuto_pre.GetInteger();
	int iWeaponType = iWeaponType_pre.GetInteger();
	
	// Alter weapon behaviour, if we are allowed to
	if ( iTertiaryMode == 1 )
	{
		// RNG the PunchAngle, first
		float flPA_X = Math.RandomFloat( flPunchXmin, flPunchXmax );
		float flPA_Y = Math.RandomFloat( flPunchYmin, flPunchYmax );
		
		// Calculate new punchangle if perk allows it
		if ( plPerk[ iPlayerIndex ] == SHARPSHOOTER )
		{
			// Only these weapons can be "recoil reduced"
			if ( iWeaponType == PISTOL || iWeaponType == SNIPER )
			{
				flPA_X = flPA_X * ( 100.0 - float( iLowerRecoil[ iPlayerIndex ] ) ) / 100.0;
				flPA_Y = flPA_Y * ( 100.0 - float( iLowerRecoil[ iPlayerIndex ] ) ) / 100.0;
			}
		}
		else if ( plPerk[ iPlayerIndex ] == COMMANDO )
		{
			// Only these weapons can be "recoil reduced"
			if ( iWeaponType == RIFLE )
			{
				flPA_X = flPA_X * ( 100.0 - float( iLowerRecoil[ iPlayerIndex ] ) ) / 100.0;
				flPA_Y = flPA_Y * ( 100.0 - float( iLowerRecoil[ iPlayerIndex ] ) ) / 100.0;
			}
		}
		else if ( plPerk[ iPlayerIndex ] == SURVIVALIST )
		{
			// ALL weapons can be "recoil reduced"
			flPA_X = flPA_X * ( 100.0 - float( iLowerRecoil[ iPlayerIndex ] ) ) / 100.0;
			flPA_Y = flPA_Y * ( 100.0 - float( iLowerRecoil[ iPlayerIndex ] ) ) / 100.0;
		}
		
		// Now, add the extra weapon punchangle
		pPlayer.pev.punchangle.x += flPA_X;
		pPlayer.pev.punchangle.y += flPA_Y;
	}
	else if ( iTertiaryMode == 2 )
	{
		// Not allowed, this is instead set to toggle semi-auto/full-auto (depends on weapon)
		if ( iIsSemiAuto == 1 )
		{
			pWeapon.KeyValue( "$i_sdx_wpn_issemiauto", "0" );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCENTER, "Modo de disparo NORMAL\n" );
		}
		else
		{
			pWeapon.KeyValue( "$i_sdx_wpn_issemiauto", "1" );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCENTER, "Modo de disparo SEMI-AUTOMATICO\n" );
		}
		
		//pWeapon.m_flNextTertiaryAttack = 0.5;
		pPlayer.m_flNextAttack = 0.5;
	}
	
	return HOOK_CONTINUE;
}

void WeaponSemiUnlock( const int& in iPlayerIndex, const int& in iWeaponIndex )
{
	// Get the entities
	CBaseEntity@ ePlayer = g_EntityFuncs.Instance( iPlayerIndex );
	CBaseEntity@ eWeapon = g_EntityFuncs.Instance( iWeaponIndex );
	
	// Stop if invalid
	if ( ePlayer is null || eWeapon is null )
		return;
	
	// Cast to proper class
	CBasePlayer@ pPlayer = cast< CBasePlayer@ >( ePlayer );
	CBasePlayerWeapon@ pWeapon = cast< CBasePlayerWeapon@ >( eWeapon );
	
	// Wait for attack buttons to be released
	int iButtons = pPlayer.pev.button;
	if ( !( ( iButtons & IN_ATTACK ) != 0 ) && !( ( iButtons & IN_ATTACK2 ) != 0 ) && !( ( iButtons & IN_ALT1 ) != 0 ) )
	{
		// Buttons released, allow fire again
		pWeapon.m_flNextPrimaryAttack = pWeapon.m_flNextSecondaryAttack = pWeapon.m_flNextTertiaryAttack = 0.0;
	}
	else
	{
		// Still blocked
		g_Scheduler.SetTimeout( "WeaponSemiUnlock", 0.01, iPlayerIndex, iWeaponIndex );
	}
}

void LoadWeaponData( CBasePlayer@ pPlayer, const string& in szClassname )
{
	int iWeaponType = INVALID;
	
	File@ fFile = g_FileSystem.OpenFile( PATH_WEAPON_TYPES, OpenFile::READ );
	if ( fFile !is null && fFile.IsOpen() )
	{
		int iLine = 0;
		// Get weapon type
		string line;
		while ( !fFile.EOFReached() )
		{
			fFile.ReadLine( line );
			iLine++;
			
			// Blank line or comment
			if ( line.Length() == 0 || line[ 0 ] == ';' )
				continue;
			
			array< string >@ pre_data = line.Split( ' ' );
			if ( pre_data.length() < 2 )
			{
				g_Game.AlertMessage( at_logged, "[SDX] WARNING: Bad weapon assignment in PATH_WEAPON_TYPES! (Line " + iLine + ")\n" );
				continue;
			}
			else
			{
				pre_data[ 0 ].Trim();
				pre_data[ 1 ].Trim();
				
				// Is this our weapon?
				if ( pre_data[ 0 ] == szClassname )
				{
					// It is, set weapon type for next search
					if ( pre_data[ 1 ] == 'meele' )
						iWeaponType = MEELE;
					else if ( pre_data[ 1 ] == 'pistol' )
						iWeaponType = PISTOL;
					else if ( pre_data[ 1 ] == 'shotgun' )
						iWeaponType = SHOTGUN;
					else if ( pre_data[ 1 ] == 'rifle' )
						iWeaponType = RIFLE;
					else if ( pre_data[ 1 ] == 'sniper' )
						iWeaponType = SNIPER;
					else if ( pre_data[ 1 ] == 'medkit' )
						iWeaponType = MEDKIT;
					else if ( pre_data[ 1 ] == 'other' )
						iWeaponType = OTHER;
					
					// End here
					break;
				}
			}
		}
		
		fFile.Close();
	}
	
	if ( iWeaponType == INVALID )
	{
		g_Game.AlertMessage( at_logged, "[SDX] ERROR: Invalid weapon type! (Classname: " + szClassname + ")\n" );
		
		// Non existant or invalid weapon type, assume all zero mod values
		pPlayer.KeyValue( "$f_sdx_wpn_punchxmin", "0.0" );
		pPlayer.KeyValue( "$f_sdx_wpn_punchxmax", "0.0" );
		pPlayer.KeyValue( "$f_sdx_wpn_punchymin", "0.0" );
		pPlayer.KeyValue( "$f_sdx_wpn_punchymax", "0.0" );
		pPlayer.KeyValue( "$f_sdx_wpn_primaryrate", "0.0" );
		pPlayer.KeyValue( "$f_sdx_wpn_secondaryrate", "0.0" );
		pPlayer.KeyValue( "$f_sdx_wpn_reloadtime", "0.0" );
		pPlayer.KeyValue( "$i_sdx_wpn_reloadanim_d", "0" );
		pPlayer.KeyValue( "$i_sdx_wpn_reloadanim_e", "0" );
		pPlayer.KeyValue( "$i_sdx_wpn_primarymode", "0" );
		pPlayer.KeyValue( "$i_sdx_wpn_secondarymode", "0" );
		pPlayer.KeyValue( "$i_sdx_wpn_tertiarymode", "0" );
		pPlayer.KeyValue( "$i_sdx_wpn_type", "0" );
	}
	else
	{
		// Locate weapon config path
		string szPath;
		switch ( iWeaponType )
		{
			case 1: szPath = "" + PATH_WEAPON_MEELES + szClassname + ".cfg"; break;
			case 2: szPath = "" + PATH_WEAPON_PISTOLS + szClassname + ".cfg"; break;
			case 3: szPath = "" + PATH_WEAPON_SHOTGUNS + szClassname + ".cfg"; break;
			case 4: szPath = "" + PATH_WEAPON_RIFLES + szClassname + ".cfg"; break;
			case 5: szPath = "" + PATH_WEAPON_SNIPERS + szClassname + ".cfg"; break;
			case 6: szPath = "" + PATH_WEAPON_MEDKITS + szClassname + ".cfg"; break;
			case 7: szPath = "" + PATH_WEAPON_OTHERS + szClassname + ".cfg"; break;
		}
		
		@fFile = g_FileSystem.OpenFile( szPath, OpenFile::READ );
		if ( fFile !is null && fFile.IsOpen() )
		{
			int iLine = 0;
			string line;
			while ( !fFile.EOFReached() )
			{
				fFile.ReadLine( line );
				iLine++;
				
				// Blank line or comment
				if ( line.Length() == 0 || line[ 0 ] == ';' )
					continue;
				
				array< string >@ pre_data = line.Split( '=' );
				if ( pre_data.length() < 2 )
				{
					g_Game.AlertMessage( at_logged, "[SDX] WARNING: Bad config in " + szPath + "! (Line " + iLine + ")\n" );
					continue;
				}
				else
				{
					// Read and adjust the player base weapon edits
					pre_data[ 0 ].Trim();
					pre_data[ 1 ].Trim();
					
					// Which keyvalue?
					if ( pre_data[ 0 ] == 'MIN_PUNCH_X' )
						pPlayer.KeyValue( "$f_sdx_wpn_punchxmin", pre_data[ 1 ] );
					else if ( pre_data[ 0 ] == 'MAX_PUNCH_X' )
						pPlayer.KeyValue( "$f_sdx_wpn_punchxmax", pre_data[ 1 ] );
					else if ( pre_data[ 0 ] == 'MIN_PUNCH_Y' )
						pPlayer.KeyValue( "$f_sdx_wpn_punchymin", pre_data[ 1 ] );
					else if ( pre_data[ 0 ] == 'MAX_PUNCH_Y' )
						pPlayer.KeyValue( "$f_sdx_wpn_punchymax", pre_data[ 1 ] );
					else if ( pre_data[ 0 ] == 'PRIMARY_FIRE_RATE' )
						pPlayer.KeyValue( "$f_sdx_wpn_primaryrate", pre_data[ 1 ] );
					else if ( pre_data[ 0 ] == 'SECONDARY_FIRE_RATE' )
						pPlayer.KeyValue( "$f_sdx_wpn_secondaryrate", pre_data[ 1 ] );
					else if ( pre_data[ 0 ] == 'RELOAD_TIME' )
						pPlayer.KeyValue( "$f_sdx_wpn_reloadtime", pre_data[ 1 ] );
					else if ( pre_data[ 0 ] == 'RELOAD_ANIM_DEFAULT' )
						pPlayer.KeyValue( "$i_sdx_wpn_reloadanim_d", pre_data[ 1 ] );
					else if ( pre_data[ 0 ] == 'RELOAD_ANIM_EMPTY' )
						pPlayer.KeyValue( "$i_sdx_wpn_reloadanim_e", pre_data[ 1 ] );
					else if ( pre_data[ 0 ] == 'PRIMARY_MODE' )
						pPlayer.KeyValue( "$i_sdx_wpn_primarymode", pre_data[ 1 ] );
					else if ( pre_data[ 0 ] == 'SECONDARY_MODE' )
						pPlayer.KeyValue( "$i_sdx_wpn_secondarymode", pre_data[ 1 ] );
					else if ( pre_data[ 0 ] == 'TERTIARY_MODE' )
						pPlayer.KeyValue( "$i_sdx_wpn_tertiarymode", pre_data[ 1 ] );
					else
					{
						if ( iWeaponType == MEDKIT )
						{
							if ( pre_data[ 0 ] == 'HEAL_ANIMATION' )
							{
								CBasePlayerItem@ pItem = cast< CBasePlayerItem@ >( pPlayer.m_hActiveItem.GetEntity() );
								CBasePlayerWeapon@ pWeapon = pItem.GetWeaponPtr();
								pWeapon.pev.iuser4 = atoi( pre_data[ 1 ] );
							}
						}
						else
							g_Game.AlertMessage( at_logged, "[SDX] WARNING: Unknown setting on Line " + iLine + " (" + szPath + ")\n" );
					}
					
					pPlayer.KeyValue( "$i_sdx_wpn_type", string( iWeaponType ) );
				}
			}
			
			fFile.Close();
		}
		else
		{
			g_Game.AlertMessage( at_logged, "[SDX] WARNING: Could not open file " + szPath + "\n" );
			
			// Missing file or read error. Reset to zero mod values
			pPlayer.KeyValue( "$f_sdx_wpn_punchxmin", "0.0" );
			pPlayer.KeyValue( "$f_sdx_wpn_punchxmax", "0.0" );
			pPlayer.KeyValue( "$f_sdx_wpn_punchymin", "0.0" );
			pPlayer.KeyValue( "$f_sdx_wpn_punchymax", "0.0" );
			pPlayer.KeyValue( "$f_sdx_wpn_primaryrate", "0.0" );
			pPlayer.KeyValue( "$f_sdx_wpn_secondaryrate", "0.0" );
			pPlayer.KeyValue( "$f_sdx_wpn_reloadtime", "0.0" );
			pPlayer.KeyValue( "$i_sdx_wpn_reloadanim_d", "0" );
			pPlayer.KeyValue( "$i_sdx_wpn_reloadanim_e", "0" );
			pPlayer.KeyValue( "$i_sdx_wpn_primarymode", "0" );
			pPlayer.KeyValue( "$i_sdx_wpn_secondarymode", "0" );
			pPlayer.KeyValue( "$i_sdx_wpn_tertiarymode", "0" );
			pPlayer.KeyValue( "$i_sdx_wpn_type", "0" );
		}
	}
}

// Weapon reloading
void DoReload( CBasePlayer@ pPlayer, int& in iClipSize, int& in iAnim, float& in fDelay, float& in fFrameRate )
{
	if ( pPlayer !is null )
	{
		CBasePlayerItem@ pItem = cast< CBasePlayerItem@ >( pPlayer.m_hActiveItem.GetEntity() );
		CBasePlayerWeapon@ pWeapon = pItem.GetWeaponPtr(); // Should never be NULL, considering the reload call will be hooked on an actual weapon instead of a button check
		
		if ( pPlayer.m_rgAmmo( pWeapon.m_iPrimaryAmmoType ) <= 0 )
			return;
		
		int j = Math.min( iClipSize - pWeapon.m_iClip, pPlayer.m_rgAmmo( pWeapon.m_iPrimaryAmmoType ) );	
		
		if ( j == 0 )
			return;
		
		// If the player is zooming, attempt to restore normal view
		// This will NOT work on the default SC weapons as they are client-sided
		if ( pPlayer.pev.fov != 0 )
		{
			pPlayer.pev.fov = pPlayer.m_iFOV = 0;
			pWeapon.m_fInZoom = false;
			if ( pPlayer.m_szAnimExtension == 'bowscope' )
				pPlayer.m_szAnimExtension = "bow";
			else if ( pPlayer.m_szAnimExtension == 'sniperscope' )
				pPlayer.m_szAnimExtension = "sniper";
		}
		
		pPlayer.m_flNextAttack = fDelay;
		
		pPlayer.SetAnimation( PLAYER_RELOAD );
		pWeapon.SendWeaponAnim( iAnim );
		
		// First person animation framerate cannot be altered without directly editing the model itself
		// At least third person animation works fine, so it can be used as an aproximation of the new reload time
		pItem.pev.framerate = fFrameRate;
		pPlayer.pev.framerate = fFrameRate;
		
		pWeapon.m_fInReload = true;
		
		pWeapon.m_flTimeWeaponIdle = 3.0 + fDelay;
	}
}

// Grenade thinking
// !!! Attempting to hook grenade Think() on AMXX tends to crash! (Bad edict). Manual AS check
void SUB_GrenadeThink()
{
	CBaseEntity@ pGrenade;
	@pGrenade = null; while ( ( @pGrenade = g_EntityFuncs.FindEntityByClassname( pGrenade, "grenade" ) ) !is null ) GrenadeThink( pGrenade );
	@pGrenade = null; while ( ( @pGrenade = g_EntityFuncs.FindEntityByClassname( pGrenade, "hlgrenade" ) ) !is null ) GrenadeThink( pGrenade );
}
void GrenadeThink( CBaseEntity@ pGrenade )
{
	// Check owner
	CBasePlayer@ pPlayer = cast< CBasePlayer@ >( g_EntityFuncs.Instance( pGrenade.pev.owner ) );
	if ( pPlayer !is null && pPlayer.IsConnected() )
	{
		int iPlayerIndex = pPlayer.entindex();
		
		// Only check grenades of medics
		if ( plPerk[ iPlayerIndex ] == FIELD_MEDIC )
		{
			// Thrown handgrenade ONLY
			if ( pGrenade.pev.friction == 0.8 )
			{
				// Don't let this grenade detonate on it's own, ever!
				pGrenade.pev.dmgtime = g_Engine.time + 99999.0;
				
				// Safe guard: If the player disconnects, this variable will let game know to delete this leftover entity
				pGrenade.pev.vuser1.y = 1;
				
				// Grenade is already detonated?
				if ( pGrenade.pev.vuser1.x == 0 )
				{
					// Calculate grenade velocity
					Vector vecTestVelocity = pGrenade.pev.velocity; 
					vecTestVelocity.z *= 0.45;
					
					// Grenade is touching the ground?
					if ( pGrenade.pev.FlagBitSet( FL_ONGROUND ) )
					{
						if ( vecTestVelocity.Length() <= 2 )
						{
							// Grenade is fully stopped, it's time to go off?
							if ( g_Engine.time > pGrenade.pev.fuser1 )
							{
								// Detonate
								pGrenade.pev.vuser1.x = 1;
								
								// Sound effect
								g_SoundSystem.EmitSound( pGrenade.edict(), CHAN_BODY, szHPGrenadeSound, VOL_NORM, ATTN_STATIC );
								
								// Stop moving
								pGrenade.pev.velocity = g_vecZero;
								pGrenade.pev.framerate = 0.0;
								
								// Self-remove the grenade after this many seconds
								pGrenade.pev.fuser2 = g_Engine.time + 5.0;
							}
						}
						else if ( vecTestVelocity.Length() <= 120 )
						{
							pGrenade.pev.movetype = MOVETYPE_FLY; // No gravity
							pGrenade.pev.solid = SOLID_NOT; // Don't let this grenade collide with anything else from now on
							pGrenade.pev.velocity.z = 0.0; // Stop falling
							
							// To prevent the grenade from emitting the "danger" we are instead going to lift it off the ground so it's Touch() function is never run
							Vector vecOrigin = pGrenade.pev.origin;
							vecOrigin.z += 1;
							g_EntityFuncs.SetOrigin( pGrenade, vecOrigin );
							
							// This grenade should slow down faster
							pGrenade.pev.velocity = pGrenade.pev.velocity * 0.1;
							
							// Update detonation time, it will set off on it's own after it stopped
							pGrenade.pev.fuser1 = g_Engine.time + 0.8;
						}
						else
						{
							// Slow down EVEN faster
							pGrenade.pev.velocity = pGrenade.pev.velocity * 0.4;
							
							// Update detonation time, it will set off on it's own after it stopped
							pGrenade.pev.fuser1 = g_Engine.time + 0.8;
						}
					}
					else
					{
						// pev was already altered, assume stopped and detonate
						if ( pGrenade.pev.movetype == MOVETYPE_FLY )
						{
							if ( g_Engine.time > pGrenade.pev.fuser1 )
							{
								// Detonate
								pGrenade.pev.vuser1.x = 1;
								
								// Sound effect
								g_SoundSystem.EmitSound( pGrenade.edict(), CHAN_BODY, szHPGrenadeSound, VOL_NORM, ATTN_STATIC );
								
								// Self-remove the grenade after this many seconds
								pGrenade.pev.fuser2 = g_Engine.time + 5.0;
							}
							
							// Force stop
							pGrenade.pev.velocity = g_vecZero;
							pGrenade.pev.framerate = 0.0;
						}
					}
				}
				else // Detonated grenade
				{
					// Grenade expired?
					if ( g_Engine.time > pGrenade.pev.fuser2 )
					{
						// Delete
						g_EntityFuncs.Remove( pGrenade );
						
						int iOldLevel = GetLevel( iPlayerIndex, FIELD_MEDIC );
						if ( iDifficulty >= NORMAL || iOldLevel == 0 )
						{
							// Save player data
							CheckPerkStatus( pPlayer, FIELD_MEDIC, iOldLevel );
							SaveData( pPlayer );
						}
					}
					else
					{
						Vector vecOrigin = pGrenade.pev.origin;
						
						// Smoke effect
						NetworkMessage nmEffect( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY );
						nmEffect.WriteByte( TE_FIREFIELD );
						nmEffect.WriteCoord( vecOrigin.x );
						nmEffect.WriteCoord( vecOrigin.y );
						nmEffect.WriteCoord( vecOrigin.z );
						nmEffect.WriteShort( 112 ); // Radius (Effect is a flat square)
						nmEffect.WriteShort( iHPGrenadeIndex );
						nmEffect.WriteByte( 20 ); // Count
						nmEffect.WriteByte( TEFIRE_FLAG_PLANAR | TEFIRE_FLAG_ADDITIVE ); // Flags
						nmEffect.WriteByte( 10 ); // Life
						nmEffect.End();
						
						// Locate nearby entities
						CBaseEntity@ pTarget = null;
						while ( ( @pTarget = g_EntityFuncs.FindEntityInSphere( pTarget, vecOrigin, 128, "*", "classname" ) ) !is null )
						{
							// Grenade must "see" this entity
							if ( pTarget.FVisible( pGrenade, false ) ) // false means DONT_IGNORE_GLASS
							{
								// Don't care about the map's environment (ie, func_breakable)
								if ( pTarget.IsPlayer() || pTarget.IsMonster() )
								{
									// Targets must be alive
									if ( pTarget.IsAlive() )
									{
										// Ally or enemy?
										if ( pTarget.IsPlayerAlly() || pTarget.IsPlayer() ) // Yes, because I need to repeat the check here
										{
											// Ally, heal it
											pTarget.TakeHealth( 1, DMG_MEDKITHEAL );
											
											// Add this healing to owner's perk status (if applicable)
											if ( pTarget.pev.health < pTarget.pev.max_health )
												iHPHealing[ iPlayerIndex ] += 1;
										}
										else
										{
											// Enemy, damage it
											pTarget.TakeDamage( pGrenade.pev, pPlayer.pev, 1, DMG_NERVEGAS );
										}
									}
								}
							}
						}
					}
				}
			}
		}
	}
	else
	{
		// Can't find owner, this grenade belonged to a player?
		if ( pGrenade.pev.vuser1.y == 1 )
		{
			// Disconnected player grenade, remove
			g_EntityFuncs.Remove( pGrenade );
		}
	}
}

void SUB_RenderThink()
{
	// Individual function call for each player
	for ( int i = 1; i <= g_Engine.maxClients; i++ )
	{
		CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( i );
		if ( pPlayer !is null && pPlayer.IsConnected() )
		{
			// Only if commando perk
			if ( plPerk[ i ] == COMMANDO )
				RenderThink( pPlayer );
		}
	}
}
void RenderThink( CBasePlayer@ pPlayer )
{
	int iPlayerIndex = pPlayer.entindex();
	
	// Get player's position
	Vector vecOrigin = pPlayer.pev.origin;
	
	// 1 foot = 16 units
	// 1 foot = 304.80 milimeters
	// 1 meter = 3.28 foots
	// 1 meter = 52.48 units
	
	// Get viewable distance
	float flDistance = 52.48 * float( iDistanceView[ iPlayerIndex ] );
	
	// Use this distance to locate nearby enemies
	CBaseEntity@ pMonster = null;
	while ( ( @pMonster = g_EntityFuncs.FindEntityInSphere( pMonster, vecOrigin, flDistance, "monster_*", "classname" ) ) !is null )
	{
		// Ignore already marked entities
		CustomKeyvalues@ pKVD = pPlayer.GetCustomKeyvalues();
		string szKVD = "$i_sdx_render_ed";
		szKVD += string( pMonster.entindex() );
		CustomKeyvalue iShouldRender_pre( pKVD.GetKeyvalue( szKVD ) );
		int iShouldRender = iShouldRender_pre.GetInteger();
		if ( iShouldRender == 0 )
		{
			// Entity is not easily visible?
			if ( pMonster.pev.rendermode != kRenderNormal && pMonster.pev.rendermode != kRenderGlow && pMonster.pev.renderamt < 64 )
			{
				// Mark this entity
				string szOldTargetname = pMonster.pev.targetname;
				pMonster.pev.targetname = "sdx_render_target";
				pPlayer.KeyValue( szKVD, "1" );
				
				// Fire the render
				g_EntityFuncs.FireTargets( "sdx_glb_render", pPlayer, pMonster, USE_ON );
				
				// Restore the monster's targetname
				pMonster.pev.targetname = szOldTargetname;
				
				// Check if the render should go away
				g_Scheduler.SetTimeout( "RenderThink_OFF", 0.01, pPlayer.entindex(), pMonster.entindex() );
			}
		}
	}
}
void RenderThink_OFF( const int& in iPlayerIndex, const int& in iMonsterIndex )
{
	CBaseEntity@ pPlayer = g_EntityFuncs.Instance( iPlayerIndex );
	CBaseEntity@ pMonster = g_EntityFuncs.Instance( iMonsterIndex );
	
	if ( pPlayer !is null && pMonster !is null )
	{
		// Do distance checks again
		float flDistance = 52.48 * float( iDistanceView[ iPlayerIndex ] );
		
		Vector vecOriginSelf = pPlayer.pev.origin;
		Vector vecOriginTarget = pMonster.pev.origin;
		
		if ( ( vecOriginTarget - vecOriginSelf ).Length() > flDistance )
		{
			// Undo mark
			string szOldTargetname = pMonster.pev.targetname;
			pMonster.pev.targetname = "sdx_render_target";
			
			string szKVD = "$i_sdx_render_ed";
			szKVD += string( pMonster.entindex() );
			pPlayer.KeyValue( szKVD, "0" );
			
			g_EntityFuncs.FireTargets( "sdx_glb_render", pPlayer, pMonster, USE_OFF );
			
			pMonster.pev.targetname = szOldTargetname;
		}
		else
		{
			// Keep checking
			g_Scheduler.SetTimeout( "RenderThink_OFF", 0.01, iPlayerIndex, iMonsterIndex );
		}
	}
}

// Locates all "player ally" monsters and set them on a PEV so AMXX can read it
void HELPER_SetAlly()
{
	CBaseEntity@ pMonster = null;
	while ( ( @pMonster = g_EntityFuncs.FindEntityByClassname( pMonster, "monster_*" ) ) !is null )
	{
		if ( pMonster.IsPlayerAlly() )
			pMonster.pev.iuser4 = 1;
		else
			pMonster.pev.iuser4 = 0;
	}
}

void HUDUpdate()
{
	HUDTextParams textParams;
	textParams.effect = 0;
	textParams.r2 = 255;
	textParams.g2 = 255;
	textParams.b2 = 255;
	textParams.a2 = 255;
	textParams.fadeinTime = 0.0;
	textParams.fadeoutTime = 0.0;
	textParams.holdTime = 1.0;
	textParams.fxTime = 0.0;
	
	for ( int i = 1; i <= g_Engine.maxClients; i++ )
	{
		CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( i );
		
		if ( pPlayer !is null && pPlayer.IsConnected() )
		{
			// Get player ready status
			CustomKeyvalues@ pKVD = pPlayer.GetCustomKeyvalues();
			CustomKeyvalue bIsReady_pre( pKVD.GetKeyvalue( "$i_sdx_ready" ) );
			int bIsReady = bIsReady_pre.GetInteger();
			if ( bIsReady == 0 || bIsReady == 1 && !g_SurvivalMode.IsActive() )
			{
				// Not ready, build player perk infos
				textParams.x = 1.0;
				textParams.y = -1;
				textParams.r1 = 255;
				textParams.g1 = 255;
				textParams.b1 = 255;
				textParams.a1 = 255;
				textParams.channel = 3;
				
				string szHudText = "";
				for ( int j = 1; j <= g_Engine.maxClients; j++ )
				{
					CBasePlayer@ jPlayer = g_PlayerFuncs.FindPlayerByIndex( j );
					
					if ( jPlayer !is null && jPlayer.IsConnected() )
					{
						// Game already started?
						if ( !g_SurvivalMode.IsActive() )
						{
							CustomKeyvalues@ jKVD = jPlayer.GetCustomKeyvalues();
							CustomKeyvalue o_bIsReady_pre( jKVD.GetKeyvalue( "$i_sdx_ready" ) );
							bIsReady = o_bIsReady_pre.GetInteger();
							
							// Get ready status
							if ( bIsReady == 1 )
								szHudText += "[LISTO] ";
							else
								szHudText += "[NO LISTO] ";
						}
						
						// Get player name
						szHudText += "" + jPlayer.pev.netname + " | ";
						
						// Get level
						szHudText += "Level " + plLevel[ j ];
						
						// Get perk
						switch ( plPerk[ j ] )
						{
							case FIELD_MEDIC: szHudText += " Field Medic"; break;
							case SUPPORT_SPECIALIST: szHudText += " Support Specialist"; break;
							case SHARPSHOOTER: szHudText += " Sharpshooter"; break;
							case COMMANDO: szHudText += " Commando"; break;
							case BERSERKER: szHudText += " Berserker"; break;
							case SURVIVALIST: szHudText += " ???"; break;
							case DEMOLITIONS: szHudText += " Demolitions"; break;
						}
						
						// Go on with the next player
						szHudText += "\n";
					}
				}
				
				// Print the info to the player
				g_PlayerFuncs.HudMessage( pPlayer, textParams, szHudText );
			}
			else
			{
				textParams.x = 0.01;
				textParams.y = 0.90;
				textParams.r1 = 250;
				textParams.g1 = 50;
				textParams.b1 = 25;
				textParams.a1 = 0;
				textParams.channel = 1;
				
				// In-game. Are we alive?
				if ( pPlayer.IsAlive() )
				{
					// Show self perk status
					string szHudText = "";
					
					// Get perk
					switch ( plPerk[ i ] )
					{
						case FIELD_MEDIC: szHudText += "Field Medic"; break;
						case SUPPORT_SPECIALIST: szHudText += "Support Specialist"; break;
						case SHARPSHOOTER: szHudText += "Sharpshooter"; break;
						case COMMANDO: szHudText += "Commando"; break;
						case BERSERKER: szHudText += "Berserker"; break;
						case SURVIVALIST: szHudText += "???"; break;
						case DEMOLITIONS: szHudText += "Demolitions"; break;
					}
					
					// Get level
					szHudText += " | Level " + plLevel[ i ];
					
					// Show the info
					g_PlayerFuncs.HudMessage( pPlayer, textParams, szHudText );
				}
				else
				{
					// Not alive but observing another player?
					CBaseEntity@ pTarget = pPlayer.GetObserver().GetObserverTarget();
					if ( pTarget !is null && pPlayer.pev.iuser1 != OBS_ROAMING )
					{
						// Gather the info of this other player
						string szHudText = "";
						
						// Get perk
						switch ( plPerk[ pTarget.entindex() ] )
						{
							case FIELD_MEDIC: szHudText += "Field Medic"; break;
							case SUPPORT_SPECIALIST: szHudText += "Support Specialist"; break;
							case SHARPSHOOTER: szHudText += "Sharpshooter"; break;
							case COMMANDO: szHudText += "Commando"; break;
							case BERSERKER: szHudText += "Berserker"; break;
							case SURVIVALIST: szHudText += "???"; break;
							case DEMOLITIONS: szHudText += "Demolitions"; break;
						}
						
						// Get level
						szHudText += " | Level " + plLevel[ pTarget.entindex() ];
						
						// Show the info
						g_PlayerFuncs.HudMessage( pPlayer, textParams, szHudText );
					}
				}
			}
			
			// Go to Mystery Gift handler, if player has it unlocked
			if ( bHasMGAccess[ i ] == 1 )
				MysteryGift_Handler( pPlayer );
		}
	}
}

HookReturnCode ClientPutInServer( CBasePlayer@ pPlayer )
{
	int iPlayerIndex = pPlayer.entindex();
	
	// I'm just paranoid, for now...
	plPerk[ iPlayerIndex ] = NONE;
	plLevel[ iPlayerIndex ] = -1;
	
	iHPHealing[ iPlayerIndex ] = 0;
	iMeeleDamage[ iPlayerIndex ] = 0;
	iHeadShots[ iPlayerIndex ] = 0;
	iShotgunDamage[ iPlayerIndex ] = 0;
	iExplosiveDamage[ iPlayerIndex ] = 0;
	iRifleDamage[ iPlayerIndex ] = 0;
	iOtherDamage[ iPlayerIndex ] = 0;
	
	iExtraHPHeal[ iPlayerIndex ] = 0;
	iExtraHPSpeed[ iPlayerIndex ] = 0;
	iPoisonResist[ iPlayerIndex ] = 0;
	iExtraAPGet[ iPlayerIndex ] = 0;
	iExtraMaxAP[ iPlayerIndex ] = 0;
	iExtraMoveSpeed[ iPlayerIndex ] = 0;
	iExtraHPAmmo[ iPlayerIndex ] = 0;
	iDamageResist[ iPlayerIndex ] = 0;
	iAttackSpeed[ iPlayerIndex ] = 0;
	iExtraBaseDamage[ iPlayerIndex ] = 0;
	flExtraHSDamage[ iPlayerIndex ] = 0.0;
	iLowerRecoil[ iPlayerIndex ] = 0;
	iReloadSpeed[ iPlayerIndex ] = 0;
	iExtraSRAmmo[ iPlayerIndex ] = 0;
	iExtraHGAmmo[ iPlayerIndex ] = 0;
	iExtraHGDamage[ iPlayerIndex ] = 0;
	iDistanceHealth[ iPlayerIndex ] = 0;
	iDistanceView[ iPlayerIndex ] = 0;
	
	flNextHPRegen[ iPlayerIndex ] = 0.0;
	bDoNotSave[ iPlayerIndex ] = true;
	bHasMGAccess[ iPlayerIndex ] = 0;
	
	// Load player data
	bool bDummy = false; // Do we have to start with this shit again?
	int iError = 0;
	LoadData( pPlayer, iError );
	
	// Failsafe: Did data truly load successfully?
	if ( iError == 0 )
	{
		// Get perk bonus and init player
		GetPerkBonus( iPlayerIndex, plPerk[ iPlayerIndex ], plLevel[ iPlayerIndex ] );
		g_Scheduler.SetTimeout( "PlayerIntro", 3.0, iPlayerIndex, false );
	}
	else
		g_Scheduler.SetTimeout( "PlayerLoadFail", 3.0, iPlayerIndex, iError );
	
	return HOOK_CONTINUE;
}

HookReturnCode ClientDisconnect( CBasePlayer@ pPlayer )
{
	int iPlayerIndex = pPlayer.entindex();
	
	plPerk[ iPlayerIndex ] = NONE;
	plLevel[ iPlayerIndex ] = -1;
	
	iHPHealing[ iPlayerIndex ] = 0;
	iMeeleDamage[ iPlayerIndex ] = 0;
	iHeadShots[ iPlayerIndex ] = 0;
	iShotgunDamage[ iPlayerIndex ] = 0;
	iExplosiveDamage[ iPlayerIndex ] = 0;
	iRifleDamage[ iPlayerIndex ] = 0;
	iOtherDamage[ iPlayerIndex ] = 0;
	
	iExtraHPHeal[ iPlayerIndex ] = 0;
	iExtraHPSpeed[ iPlayerIndex ] = 0;
	iPoisonResist[ iPlayerIndex ] = 0;
	iExtraAPGet[ iPlayerIndex ] = 0;
	iExtraMaxAP[ iPlayerIndex ] = 0;
	iExtraMoveSpeed[ iPlayerIndex ] = 0;
	iExtraHPAmmo[ iPlayerIndex ] = 0;
	iDamageResist[ iPlayerIndex ] = 0;
	iAttackSpeed[ iPlayerIndex ] = 0;
	iExtraBaseDamage[ iPlayerIndex ] = 0;
	flExtraHSDamage[ iPlayerIndex ] = 0.0;
	iLowerRecoil[ iPlayerIndex ] = 0;
	iReloadSpeed[ iPlayerIndex ] = 0;
	iExtraSRAmmo[ iPlayerIndex ] = 0;
	iExtraHGAmmo[ iPlayerIndex ] = 0;
	iExtraHGDamage[ iPlayerIndex ] = 0;
	iDistanceHealth[ iPlayerIndex ] = 0;
	iDistanceView[ iPlayerIndex ] = 0;
	
	flNextHPRegen[ iPlayerIndex ] = 0.0;
	bDoNotSave[ iPlayerIndex ] = false;
	bHasMGAccess[ iPlayerIndex ] = 0;
	
	return HOOK_CONTINUE;
}

// Calculate perk bonuses
void GetPerkBonus( const int& in iPlayerIndex, const int& in iPerk, const int& in iLevel )
{
	// First reset all perk bonus vars
	iExtraHPHeal[ iPlayerIndex ] = 0;
	iExtraHPSpeed[ iPlayerIndex ] = 0;
	iPoisonResist[ iPlayerIndex ] = 0;
	iExtraAPGet[ iPlayerIndex ] = 0;
	iExtraMaxAP[ iPlayerIndex ] = 0;
	iExtraMoveSpeed[ iPlayerIndex ] = 0;
	iExtraHPAmmo[ iPlayerIndex ] = 0;
	iDamageResist[ iPlayerIndex ] = 0;
	iAttackSpeed[ iPlayerIndex ] = 0;
	iExtraBaseDamage[ iPlayerIndex ] = 0;
	flExtraHSDamage[ iPlayerIndex ] = 0.0;
	iLowerRecoil[ iPlayerIndex ] = 0;
	iReloadSpeed[ iPlayerIndex ] = 0;
	iExtraSRAmmo[ iPlayerIndex ] = 0;
	iExtraHGAmmo[ iPlayerIndex ] = 0;
	iExtraHGDamage[ iPlayerIndex ] = 0;
	iDistanceHealth[ iPlayerIndex ] = 0;
	iDistanceView[ iPlayerIndex ] = 0;
	
	// Now get 'em
	switch ( iPerk )
	{
		case FIELD_MEDIC:
		{
			if ( iLevel == 0 )
			{
				iExtraAPGet[ iPlayerIndex ] = 10;
				iExtraHPSpeed[ iPlayerIndex ] = 10;
				iExtraHPHeal[ iPlayerIndex ] = 10;
				iPoisonResist[ iPlayerIndex ] = 10;
			}
			else if ( iLevel == 1 )
			{
				iExtraHPAmmo[ iPlayerIndex ] = 20;
				iExtraMaxAP[ iPlayerIndex ] = 10;
				iExtraAPGet[ iPlayerIndex ] = 20;
				iExtraHPSpeed[ iPlayerIndex ] = 25;
				iExtraHPHeal[ iPlayerIndex ] = 25;
				iPoisonResist[ iPlayerIndex ] = 25;
			}
			else if ( iLevel == 2 )
			{
				iExtraHPAmmo[ iPlayerIndex ] = 40;
				iExtraMaxAP[ iPlayerIndex ] = 20;
				iExtraAPGet[ iPlayerIndex ] = 30;
				iExtraHPSpeed[ iPlayerIndex ] = 50;
				iExtraHPHeal[ iPlayerIndex ] = 25;
				iPoisonResist[ iPlayerIndex ] = 50;
				iExtraMoveSpeed[ iPlayerIndex ] = 5;
			}
			else if ( iLevel == 3 )
			{
				iExtraHPAmmo[ iPlayerIndex ] = 60;
				iExtraMaxAP[ iPlayerIndex ] = 30;
				iExtraAPGet[ iPlayerIndex ] = 40;
				iExtraHPSpeed[ iPlayerIndex ] = 75;
				iExtraHPHeal[ iPlayerIndex ] = 50;
				iPoisonResist[ iPlayerIndex ] = 50;
				iExtraMoveSpeed[ iPlayerIndex ] = 10;
			}
			else if ( iLevel == 4 )
			{
				iExtraHPAmmo[ iPlayerIndex ] = 80;
				iExtraMaxAP[ iPlayerIndex ] = 40;
				iExtraAPGet[ iPlayerIndex ] = 50;
				iExtraHPSpeed[ iPlayerIndex ] = 100;
				iExtraHPHeal[ iPlayerIndex ] = 50;
				iPoisonResist[ iPlayerIndex ] = 50;
				iExtraMoveSpeed[ iPlayerIndex ] = 15;
			}
			else if ( iLevel == 5 )
			{
				iExtraHPAmmo[ iPlayerIndex ] = 100;
				iExtraMaxAP[ iPlayerIndex ] = 50;
				iExtraAPGet[ iPlayerIndex ] = 60;
				iExtraHPSpeed[ iPlayerIndex ] = 150;
				iExtraHPHeal[ iPlayerIndex ] = 50;
				iPoisonResist[ iPlayerIndex ] = 75;
				iExtraMoveSpeed[ iPlayerIndex ] = 20;
			}
			else if ( iLevel == 6 )
			{
				iExtraHPAmmo[ iPlayerIndex ] = 100;
				iExtraMaxAP[ iPlayerIndex ] = 75;
				iExtraAPGet[ iPlayerIndex ] = 70;
				iExtraHPSpeed[ iPlayerIndex ] = 200;
				iExtraHPHeal[ iPlayerIndex ] = 75;
				iPoisonResist[ iPlayerIndex ] = 75;
				iExtraMoveSpeed[ iPlayerIndex ] = 25;
			}
			break;
		}
		case SUPPORT_SPECIALIST:
		{
			if ( iLevel == 0 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 10;
				flExtraHSDamage[ iPlayerIndex ] = 1.0;
				iExtraSRAmmo[ iPlayerIndex ] = 10;
			}
			else if ( iLevel == 1 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 10;
				flExtraHSDamage[ iPlayerIndex ] = 1.8;
				iDamageResist[ iPlayerIndex ] = 15;
				iExtraHGAmmo[ iPlayerIndex ] = 20;
				iExtraHGDamage[ iPlayerIndex ] = 5;
				iExtraSRAmmo[ iPlayerIndex ] = 25;
			}
			else if ( iLevel == 2 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 20;
				flExtraHSDamage[ iPlayerIndex ] = 3.6;
				iDamageResist[ iPlayerIndex ] = 20;
				iExtraHGAmmo[ iPlayerIndex ] = 40;
				iExtraHGDamage[ iPlayerIndex ] = 10;
				iExtraSRAmmo[ iPlayerIndex ] = 50;
			}
			else if ( iLevel == 3 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 30;
				flExtraHSDamage[ iPlayerIndex ] = 5.4;
				iDamageResist[ iPlayerIndex ] = 25;
				iExtraHGAmmo[ iPlayerIndex ] = 60;
				iExtraHGDamage[ iPlayerIndex ] = 20;
				iExtraSRAmmo[ iPlayerIndex ] = 75;
			}
			else if ( iLevel == 4 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 40;
				flExtraHSDamage[ iPlayerIndex ] = 7.2;
				iDamageResist[ iPlayerIndex ] = 30;
				iExtraHGAmmo[ iPlayerIndex ] = 80;
				iExtraHGDamage[ iPlayerIndex ] = 30;
				iExtraSRAmmo[ iPlayerIndex ] = 100;
			}
			else if ( iLevel == 5 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 50;
				flExtraHSDamage[ iPlayerIndex ] = 9.0;
				iDamageResist[ iPlayerIndex ] = 50;
				iExtraHGAmmo[ iPlayerIndex ] = 100;
				iExtraHGDamage[ iPlayerIndex ] = 40;
				iExtraSRAmmo[ iPlayerIndex ] = 150;
			}
			else if ( iLevel == 6 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 60;
				flExtraHSDamage[ iPlayerIndex ] = 9.0;
				iDamageResist[ iPlayerIndex ] = 60;
				iExtraHGAmmo[ iPlayerIndex ] = 120;
				iExtraHGDamage[ iPlayerIndex ] = 50;
				iExtraSRAmmo[ iPlayerIndex ] = 150;
			}
			break;
		}
		case SHARPSHOOTER:
		{
			if ( iLevel == 0 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 5;
				flExtraHSDamage[ iPlayerIndex ] = 0.5;
			}
			else if ( iLevel == 1 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 10;
				iLowerRecoil[ iPlayerIndex ] = 25;
				iReloadSpeed[ iPlayerIndex ] = 10;
				flExtraHSDamage[ iPlayerIndex ] = 1.0;
			}
			else if ( iLevel == 2 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 15;
				iLowerRecoil[ iPlayerIndex ] = 50;
				iReloadSpeed[ iPlayerIndex ] = 20;
				flExtraHSDamage[ iPlayerIndex ] = 2.0;
			}
			else if ( iLevel == 3 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 20;
				iLowerRecoil[ iPlayerIndex ] = 75;
				iReloadSpeed[ iPlayerIndex ] = 30;
				flExtraHSDamage[ iPlayerIndex ] = 3.0;
			}
			else if ( iLevel == 4 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 30;
				iLowerRecoil[ iPlayerIndex ] = 75;
				iReloadSpeed[ iPlayerIndex ] = 40;
				flExtraHSDamage[ iPlayerIndex ] = 4.0;
			}
			else if ( iLevel == 5 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 50;
				iLowerRecoil[ iPlayerIndex ] = 75;
				iReloadSpeed[ iPlayerIndex ] = 50;
				flExtraHSDamage[ iPlayerIndex ] = 5.0;
			}
			else if ( iLevel == 6 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 60;
				iLowerRecoil[ iPlayerIndex ] = 75;
				iReloadSpeed[ iPlayerIndex ] = 60;
				flExtraHSDamage[ iPlayerIndex ] = 5.0;
			}
			break;
		}
		case COMMANDO:
		{
			if ( iLevel == 0 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 5;
				iLowerRecoil[ iPlayerIndex ] = 5;
				iReloadSpeed[ iPlayerIndex ] = 5;
				iDistanceView[ iPlayerIndex ] = 4;
			}
			else if ( iLevel == 1 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 10;
				iLowerRecoil[ iPlayerIndex ] = 10;
				iReloadSpeed[ iPlayerIndex ] = 10;
				iDistanceView[ iPlayerIndex ] = 8;
				iDistanceHealth[ iPlayerIndex ] = 4;
			}
			else if ( iLevel == 2 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 20;
				iLowerRecoil[ iPlayerIndex ] = 15;
				iReloadSpeed[ iPlayerIndex ] = 15;
				iDistanceView[ iPlayerIndex ] = 10;
				iDistanceHealth[ iPlayerIndex ] = 7;
			}
			else if ( iLevel == 3 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 30;
				iLowerRecoil[ iPlayerIndex ] = 20;
				iReloadSpeed[ iPlayerIndex ] = 20;
				iDistanceView[ iPlayerIndex ] = 12;
				iDistanceHealth[ iPlayerIndex ] = 10;
			}
			else if ( iLevel == 4 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 40;
				iLowerRecoil[ iPlayerIndex ] = 30;
				iReloadSpeed[ iPlayerIndex ] = 25;
				iDistanceView[ iPlayerIndex ] = 14;
				iDistanceHealth[ iPlayerIndex ] = 13;
			}
			else if ( iLevel == 5 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 50;
				iLowerRecoil[ iPlayerIndex ] = 30;
				iReloadSpeed[ iPlayerIndex ] = 30;
				iDistanceView[ iPlayerIndex ] = 16;
				iDistanceHealth[ iPlayerIndex ] = 16;
			}
			else if ( iLevel == 6 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 50;
				iLowerRecoil[ iPlayerIndex ] = 40;
				iReloadSpeed[ iPlayerIndex ] = 35;
				iDistanceView[ iPlayerIndex ] = 16;
				iDistanceHealth[ iPlayerIndex ] = 16;
			}
			break;
		}
		case BERSERKER:
		{
			if ( iLevel == 0 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 10;
				iExtraMoveSpeed[ iPlayerIndex ] = 5;
				iPoisonResist[ iPlayerIndex ] = 10;
			}
			else if ( iLevel == 1 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 20;
				iAttackSpeed[ iPlayerIndex ] = 5;
				iExtraMoveSpeed[ iPlayerIndex ] = 10;
				iPoisonResist[ iPlayerIndex ] = 25;
				iDamageResist[ iPlayerIndex ] = 5;
			}
			else if ( iLevel == 2 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 40;
				iAttackSpeed[ iPlayerIndex ] = 10;
				iExtraMoveSpeed[ iPlayerIndex ] = 15;
				iPoisonResist[ iPlayerIndex ] = 35;
				iDamageResist[ iPlayerIndex ] = 10;
			}
			else if ( iLevel == 3 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 60;
				iAttackSpeed[ iPlayerIndex ] = 10;
				iExtraMoveSpeed[ iPlayerIndex ] = 20;
				iPoisonResist[ iPlayerIndex ] = 50;
				iDamageResist[ iPlayerIndex ] = 15;
			}
			else if ( iLevel == 4 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 80;
				iAttackSpeed[ iPlayerIndex ] = 15;
				iExtraMoveSpeed[ iPlayerIndex ] = 20;
				iPoisonResist[ iPlayerIndex ] = 65;
				iDamageResist[ iPlayerIndex ] = 20;
			}
			else if ( iLevel == 5 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 100;
				iAttackSpeed[ iPlayerIndex ] = 20;
				iExtraMoveSpeed[ iPlayerIndex ] = 20;
				iPoisonResist[ iPlayerIndex ] = 75;
				iDamageResist[ iPlayerIndex ] = 30;
			}
			else if ( iLevel == 6 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 100;
				iAttackSpeed[ iPlayerIndex ] = 25;
				iExtraMoveSpeed[ iPlayerIndex ] = 30;
				iPoisonResist[ iPlayerIndex ] = 80;
				iDamageResist[ iPlayerIndex ] = 40;
			}
			break;
		}
		case SURVIVALIST:
		{
			if ( iLevel == 0 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 5;
				flExtraHSDamage[ iPlayerIndex ] = 0.5;
				iExtraMaxAP[ iPlayerIndex ] = 10;
			}
			else if ( iLevel == 1 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 10;
				flExtraHSDamage[ iPlayerIndex ] = 1.0;
				iLowerRecoil[ iPlayerIndex ] = 5;
				iExtraMaxAP[ iPlayerIndex ] = 15;
				iExtraAPGet[ iPlayerIndex ] = 10;
				iPoisonResist[ iPlayerIndex ] = iLevel;
			}
			else if ( iLevel == 2 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 10;
				flExtraHSDamage[ iPlayerIndex ] = 1.5;
				iLowerRecoil[ iPlayerIndex ] = 5;
				iExtraMaxAP[ iPlayerIndex ] = 15;
				iExtraAPGet[ iPlayerIndex ] = 20;
				iPoisonResist[ iPlayerIndex ] = iLevel;
			}
			else if ( iLevel == 3 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 20;
				flExtraHSDamage[ iPlayerIndex ] = 2.0;
				iLowerRecoil[ iPlayerIndex ] = 10;
				iExtraMaxAP[ iPlayerIndex ] = 20;
				iExtraAPGet[ iPlayerIndex ] = 20;
				iPoisonResist[ iPlayerIndex ] = iLevel;
			}
			else if ( iLevel == 4 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 20;
				flExtraHSDamage[ iPlayerIndex ] = 2.5;
				iLowerRecoil[ iPlayerIndex ] = 10;
				iExtraMaxAP[ iPlayerIndex ] = 20;
				iExtraAPGet[ iPlayerIndex ] = 30;
				iPoisonResist[ iPlayerIndex ] = iLevel;
			}
			else if ( iLevel == 5 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 30;
				flExtraHSDamage[ iPlayerIndex ] = 3.0;
				iLowerRecoil[ iPlayerIndex ] = 10;
				iExtraMaxAP[ iPlayerIndex ] = 25;
				iExtraAPGet[ iPlayerIndex ] = 40;
				iPoisonResist[ iPlayerIndex ] = iLevel;
			}
			else if ( iLevel == 6 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 30;
				flExtraHSDamage[ iPlayerIndex ] = 3.5;
				iLowerRecoil[ iPlayerIndex ] = 15;
				iExtraMaxAP[ iPlayerIndex ] = 25;
				iExtraAPGet[ iPlayerIndex ] = 50;
				iPoisonResist[ iPlayerIndex ] = iLevel;
			}
			break;
		}
		case DEMOLITIONS:
		{
			if ( iLevel == 0 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 5;
				iDamageResist[ iPlayerIndex ] = 25;
			}
			else if ( iLevel == 1 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 10;
				iDamageResist[ iPlayerIndex ] = 30;
				iExtraHGAmmo[ iPlayerIndex ] = 20;
			}
			else if ( iLevel == 2 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 20;
				iDamageResist[ iPlayerIndex ] = 35;
				iExtraHGAmmo[ iPlayerIndex ] = 40;
			}
			else if ( iLevel == 3 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 30;
				iDamageResist[ iPlayerIndex ] = 40;
				iExtraHGAmmo[ iPlayerIndex ] = 60;
			}
			else if ( iLevel == 4 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 40;
				iDamageResist[ iPlayerIndex ] = 45;
				iExtraHGAmmo[ iPlayerIndex ] = 80;
			}
			else if ( iLevel == 5 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 50;
				iDamageResist[ iPlayerIndex ] = 50;
				iExtraHGAmmo[ iPlayerIndex ] = 100;
			}
			else if ( iLevel == 6 )
			{
				iExtraBaseDamage[ iPlayerIndex ] = 60;
				iDamageResist[ iPlayerIndex ] = 55;
				iExtraHGAmmo[ iPlayerIndex ] = 120;
			}
			break;
		}
	}
}

void PerkInfo( const int& in iPlayerIndex )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null && pPlayer.IsConnected() )
	{
		// Save old perk
		int iOldPerk = plPerk[ iPlayerIndex ];
		
		// Get perk to view
		CustomKeyvalues@ pKVD = pPlayer.GetCustomKeyvalues();
		CustomKeyvalue iPerk_pre( pKVD.GetKeyvalue( "$i_sdx_perk_info" ) );
		int iPerk = iPerk_pre.GetInteger();
		
		// Show current perk?
		if ( iPerk == 0 )
			iPerk = plPerk[ iPlayerIndex ];
		
		// Re-calculate perk bonuses
		plLevel[ iPlayerIndex ] = GetLevel( iPlayerIndex, iPerk );
		GetPerkBonus( iPlayerIndex, iPerk, plLevel[ iPlayerIndex ] );
		
		// Build MOTD window text
		string szText = "";
		switch ( iPerk )
		{
			case FIELD_MEDIC:
			{
				szText += "Level " + GetLevel( iPlayerIndex, FIELD_MEDIC ) + " Field Medic\n\n\n\n";
				
				if ( iExtraHPHeal[ iPlayerIndex ] > 0 )
					szText += "+" + iExtraHPHeal[ iPlayerIndex ] + "% Potencia de curacion de Medkit\n";
				if ( iExtraHPSpeed[ iPlayerIndex ] > 0 )
					szText += "+" + iExtraHPSpeed[ iPlayerIndex ] + "% Velocidad de recarga de Medkit\n";
				if ( iExtraHPAmmo[ iPlayerIndex ] > 0 )
					szText += "+" + iExtraHPAmmo[ iPlayerIndex ] + "% Capacidad maxima de Medkit\n";
				if ( iPoisonResist[ iPlayerIndex ] > 0 )
					szText += "-" + iPoisonResist[ iPlayerIndex ] + "% a Danios de Infecciones\n";
				if ( iExtraAPGet[ iPlayerIndex ] > 0 )
					szText += "+" + iExtraAPGet[ iPlayerIndex ] + "% Armadura extra de Baterias\n";
				if ( iExtraMaxAP[ iPlayerIndex ] > 0 )
					szText += "+" + iExtraMaxAP[ iPlayerIndex ] + "% Capacidad maxima de Armadura\n";
				if ( iExtraMoveSpeed[ iPlayerIndex ] > 0 )
					szText += "+" + iExtraMoveSpeed[ iPlayerIndex ] + "% Velocidad de Movimiento\n";
				if ( plLevel[ iPlayerIndex ] >= 5 )
					szText += "Empezar con Medkit\n";
				if ( plLevel[ iPlayerIndex ] >= 6 )
					szText += "Empezar con Armadura\n";
				szText += "Las Handgrenades curan a aliados y lastiman enemigos\n";
				break;
			}
			case SUPPORT_SPECIALIST:
			{
				szText += "Level " + GetLevel( iPlayerIndex, SUPPORT_SPECIALIST ) + " Support Specialist\n\n\n\n";
				
				if ( iExtraBaseDamage[ iPlayerIndex ] > 0 )
					szText += "+" + iExtraBaseDamage[ iPlayerIndex ] + "% Danio base con Escopetas\n";
				if ( flExtraHSDamage[ iPlayerIndex ] > 0.0 )
					szText += "+" + fl2Decimals( flExtraHSDamage[ iPlayerIndex ] ) + "% Danio extra de HeadShot con Escopetas\n";
				if ( iExtraSRAmmo[ iPlayerIndex ] > 0 )
					szText += "+" + iExtraSRAmmo[ iPlayerIndex ] + "% Capacidad maxima de Shock Rifle\n";
				if ( iDamageResist[ iPlayerIndex ] > 0 )
					szText += "-" + iDamageResist[ iPlayerIndex ] + "% a Danios por caida\n";
				if ( iExtraHGAmmo[ iPlayerIndex ] > 0 )
					szText += "+" + iExtraHGAmmo[ iPlayerIndex ] + "% Capacidad maxima de HandGrenades\n";
				if ( iExtraHGDamage[ iPlayerIndex ] > 0 )
					szText += "+" + iExtraHGDamage[ iPlayerIndex ] + "% Danio base con HandGrenades\n";
				if ( plLevel[ iPlayerIndex ] >= 5 )
					szText += "Empezar con Escopeta\n";
				if ( plLevel[ iPlayerIndex ] >= 6 )
					szText += "Empezar con Shock Rifle\n";
				break;
			}
			case SHARPSHOOTER:
			{
				szText += "Level " + GetLevel( iPlayerIndex, SHARPSHOOTER ) + " Sharpshooter\n\n\n\n";
				
				if ( iExtraBaseDamage[ iPlayerIndex ] > 0 )
					szText += "+" + iExtraBaseDamage[ iPlayerIndex ] + "% Danio base con Pistolas, Ballestas y Francotiradores\n";
				if ( flExtraHSDamage[ iPlayerIndex ] > 0.0 )
					szText += "+" + fl2Decimals( flExtraHSDamage[ iPlayerIndex ] ) + "% Danio extra de HeadShot con Pistolas, Ballestas y Francotiradores\n";
				if ( iLowerRecoil[ iPlayerIndex ] > 0 )
					szText += "-" + iLowerRecoil[ iPlayerIndex ] + "% Recoil con Pistolas, Ballestas y Francotiradores\n";
				if ( iReloadSpeed[ iPlayerIndex ] > 0 )
					szText += "+" + iReloadSpeed[ iPlayerIndex ] + "% Velocidad de recarga con Pistolas, Ballestas y Francotiradores\n";
				if ( plLevel[ iPlayerIndex ] == 5 )
					szText += "Empezar con Ballesta\n";
				else if ( plLevel[ iPlayerIndex ] >= 6 )
					szText += "Empezar con Sniper Rifle\n";
				break;
			}
			case COMMANDO:
			{
				szText += "Level " + GetLevel( iPlayerIndex, COMMANDO ) + " Commando\n\n\n\n";
				
				if ( iExtraBaseDamage[ iPlayerIndex ] > 0 )
					szText += "+" + iExtraBaseDamage[ iPlayerIndex ] + "% Danio base con Rifles y Uzi\n";
				if ( iLowerRecoil[ iPlayerIndex ] > 0 )
					szText += "-" + iLowerRecoil[ iPlayerIndex ] + "% Recoil con Rifles y Uzi\n";
				if ( iReloadSpeed[ iPlayerIndex ] > 0 )
					szText += "+" + iReloadSpeed[ iPlayerIndex ] + "% Velocidad de recarga con todas las armas (Salvo Escopetas)\n";
				if ( iDistanceView[ iPlayerIndex ] > 0 )
					szText += "Puede ver monstruos poco visibles desde " + iDistanceView[ iPlayerIndex ] + " metros\n";
				if ( iDistanceHealth[ iPlayerIndex ] > 0 )
					szText += "Puede ver la vida del enemigo desde " + iDistanceHealth[ iPlayerIndex ] + " metros\n";
				if ( plLevel[ iPlayerIndex ] == 5 )
					szText += "Empezar con Rifle MP5\n";
				else if ( plLevel[ iPlayerIndex ] >= 6 )
					szText += "Empezar con Uzi\n";
				break;
			}
			case BERSERKER:
			{
				szText += "Level " + GetLevel( iPlayerIndex, BERSERKER ) + " Berserker\n\n\n\n";
				
				if ( iExtraBaseDamage[ iPlayerIndex ] > 0 )
					szText += "+" + iExtraBaseDamage[ iPlayerIndex ] + "% Danio base con Armas cuerpo a cuerpo\n";
				if ( iExtraMoveSpeed[ iPlayerIndex ] > 0 )
					szText += "+" + iExtraMoveSpeed[ iPlayerIndex ] + "% Velocidad de Movimiento con Armas cuerpo a cuerpo\n";
				if ( iPoisonResist[ iPlayerIndex ] > 0 )
					szText += "-" + iPoisonResist[ iPlayerIndex ] + "% a Danios de Infecciones\n";
				if ( iAttackSpeed[ iPlayerIndex ] > 0 )
					szText += "+" + iAttackSpeed[ iPlayerIndex ] + "% Velocidad de Ataque con Armas cuerpo a cuerpo\n";
				if ( iDamageResist[ iPlayerIndex ] > 0 )
					szText += "+" + iDamageResist[ iPlayerIndex ] + "% Resistencia a todos los Danios (Salvo por caida)\n";
				if ( plLevel[ iPlayerIndex ] == 5 )
					szText += "Empezar con Crowbar\n";
				else if ( plLevel[ iPlayerIndex ] >= 6 )
				{
					szText += "Empezar con Pipe Wrench\n";
					szText += "Empezar con Armadura\n";
				}
				break;
			}
			case SURVIVALIST:
			{
				szText += "Level " + GetLevel( iPlayerIndex, SURVIVALIST ) + " ???\n\n\n\n";
				
				switch ( GetLevel( iPlayerIndex, SURVIVALIST ) )
				{
					case 0:
					{
						szText += "Este Perk es una incognita, y no puedes saber cuales son sus efectos\n";
						break;
					}
					case 1:
					{
						szText += "Segun el tiempo dedicado a este Perk, puedes deducir los siguientes efectos:\n\n";
						szText += "+??% Danio base con Armas ???\n";
						szText += "+??% Capacidad maxima de Vida\n";
						break;
					}
					case 2:
					{
						szText += "Segun el tiempo dedicado a este Perk, puedes deducir los siguientes efectos:\n\n";
						szText += "+??% Danio base con Armas ???\n";
						szText += "+??% Capacidad maxima de Vida\n";
						szText += "+??% Vida Extra de Medkits\n";
						szText += "Ningun danio puede gibbear (Salvo...???)\n";
						break;
					}
					case 3:
					{
						szText += "Segun el tiempo dedicado a este Perk, puedes deducir los siguientes efectos:\n\n";
						szText += "+??% Danio base con Armas ???\n";
						szText += "+?.?% Danio extra de HeadShot con Armas ???\n";
						szText += "+??% Capacidad maxima de Vida\n";
						szText += "+??% Vida Extra de Medkits\n";
						szText += "Ningun danio puede gibbear (Salvo...???)\n";
						break;
					}
					case 4:
					{
						szText += "Segun el tiempo dedicado a este Perk, puedes deducir los siguientes efectos:\n\n";
						szText += "+??% Danio base con Armas ???\n";
						szText += "+?.?% Danio extra de HeadShot con Armas ???\n";
						szText += "-??% Recoil con ???\n";
						szText += "+??% Capacidad maxima de Vida\n";
						szText += "+??% Vida Extra de Medkits\n";
						szText += "Ningun danio puede gibbear (Salvo...???)\n";
						break;
					}
					case 5:
					{
						szText += "Segun el tiempo dedicado a este Perk, puedes deducir los siguientes efectos:\n\n";
						szText += "+??% Danio base con Armas ???\n";
						szText += "+?.?% Danio extra de HeadShot con Armas ???\n";
						szText += "-??% Recoil con ???\n";
						szText += "+??% Capacidad maxima de Vida\n";
						szText += "+??% Vida Extra de Medkits\n";
						szText += "Ningun danio puede gibbear (Salvo danios por caida)\n";
						szText += "Empezar con ???\n";
						break;
					}
					case 6:
					{
						szText += "Segun el tiempo dedicado a este Perk, puedes deducir los siguientes efectos:\n\n";
						szText += "+??% Danio base con Armas ???\n";
						szText += "+?.?% Danio extra de HeadShot con Armas ???\n";
						szText += "-??% Recoil con ???\n";
						szText += "+??% Capacidad maxima de Vida\n";
						szText += "+??% Vida Extra de Medkits\n";
						szText += "Ningun danio puede gibbear (Salvo danios por caida)\n";
						szText += "Empezar con ???\n";
						szText += "Empezar con 5 Snarks\n";
						break;
					}
				}
				
				break;
			}
			case DEMOLITIONS:
			{
				szText += "Level " + GetLevel( iPlayerIndex, DEMOLITIONS ) + " Demolitions\n\n\n\n";
				
				if ( iExtraBaseDamage[ iPlayerIndex ] > 0 )
					szText += "+" + iExtraBaseDamage[ iPlayerIndex ] + "% Danio base con Explosivos\n";
				if ( iDamageResist[ iPlayerIndex ] > 0 )
					szText += "+" + iDamageResist[ iPlayerIndex ] + "% Resistencia a Danios de Explosivos\n";
				if ( iExtraHGAmmo[ iPlayerIndex ] > 0 )
					szText += "+" + iExtraHGAmmo[ iPlayerIndex ] + "% Capacidad maxima de HandGrenades\n";
				if ( plLevel[ iPlayerIndex ] >= 1 )
					szText += "Puede llevar hasta " + ( 7 + plLevel[ iPlayerIndex ] ) + " Satchel Charges\n";
				if ( plLevel[ iPlayerIndex ] >= 5 )
					szText += "Empezar con M16 (+2 Granadas)\n";
				if ( plLevel[ iPlayerIndex ] >= 6 )
					szText += "Empezar con 1 Satchel Charge\n";
				break;
			}
		}
		
		ShowMOTD( pPlayer, "Informacion del Perk", szText );
		
		// Restore old perk
		g_Scheduler.SetTimeout( "RestorePerk", 0.02, iPlayerIndex, iOldPerk );
	}
}

void PlayerIntro( const int& in iPlayerIndex, bool& in bInfoOnly )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null && pPlayer.IsConnected() )
	{
		MenuHandler@ state = MenuGetPlayer( pPlayer );
		state.InitMenu( pPlayer, PlayerIntro_CB );
		
		// Build title
		string szTitle = "ERR_OUT_OF_MATECOCIDO";
		switch ( plPerk[ iPlayerIndex ] )
		{
			case FIELD_MEDIC: szTitle = "Field Medic"; break;
			case SUPPORT_SPECIALIST: szTitle = "Support Specialist"; break;
			case SHARPSHOOTER: szTitle = "Sharpshooter"; break;
			case COMMANDO: szTitle = "Commando"; break;
			case BERSERKER: szTitle = "Berserker"; break;
			case SURVIVALIST: szTitle = "???"; break;
			case DEMOLITIONS: szTitle = "Demolitions"; break;
		}
		CustomKeyvalues@ pKVD = pPlayer.GetCustomKeyvalues();
		CustomKeyvalue iPerk_pre( pKVD.GetKeyvalue( "$i_sdx_perk_info" ) );
		int iPerk = iPerk_pre.GetInteger();
		if ( iPerk == 0 ) iPerk = plPerk[ iPlayerIndex ];
		szTitle += " - Level " + GetLevel( iPlayerIndex, iPerk ) + "\n\n";
		
		// Build info
		switch ( plPerk[ iPlayerIndex ] )
		{
			case FIELD_MEDIC:
			{
				int iNextLevelRequirement = 0;
				GetLevel( iPlayerIndex, FIELD_MEDIC, iNextLevelRequirement );
				
				if ( plLevel[ iPlayerIndex ] >= 6 )
					szTitle += "Para el siguiente nivel:\nCurar -,---,---\nHP a aliados [ " + AddCommas( iHPHealing[ iPlayerIndex ] ) + " / -,---,--- ]\n";
				else
					szTitle += "Para el siguiente nivel:\nCurar " + AddCommas( iNextLevelRequirement ) + "\nHP a aliados [ " + AddCommas( iHPHealing[ iPlayerIndex ] ) + " / " + AddCommas( iNextLevelRequirement ) + " ]\n";
				
				break;
			}
			case SUPPORT_SPECIALIST:
			{
				int iNextLevelRequirement = 0;
				GetLevel( iPlayerIndex, SUPPORT_SPECIALIST, iNextLevelRequirement );
				
				if ( plLevel[ iPlayerIndex ] >= 6 )
					szTitle += "Para el siguiente nivel:\nRealizar -,---,---\nde danio con Escopetas [ " + AddCommas( iShotgunDamage[ iPlayerIndex ] ) + " / -,---,--- ]\n";
				else
					szTitle += "Para el siguiente nivel:\nRealizar " + AddCommas( iNextLevelRequirement ) + "\nde danio con Escopetas [ " + AddCommas( iShotgunDamage[ iPlayerIndex ] ) + " / " + AddCommas( iNextLevelRequirement ) + " ]\n";
				
				break;
			}
			case SHARPSHOOTER:
			{
				int iNextLevelRequirement = 0;
				GetLevel( iPlayerIndex, SHARPSHOOTER, iNextLevelRequirement );
				
				if ( plLevel[ iPlayerIndex ] >= 6 )
					szTitle += "Para el siguiente nivel:\nHacer -,---,---\nHeadShots con Pistolas, Ballestas o Francotiradores [ " + AddCommas( iHeadShots[ iPlayerIndex ] ) + " / -,---,--- ]\n";
				else
					szTitle += "Para el siguiente nivel:\nHacer " + AddCommas( iNextLevelRequirement ) + "\nHeadShots con Pistolas, Ballestas o Francotiradores [ " + AddCommas( iHeadShots[ iPlayerIndex ] ) + " / " + AddCommas( iNextLevelRequirement ) + " ]\n";
				
				break;
			}
			case COMMANDO:
			{
				int iNextLevelRequirement = 0;
				GetLevel( iPlayerIndex, COMMANDO, iNextLevelRequirement );
				
				if ( plLevel[ iPlayerIndex ] >= 6 )
					szTitle += "Para el siguiente nivel:\nRealizar -,---,---\nde danio con Rifles o Uzis [ " + AddCommas( iRifleDamage[ iPlayerIndex ] ) + " / -,---,--- ]\n";
				else
					szTitle += "Para el siguiente nivel:\nRealizar " + AddCommas( iNextLevelRequirement ) + "\nde danio con Rifles o Uzis [ " + AddCommas( iRifleDamage[ iPlayerIndex ] ) + " / " + AddCommas( iNextLevelRequirement ) + " ]\n";
				
				break;
			}
			case BERSERKER:
			{
				int iNextLevelRequirement = 0;
				GetLevel( iPlayerIndex, BERSERKER, iNextLevelRequirement );
				
				if ( plLevel[ iPlayerIndex ] >= 6 )
					szTitle += "Para el siguiente nivel:\nRealizar -,---,---\nde danio con Armas cuerpo a cuerpo [ " + AddCommas( iMeeleDamage[ iPlayerIndex ] ) + " / -,---,--- ]\n";
				else
					szTitle += "Para el siguiente nivel:\nRealizar " + AddCommas( iNextLevelRequirement ) + "\nde danio con Armas cuerpo a cuerpo [ " + AddCommas( iMeeleDamage[ iPlayerIndex ] ) + " / " + AddCommas( iNextLevelRequirement ) + " ]\n";
				
				break;
			}
			case SURVIVALIST:
			{
				int iNextLevelRequirement = 0;
				GetLevel( iPlayerIndex, SURVIVALIST, iNextLevelRequirement );
				
				/*
				if ( plLevel[ iPlayerIndex ] >= 6 )
					szTitle += "Para el siguiente nivel:\nRealizar -,---,---\nde danio con Armas cuerpo a cuerpo [ " + AddCommas( iMeeleDamage[ iPlayerIndex ] ) + " / -,---,--- ]\n";
				else
					szTitle += "Para el siguiente nivel:\nRealizar " + AddCommas( iNextLevelRequirement ) + "\nde danio con Armas cuerpo a cuerpo [ " + AddCommas( iMeeleDamage[ iPlayerIndex ] ) + " / " + AddCommas( iNextLevelRequirement ) + " ]\n";
				*/
				
				szTitle += "Para el siguiente nivel:\n???\n??? [ " + AddCommas( iOtherDamage[ iPlayerIndex ] ) + " ] / [ ?,???,??? ]\n";
				
				break;
			}
			case DEMOLITIONS:
			{
				int iNextLevelRequirement = 0;
				GetLevel( iPlayerIndex, DEMOLITIONS, iNextLevelRequirement );
				
				if ( plLevel[ iPlayerIndex ] >= 6 )
					szTitle += "Para el siguiente nivel:\nRealizar -,---,---\nde danio con Explosivos [ " + AddCommas( iExplosiveDamage[ iPlayerIndex ] ) + " / -,---,--- ]\n";
				else
					szTitle += "Para el siguiente nivel:\nRealizar " + AddCommas( iNextLevelRequirement ) + "\nde danio con Explosivos [ " + AddCommas( iExplosiveDamage[ iPlayerIndex ] ) + " / " + AddCommas( iNextLevelRequirement ) + " ]\n";
				
				break;
			}
		}
		// Perk progression disabled?
		if ( plLevel[ iPlayerIndex ] >= 1 && iDifficulty == BEGINNER )
			szTitle += "\nEl progreso de las Perks ha sido deshabilitada\nporque la dificultad del mapa es BEGINNER\n";
		
		// Anti-Beginner difficulty?
		if ( bBeginnerWarn && iDifficulty == BEGINNER )
			szTitle += "\nEste mapa castiga el uso de la dificultad BEGINNER!\nCuidado antes de empezar la partida\n";
		
		state.menu.SetTitle( szTitle );
		
		// Items
		if ( !bInfoOnly )
		{
			CustomKeyvalue bIsReady_pre( pKVD.GetKeyvalue( "$i_sdx_ready" ) );
			int bIsReady = bIsReady_pre.GetInteger();
			if ( bIsReady == 0 )
				state.menu.AddItem( "Listo", any( "item1" ) );
			else
				state.menu.AddItem( "No Listo", any( "item1" ) );
			
			state.menu.AddItem( "Elegir Perk\n", any( "item2" ) );
			
			string szDifficulty = "Dificultad: ";
			switch ( iDifficulty )
			{
				case BEGINNER: szDifficulty += "Beginner\n"; break;
				case NORMAL: szDifficulty += "Normal\n"; break;
				case HARD: szDifficulty += "Hard\n"; break;
				case SUICIDE: szDifficulty += "Suicidal\n"; break;
				case HELL: szDifficulty += "Hell\n"; break;
			}
			state.menu.AddItem( szDifficulty, any( "item3" ) );
		}
		else
			state.menu.AddItem( "Ver otro Perk\n", any( "item4" ) );
		
		state.menu.AddItem( "Ver efectos del Perk\n", any( "item5" ) );
		
		state.OpenMenu( pPlayer, 0, 0 );
	}
}

void PlayerIntro_CB( CTextMenu@ menu, CBasePlayer@ pPlayer, int page, const CTextMenuItem@ item )
{
	int index = pPlayer.entindex();
	if ( page == 10 )
	{
		if ( !g_SurvivalMode.IsActive() )
		{
			// This menu cannot be closed this way...
			g_Scheduler.SetTimeout( "PlayerIntro", 0.01, index, false );
		}
		return;
	}
	
	string selection;
	item.m_pUserData.retrieve( selection );
	
	AdminLevel_t aLevel = g_PlayerFuncs.AdminLevel( pPlayer );
	
	if ( selection == 'item1' )
	{
		if ( ( g_Engine.time - flGameTime ) > 20.0 )
			g_Scheduler.SetTimeout( "ToggleReady", 0.01, index );
		else
		{
			float flWaitTime = 20.0 - ( g_Engine.time - flGameTime );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCENTER, "Debes esperar " + fl2Decimals( flWaitTime ) + " segundos\nantes de poder marcarte como listo\n" );
			g_Scheduler.SetTimeout( "PlayerIntro", 0.01, index, false );
		}
	}
	else if ( selection == 'item2' )
		g_Scheduler.SetTimeout( "SelectPerk", 0.01, index, false );
	else if ( selection == 'item3' )
	{
		if ( !g_SurvivalMode.IsActive() )
		{
			if ( !bPLRDiffVoted[ 32 ] || aLevel >= ADMIN_YES )
			{
				if ( !bPLRDiffVoted[ index ] || aLevel >= ADMIN_YES )
					g_Scheduler.SetTimeout( "DifficultyVote", 0.01, index );
				else
				{
					g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCENTER, "Ya has emitido tu voto de dificultad\n" );
					g_Scheduler.SetTimeout( "PlayerIntro", 0.01, index, false );
				}
			}
			else
			{
				g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[SDX] La dificultad del mapa ha sido forzada por un Administrador y no puede ser cambiada\n" );
				g_Scheduler.SetTimeout( "PlayerIntro", 0.01, index, false );
			}
		}
		else
		{
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[SDX] No puedes cambiar la dificultad del mapa cuando la partida ya ha comenzado\n" );
			g_Scheduler.SetTimeout( "PlayerIntro", 0.01, index, false );
		}
	}
	else if ( selection == 'item4' )
		g_Scheduler.SetTimeout( "SelectPerk", 0.01, index, true );
	else if ( selection == 'item5' )
	{
		g_Scheduler.SetTimeout( "PerkInfo", 0.01, index );
		
		if ( !g_SurvivalMode.IsActive() )
			g_Scheduler.SetTimeout( "PlayerIntro", 0.01, index, false );
		else
		{
			CustomKeyvalues@ pKVD = pPlayer.GetCustomKeyvalues();
			CustomKeyvalue bIsReady_pre( pKVD.GetKeyvalue( "$i_sdx_ready" ) );
			int bIsReady = bIsReady_pre.GetInteger();
			if ( bIsReady == 1 )
				g_Scheduler.SetTimeout( "PlayerIntro", 0.01, index, true );
			else
				g_Scheduler.SetTimeout( "PlayerIntro", 0.01, index, false );
		}
	}
}

void PlayerLoadFail( const int& in iPlayerIndex, const int& in iError )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null && pPlayer.IsConnected() )
	{
		MenuHandler@ state = MenuGetPlayer( pPlayer );
		state.InitMenu( pPlayer, PlayerLoadFail_CB );
		
		// Error message
		string szTitle = "Esto no deberia pasar...\n\n";
		szTitle += "Una falla ha impedido la carga de tus datos personales\nEstas causas pueden ser varias y a veces imposibles de conocer\n\n";
		szTitle += "Si crees que este mensaje es erroneo, prueba a reintentar\nSi el problema persiste, recomendamos solicitar ayuda a los Administradores\n\n";
		szTitle += "Puedes ignorar este mensaje y continuar jugando, pero\nten en cuenta que tus Perks volveran a Level 0 y no\npodras guardar tu progreso mientras el problema exista\n\n";
		
		switch ( iError )
		{
			case 1: szTitle += "ERR_DATA_CORRUPTED\n\n "; break;
			case 2: szTitle += "ERR_LOAD_FAILURE\n\n   "; break;
			case 3: szTitle += "ERR_STEAM_NOAUTH\n\n   "; break;
			default: szTitle += "ERR_UNKNOWN_CAUSE\n\n  "; break;
		}
		state.menu.SetTitle( szTitle );
		
		// Items
		state.menu.AddItem( "Reintentar\n", any( "item1" ) );
		state.menu.AddItem( "Ignorar y continuar", any( "item2" ) );
		
		state.OpenMenu( pPlayer, 0, 0 );
	}
}

void PlayerLoadFail_CB( CTextMenu@ menu, CBasePlayer@ pPlayer, int page, const CTextMenuItem@ item )
{
	int index = pPlayer.entindex();
	
	string selection;
	item.m_pUserData.retrieve( selection );
	
	if ( selection == 'item1' )
	{
		// Retry
		bool bDummy = false; // Do we have to start with this shit again?
		int iError = 0;
		LoadData( pPlayer, iError );
		
		if ( iError == 0 )
		{
			// Get perk bonus and init player
			GetPerkBonus( index, plPerk[ index ], plLevel[ index ] );
			g_Scheduler.SetTimeout( "PlayerIntro", 0.5, index, false );
		}
		else
			g_Scheduler.SetTimeout( "PlayerLoadFail", 0.5, index, iError );
	}
	else
	{
		// Init empty values, and set DO NOT SAVE flag
		while ( plPerk[ index ] == NONE )
		{
			int iNewPerk = Math.RandomLong( 1, 7 );
			if ( iNewPerk == SURVIVALIST )
				iNewPerk = NONE;
			plPerk[ index ] = iNewPerk;
		}
		plLevel[ index ] = 0;
		GetPerkBonus( index, plPerk[ index ], plLevel[ index ] );
		
		bDoNotSave[ index ] = true;
		g_Scheduler.SetTimeout( "PlayerIntro", 0.5, index, false );
	}
}

void ToggleReady( const int& in iPlayerIndex )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null && pPlayer.IsConnected() )
	{
		CustomKeyvalues@ pKVD = pPlayer.GetCustomKeyvalues();
		CustomKeyvalue bIsReady_pre( pKVD.GetKeyvalue( "$i_sdx_ready" ) );
		int bIsReady = bIsReady_pre.GetInteger();
		bIsReady = bIsReady ^ 1;
		pPlayer.KeyValue( "$i_sdx_ready", string( bIsReady ) );
		
		// Survival not yet started
		if ( !g_SurvivalMode.IsActive() )
		{
			// Iterate through other players and check if everyone is also ready
			int iTotalPlayers = 0;
			int iReadyPlayers = 0;
			for ( int i = 1; i <= g_Engine.maxClients; i++ )
			{
				CBasePlayer@ oPlayer = g_PlayerFuncs.FindPlayerByIndex( i );
				
				if ( oPlayer !is null && oPlayer.IsConnected() )
				{
					iTotalPlayers++;
					CustomKeyvalues@ oKVD = oPlayer.GetCustomKeyvalues();
					CustomKeyvalue o_bIsReady_pre( oKVD.GetKeyvalue( "$i_sdx_ready" ) );
					bIsReady = o_bIsReady_pre.GetInteger();
					if ( bIsReady == 1 )
						iReadyPlayers++;
				}
			}
			
			if ( iTotalPlayers == iReadyPlayers && !bVoting ) // Don't start game if a vote is in progress
				StartGame( false );
			else
				g_Scheduler.SetTimeout( "PlayerIntro", 0.01, iPlayerIndex, false );
		}
		else
		{
			// Bug fix, survival mode started and player just pressed NOT READY at the exact frame
			if ( bIsReady == 0 )
			{
				// BITCH
				pPlayer.KeyValue( "$i_sdx_ready", "1" );
			}
		}
	}
}

void DifficultyVote( const int& in iPlayerIndex )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null && pPlayer.IsConnected() )
	{
		MenuHandler@ state = MenuGetPlayer( pPlayer );
		state.InitMenu( pPlayer, DifficultyVote_CB );
		
		state.menu.SetTitle( "En que dificultad quieres jugar este mapa?\n" );
		
		state.menu.AddItem( "Beginner", any( "1" ) );
		state.menu.AddItem( "Normal", any( "2" ) );
		state.menu.AddItem( "Hard", any( "3" ) );
		state.menu.AddItem( "Suicidal", any( "4" ) );
		state.menu.AddItem( "Hell\n", any( "5" ) );
		
		if ( g_PlayerFuncs.AdminLevel( pPlayer ) >= ADMIN_YES )
		{
			state.menu.AddItem( "Forzar dificultad Beginner", any( "force_beginner" ) );
			state.menu.AddItem( "Forzar dificultad Normal", any( "force_normal" ) );
			state.menu.AddItem( "Forzar dificultad Hard", any( "force_hard" ) );
			state.menu.AddItem( "Forzar dificultad Suicidal", any( "force_suicide" ) );
			state.menu.AddItem( "Forzar dificultad Hell", any( "force_hell" ) );
		}
		
		state.OpenMenu( pPlayer, 0, 0 );
	}
}

void DifficultyVote_CB( CTextMenu@ menu, CBasePlayer@ pPlayer, int page, const CTextMenuItem@ item )
{
	int index = pPlayer.entindex();
	if ( page == 10 )
	{
		// Return to ready menu
		g_Scheduler.SetTimeout( "PlayerIntro", 0.01, index, false );
		return;
	}
	
	if ( bPLRDiffVoted[ 32 ] && g_PlayerFuncs.AdminLevel( pPlayer ) == ADMIN_NO )
	{
		// Invalidate any command and return to ready menu
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[SDX] La dificultad del mapa ha sido forzada por un Administrador y no puede ser cambiada\n" );
		g_Scheduler.SetTimeout( "PlayerIntro", 0.01, index, false );
	}
	
	string selection;
	item.m_pUserData.retrieve( selection );
	
	if ( selection == 'force_beginner' )
	{
		if ( iDifficulty == BEGINNER )
		{
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCENTER, "La dificultad del mapa ya es Beginner\n" );
			g_Scheduler.SetTimeout( "DifficultyVote", 0.01, index );
			return;
		}
		else
		{
			iDifficulty = BEGINNER;
			bPLRDiffVoted[ 32 ] = true;
			
			g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] La dificultad del mapa ha sido forzada a Beginner!\n" );
			g_Game.AlertMessage( at_logged, "[SDX] La dificultad del mapa ha sido forzada a Beginner\n" );
			ALL_PlayerIntro();
			return;
		}
	}
	else if ( selection == 'force_normal' )
	{
		if ( iDifficulty == NORMAL )
		{
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCENTER, "La dificultad del mapa ya es Normal\n" );
			g_Scheduler.SetTimeout( "DifficultyVote", 0.01, index );
			return;
		}
		else
		{
			iDifficulty = NORMAL;
			bPLRDiffVoted[ 32 ] = true;
			
			g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] La dificultad del mapa ha sido forzada a Normal!\n" );
			g_Game.AlertMessage( at_logged, "[SDX] La dificultad del mapa ha sido forzada a Normal\n" );
			ALL_PlayerIntro();
			return;
		}
	}
	else if ( selection == 'force_hard' )
	{
		if ( iDifficulty == HARD )
		{
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCENTER, "La dificultad del mapa ya es Hard\n" );
			g_Scheduler.SetTimeout( "DifficultyVote", 0.01, index );
			return;
		}
		else
		{
			iDifficulty = HARD;
			bPLRDiffVoted[ 32 ] = true;
			
			g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] La dificultad del mapa ha sido forzada a Hard!\n" );
			g_Game.AlertMessage( at_logged, "[SDX] La dificultad del mapa ha sido forzada a Hard\n" );
			ALL_PlayerIntro();
			return;
		}
	}
	else if ( selection == 'force_suicide' )
	{
		if ( iDifficulty == SUICIDE )
		{
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCENTER, "La dificultad del mapa ya es Suicidal\n" );
			g_Scheduler.SetTimeout( "DifficultyVote", 0.01, index );
			return;
		}
		else
		{
			iDifficulty = SUICIDE;
			bPLRDiffVoted[ 32 ] = true;
			
			g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] La dificultad del mapa ha sido forzada a Suicidal!\n" );
			g_Game.AlertMessage( at_logged, "[SDX] La dificultad del mapa ha sido forzada a Suicidal\n" );
			ALL_PlayerIntro();
			return;
		}
	}
	else if ( selection == 'force_hell' )
	{
		if ( iDifficulty == HELL )
		{
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCENTER, "La dificultad del mapa ya es Hell\n" );
			g_Scheduler.SetTimeout( "DifficultyVote", 0.01, index );
			return;
		}
		else
		{
			iDifficulty = HELL;
			bPLRDiffVoted[ 32 ] = true;
			
			g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] La dificultad del mapa ha sido forzada a Hell!\n" );
			g_Game.AlertMessage( at_logged, "[SDX] La dificultad del mapa ha sido forzada a Hell\n" );
			ALL_PlayerIntro();
			return;
		}
	}
	
	int iVoteDiff = atoi( selection );
	if ( iVoteDiff == iDifficulty )
	{
		string szMessage = "La dificultad del mapa ya es ";
		switch ( iDifficulty )
		{
			case BEGINNER: szMessage += "Beginner\n"; break;
			case NORMAL: szMessage += "Normal\n"; break;
			case HARD: szMessage += "Hard\n"; break;
			case SUICIDE: szMessage += "Suicidal\n"; break;
			case HELL: szMessage += "Hell\n"; break;
		}
		
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCENTER, szMessage );
		g_Scheduler.SetTimeout( "DifficultyVote", 0.01, index );
		return;
	}
	
	if ( bVoting )
	{
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[SDX] Ya hay una votacion en progreso. Por favor espera a que esta finalize\n" );
		g_Scheduler.SetTimeout( "DifficultyVote", 0.01, index );
		return;
	}
	
	bVoting = true;
	bPLRDiffVoted[ index ] = true;
	g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] Votacion inminente!\n" );
	g_PlayerFuncs.ClientPrintAll( HUD_PRINTCENTER, "Votacion inminente!\n" );
	g_Scheduler.SetTimeout( "CALL_DiffVote", 1.5, index, iVoteDiff );
	
	// Return to ready menu
	g_Scheduler.SetTimeout( "PlayerIntro", 0.01, index, false );
}

void CheckAutoStart()
{
	// Game started, stop caring
	if ( g_SurvivalMode.IsActive() )
		return;
	
	// Get number of ready players and total player count
	int iTotalPlayers = 0;
	int iReadyPlayers = 0;
	for ( int i = 1; i <= g_Engine.maxClients; i++ )
	{
		CBasePlayer@ oPlayer = g_PlayerFuncs.FindPlayerByIndex( i );
		
		if ( oPlayer !is null && oPlayer.IsConnected() )
		{
			iTotalPlayers++;
			CustomKeyvalues@ oKVD = oPlayer.GetCustomKeyvalues();
			CustomKeyvalue o_bIsReady_pre( oKVD.GetKeyvalue( "$i_sdx_ready" ) );
			int bIsReady = o_bIsReady_pre.GetInteger();
			if ( bIsReady == 1 )
				iReadyPlayers++;
		}
	}
	
	// No player is ready or a vote is in progress
	if ( iReadyPlayers == 0 || bVoting )
	{
		// Try again
		@CSF_AutoStartTask = @g_Scheduler.SetTimeout( "CheckAutoStart", 1.0 );
		return;
	}
	
	// Half amount of players are ready?
	int iHalfPlayers = int( Math.Ceil( float( iTotalPlayers ) / 2.0 ) );
	if ( iReadyPlayers >= iHalfPlayers )
	{
		// Auto start in ...
		iAutoStartTime--;
		if ( iAutoStartTime < 0 )
		{
			// Force start game
			StartGame( true );
		}
		else
		{
			g_PlayerFuncs.ClientPrintAll( HUD_PRINTCENTER, "La partida comenzara en " + iAutoStartTime + "\n" );
			@CSF_AutoStartTask = @g_Scheduler.SetTimeout( "CheckAutoStart", 1.0 );
		}
	}
	else
	{
		// Too long on lobby?
		if ( ( g_Engine.time - flGameTime ) > 120.0 )
		{
			// Auto start in ...
			iAutoStartTime--;
			if ( iAutoStartTime < 0 )
			{
				// Force start game
				StartGame( true );
			}
			else
			{
				g_PlayerFuncs.ClientPrintAll( HUD_PRINTCENTER, "La partida comenzara en " + iAutoStartTime + "\n" );
				@CSF_AutoStartTask = @g_Scheduler.SetTimeout( "CheckAutoStart", 1.0 );
			}
		}
		else
		{
			// Try again
			@CSF_AutoStartTask = @g_Scheduler.SetTimeout( "CheckAutoStart", 1.0 );
		}
	}
}

void StartGame( bool& in bForce )
{
	// Respawn all players
	g_PlayerFuncs.RespawnAllPlayers( true, true );
	
	// Now, activate survival mode
	g_SurvivalMode.Activate( true );
	
	// Game was forcefully started?
	if ( bForce )
	{
		// Iterate through all players and force set them ready status
		for ( int i = 1; i <= g_Engine.maxClients; i++ )
		{
			CBasePlayer@ oPlayer = g_PlayerFuncs.FindPlayerByIndex( i );
			if ( oPlayer !is null && oPlayer.IsConnected() )
			{
				oPlayer.KeyValue( "$i_sdx_ready", "1" );
			}
		}
	}
	
	// Post-start
	SaveDifficulty();
	ApplyMapChanges();
}

void SelectPerk( const int& in iPlayerIndex, bool& in bInfoOnly )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null && pPlayer.IsConnected() )
	{
		MenuHandler@ state = MenuGetPlayer( pPlayer );
		if ( !bInfoOnly )
			state.InitMenu( pPlayer, SelectPerk_CB );
		else
			state.InitMenu( pPlayer, SelectViewPerk_CB );
		
		state.menu.SetTitle( "Elegir Perk\n" );
		
		state.menu.AddItem( "Field Medic", any( "item1" ) );
		state.menu.AddItem( "Support Specialist", any( "item2" ) );
		state.menu.AddItem( "Sharpshooter", any( "item3" ) );
		state.menu.AddItem( "Commando", any( "item4" ) );
		state.menu.AddItem( "Berserker", any( "item5" ) );
		state.menu.AddItem( "???", any( "item6" ) );
		state.menu.AddItem( "Demolitions", any( "item7" ) );
		
		state.OpenMenu( pPlayer, 0, 0 );
	}
}

void SelectPerk_CB( CTextMenu@ menu, CBasePlayer@ pPlayer, int page, const CTextMenuItem@ item )
{
	int index = pPlayer.entindex();
	if ( page == 10 )
	{
		// Return to ready menu
		g_Scheduler.SetTimeout( "PlayerIntro", 0.01, index, false );
		return;
	}
	
	string selection;
	item.m_pUserData.retrieve( selection );
	
	// Perk
	if ( selection == 'item1' )
		plPerk[ index ] = FIELD_MEDIC;
	else if ( selection == 'item2' )
		plPerk[ index ] = SUPPORT_SPECIALIST;
	else if ( selection == 'item3' )
		plPerk[ index ] = SHARPSHOOTER;
	else if ( selection == 'item4' )
		plPerk[ index ] = COMMANDO;
	else if ( selection == 'item5' )
		plPerk[ index ] = BERSERKER;
	else if ( selection == 'item6' )
		plPerk[ index ] = SURVIVALIST;
	else if ( selection == 'item7' )
		plPerk[ index ] = DEMOLITIONS;
	
	// Re-calculate perk bonuses
	plLevel[ index ] = GetLevel( index, plPerk[ index ] );
	GetPerkBonus( index, plPerk[ index ], plLevel[ index ] );
	
	// Return to ready menu
	g_Scheduler.SetTimeout( "PlayerIntro", 0.01, index, false );
}

void SelectViewPerk_CB( CTextMenu@ menu, CBasePlayer@ pPlayer, int page, const CTextMenuItem@ item )
{
	int index = pPlayer.entindex();
	if ( page == 10 )
	{
		// Return to ready menu
		g_Scheduler.SetTimeout( "PlayerIntro", 0.01, index, true );
		return;
	}
	
	string selection;
	item.m_pUserData.retrieve( selection );
	
	// Save old perk
	int iOldPerk = plPerk[ index ];
	
	// Select new perk
	if ( selection == 'item1' )
		plPerk[ index ] = FIELD_MEDIC;
	else if ( selection == 'item2' )
		plPerk[ index ] = SUPPORT_SPECIALIST;
	else if ( selection == 'item3' )
		plPerk[ index ] = SHARPSHOOTER;
	else if ( selection == 'item4' )
		plPerk[ index ] = COMMANDO;
	else if ( selection == 'item5' )
		plPerk[ index ] = BERSERKER;
	else if ( selection == 'item6' )
		plPerk[ index ] = SURVIVALIST;
	else if ( selection == 'item7' )
		plPerk[ index ] = DEMOLITIONS;
	
	// Save the viewed perk for MOTD window
	pPlayer.KeyValue( "$i_sdx_perk_info", string( plPerk[ index ] ) );
	
	// Return to ready menu
	g_Scheduler.SetTimeout( "PlayerIntro", 0.01, index, true );
	
	// Restore old perk
	g_Scheduler.SetTimeout( "RestorePerk", 0.02, index, iOldPerk );
}
void RestorePerk( const int& in iPlayerIndex, const int& in iOldPerk )
{
	plPerk[ iPlayerIndex ] = iOldPerk;
	plLevel[ iPlayerIndex ] = GetLevel( iPlayerIndex, plPerk[ iPlayerIndex ] );
	GetPerkBonus( iPlayerIndex, plPerk[ iPlayerIndex ], plLevel[ iPlayerIndex ] );
}

// Item menu: Main
void ItemMenu( const int& in iPlayerIndex )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null && pPlayer.IsConnected() )
	{
		MenuHandler@ state = MenuGetPlayer( pPlayer );
		state.InitMenu( pPlayer, ItemMenu_CB );
		
		state.menu.SetTitle( "Objetos\n" );
		
		// Find any items
		int iFoundItems = 0;
		for ( uint i = 0; i < MAX_ITEMS; i++ )
		{
			int iAmount = 0;
			if ( pl_iItemData[ iPlayerIndex ][ i ] >= 1 )
			{
				while ( iAmount < pl_iItemData[ iPlayerIndex ][ i ] )
				{
					state.menu.AddItem( ItemName[ i ], any( string( i ) ) );
					iAmount++;
					iFoundItems++;
				}
			}
		}
		
		if ( iFoundItems > 0 )
			state.OpenMenu( pPlayer, 0, 0 );
		else
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[SDX] Tu inventario esta vacio\n" );
	}
}
void ItemMenu_CB( CTextMenu@ menu, CBasePlayer@ pPlayer, int page, const CTextMenuItem@ item )
{
	int index = pPlayer.entindex();
	if ( page == 10 )
		return;
	
	string selection;
	item.m_pUserData.retrieve( selection );
	
	// Save selection
	pPlayer.KeyValue( "$i_sdx_item_selection", selection );
	
	// Open sub-menu
	g_Scheduler.SetTimeout( "ItemOptions", 0.01, index );
}

// Item menu: Options menu
void ItemOptions( const int& in iPlayerIndex )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null && pPlayer.IsConnected() )
	{
		MenuHandler@ state = MenuGetPlayer( pPlayer );
		state.InitMenu( pPlayer, ItemOptions_CB );
		
		// Get item ID
		CustomKeyvalues@ pKVD = pPlayer.GetCustomKeyvalues();
		CustomKeyvalue ItemID_pre( pKVD.GetKeyvalue( "$i_sdx_item_selection" ) );
		int ItemID = ItemID_pre.GetInteger();
		
		state.menu.SetTitle( "" + ItemName[ ItemID ] + "\n" );
		
		state.menu.AddItem( "Usar", any( "item1" ) );
		state.menu.AddItem( "Lanzar", any( "item2" ) );
		state.menu.AddItem( "Dar", any( "item3" ) );
		state.menu.AddItem( "Tirar", any( "item4" ) );
		state.menu.AddItem( "Info.", any( "item5" ) );
		
		state.OpenMenu( pPlayer, 0, 0 );
	}
}
void ItemOptions_CB( CTextMenu@ menu, CBasePlayer@ pPlayer, int page, const CTextMenuItem@ item )
{
	int index = pPlayer.entindex();
	if ( page == 10 )
	{
		// Return to items menu
		g_Scheduler.SetTimeout( "ItemMenu", 0.01, index );
		return;
	}
	
	// Get item ID
	CustomKeyvalues@ pKVD = pPlayer.GetCustomKeyvalues();
	CustomKeyvalue ItemID_pre( pKVD.GetKeyvalue( "$i_sdx_item_selection" ) );
	int ItemID = ItemID_pre.GetInteger();
	
	string selection;
	item.m_pUserData.retrieve( selection );
	
	if ( selection == 'item1' )
	{
		// Use. Self mode?
		if ( ItemSelfMode[ ItemID ] )
		{
			// No player menu, auto-use on self. Can item be used?
			if ( BaseItem_CanUse( index, ItemInternal[ ItemID ] ) )
			{
				// Use the item
				BaseItem_Use( index, ItemInternal[ ItemID ] );
				RemoveItem( index, ItemInternal[ ItemID ] );
			}
			else
			{
				// Can't...
				g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCENTER, "No puede usarse\n" );
				g_Scheduler.SetTimeout( "ItemOptions", 0.01, index );
			}
		}
		else
		{
			// Open players menu for USE
			g_Scheduler.SetTimeout( "ItemSelectPlayer", 0.01, index, false );
		}
	}
	else if ( selection == 'item2' )
	{
		// Throw. Can item be thrown?
		if ( BaseItem_CanThrow( index, ItemInternal[ ItemID ] ) )
		{
			// Throw away!
			BaseItem_Throw( index, ItemInternal[ ItemID ] );
			RemoveItem( index, ItemInternal[ ItemID ] );
		}
		else
		{
			// Can't...
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCENTER, "No puede lanzarse\n" );
			g_Scheduler.SetTimeout( "ItemOptions", 0.01, index );
		}
	}
	else if ( selection == 'item3' )
	{
		// Open players menu for GIVE
		g_Scheduler.SetTimeout( "ItemSelectPlayer", 0.01, index, true );
	}
	else if ( selection == 'item4' )
	{
		// Drop. Open confirmation menu
		g_Scheduler.SetTimeout( "ItemDrop", 0.01, index );
	}
	else if ( selection == 'item5' )
	{
		// Display item information
		g_Scheduler.SetTimeout( "ItemGetInfo", 0.01, index );
	}
}

// Item menu: Drop confirmation
void ItemDrop( const int& in iPlayerIndex )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null && pPlayer.IsConnected() )
	{
		MenuHandler@ state = MenuGetPlayer( pPlayer );
		state.InitMenu( pPlayer, ItemDrop_CB );
		
		// Get item ID
		CustomKeyvalues@ pKVD = pPlayer.GetCustomKeyvalues();
		CustomKeyvalue ItemID_pre( pKVD.GetKeyvalue( "$i_sdx_item_selection" ) );
		int ItemID = ItemID_pre.GetInteger();
		
		state.menu.SetTitle( "Estas seguro que deseas\ndeshacerte de tu " + ItemName[ ItemID ] + "?\n" );
		
		state.menu.AddItem( "Si", any( "item1" ) );
		state.menu.AddItem( "No", any( "item2" ) );
		
		state.OpenMenu( pPlayer, 0, 0 );
	}
}
void ItemDrop_CB( CTextMenu@ menu, CBasePlayer@ pPlayer, int page, const CTextMenuItem@ item )
{
	int index = pPlayer.entindex();
	if ( page == 10 )
		return;
	
	// Get item ID
	CustomKeyvalues@ pKVD = pPlayer.GetCustomKeyvalues();
	CustomKeyvalue ItemID_pre( pKVD.GetKeyvalue( "$i_sdx_item_selection" ) );
	int ItemID = ItemID_pre.GetInteger();
	
	string selection;
	item.m_pUserData.retrieve( selection );
	
	if ( selection == 'item1' )
	{
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[SDX] Tiraste el objeto \"" + ItemName[ ItemID ] + "\"\n" );
		RemoveItem( index, ItemInternal[ ItemID ] );
		g_Scheduler.SetTimeout( "ItemMenu", 0.01, index );
	}
	else if ( selection == 'item2' )
		g_Scheduler.SetTimeout( "ItemOptions", 0.01, index );
}

// Item menu: Item information
void ItemGetInfo( const int& in iPlayerIndex )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null && pPlayer.IsConnected() )
	{
		MenuHandler@ state = MenuGetPlayer( pPlayer );
		state.InitMenu( pPlayer, ItemGetInfo_CB );
		
		// Get item ID
		CustomKeyvalues@ pKVD = pPlayer.GetCustomKeyvalues();
		CustomKeyvalue ItemID_pre( pKVD.GetKeyvalue( "$i_sdx_item_selection" ) );
		int ItemID = ItemID_pre.GetInteger();
		
		state.menu.SetTitle( "" + ItemName[ ItemID ] + "\n\n" + ItemDescription[ ItemID ] + "\n" );
		
		state.menu.AddItem( "Volver", any( "item1" ) );
		
		state.OpenMenu( pPlayer, 0, 0 );
	}
}
void ItemGetInfo_CB( CTextMenu@ menu, CBasePlayer@ pPlayer, int page, const CTextMenuItem@ item )
{
	int index = pPlayer.entindex();
	if ( page == 10 )
		return;
	
	g_Scheduler.SetTimeout( "ItemOptions", 0.01, index );
}

// Item menu: Player selection
void ItemSelectPlayer( const int& in iPlayerIndex, bool& in bGiveMode )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null && pPlayer.IsConnected() )
	{
		MenuHandler@ state = MenuGetPlayer( pPlayer );
		if ( !bGiveMode )
			state.InitMenu( pPlayer, ItemPlayerUse_CB );
		else
			state.InitMenu( pPlayer, ItemPlayerGive_CB );
		
		state.menu.SetTitle( "Quien?\n" );
		
		// Get all players
		for ( int i = 1; i <= g_Engine.maxClients; i++ )
		{
			CBasePlayer@ iPlayer = g_PlayerFuncs.FindPlayerByIndex( i );
			
			if ( iPlayer !is null && iPlayer.IsConnected() )
			{
				state.menu.AddItem( iPlayer.pev.netname, any( string( iPlayer.pev.netname ) ) );
			}
		}
		
		state.OpenMenu( pPlayer, 0, 0 );
	}
}
void ItemPlayerUse_CB( CTextMenu@ menu, CBasePlayer@ pPlayer, int page, const CTextMenuItem@ item )
{
	int index = pPlayer.entindex();
	if ( page == 10 )
	{
		// Return to options menu
		g_Scheduler.SetTimeout( "ItemOptions", 0.01, index );
		return;
	}
	
	// Get item ID
	CustomKeyvalues@ pKVD = pPlayer.GetCustomKeyvalues();
	CustomKeyvalue ItemID_pre( pKVD.GetKeyvalue( "$i_sdx_item_selection" ) );
	int ItemID = ItemID_pre.GetInteger();
	
	string selection;
	item.m_pUserData.retrieve( selection );
	
	CBasePlayer@ iPlayer = g_PlayerFuncs.FindPlayerByName( selection );
	if ( iPlayer !is null && iPlayer.IsConnected() )
	{
		int iTargetIndex = iPlayer.entindex();
		
		// Can this player use this item?
		if ( BaseItem_CanUse( iTargetIndex, ItemInternal[ ItemID ] ) )
		{
			// Use the item
			BaseItem_Use( iTargetIndex, ItemInternal[ ItemID ] );
			RemoveItem( index, ItemInternal[ ItemID ] );
		}
		else
		{
			// Nope
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCENTER, "No puede usarse en " + iPlayer.pev.netname + "\n" );
			g_Scheduler.SetTimeout( "ItemSelectPlayer", 0.01, index, false );
		}
	}
	else
	{
		// Refresh the menu
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCENTER, "Jugador no encontrado\n" );
		g_Scheduler.SetTimeout( "ItemSelectPlayer", 0.01, index, false );
	}
}
void ItemPlayerGive_CB( CTextMenu@ menu, CBasePlayer@ pPlayer, int page, const CTextMenuItem@ item )
{
	int index = pPlayer.entindex();
	if ( page == 10 )
	{
		// Return to options menu
		g_Scheduler.SetTimeout( "ItemOptions", 0.01, index );
		return;
	}
	
	// Get item ID
	CustomKeyvalues@ pKVD = pPlayer.GetCustomKeyvalues();
	CustomKeyvalue ItemID_pre( pKVD.GetKeyvalue( "$i_sdx_item_selection" ) );
	int ItemID = ItemID_pre.GetInteger();
	
	string selection;
	item.m_pUserData.retrieve( selection );
	
	CBasePlayer@ iPlayer = g_PlayerFuncs.FindPlayerByName( selection );
	if ( iPlayer !is null && iPlayer.IsConnected() )
	{
		if ( iPlayer !is pPlayer )
		{
			int iTargetIndex = iPlayer.entindex();
		
			// Attempt to give the item to the player
			if ( AddItem( iTargetIndex, ItemInternal[ ItemID ] ) != 0 )
			{
				// Sound goes here
				g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] " + iPlayer.pev.netname + " recibio el objeto \"" + ItemName[ ItemID ] + "\" de " + pPlayer.pev.netname + "\n" );
				RemoveItem( index, ItemInternal[ ItemID ] );
			}
			else
			{
				// Nope
				g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCENTER, "El inventario de " + iPlayer.pev.netname + " esta lleno\n" );
				g_Scheduler.SetTimeout( "ItemSelectPlayer", 0.01, index, true );
			}
		}
		else
		{
			// ????????
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCENTER, "Dar un objeto a ti mismo?\n" );
			g_Scheduler.SetTimeout( "ItemSelectPlayer", 0.01, index, true );
		}
	}
	else
	{
		// Refresh the menu
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCENTER, "Jugador no encontrado\n" );
		g_Scheduler.SetTimeout( "ItemSelectPlayer", 0.01, index, true );
	}
}

// DEBUG - Add ITEMS
CClientCommand ADMIN_CMDHELP( "debug_additem", " - DEBUG", @TEMP_ADDBERRY, ConCommandFlag::AdminOnly );
void TEMP_ADDBERRY( const CCommand@ pArgs )
{
	CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();
	
	if ( pArgs.ArgC() >= 2 )
	{
		if ( ItemExists( pArgs[ 1 ] ) )
		{
			if ( AddItem( pPlayer.entindex(), pArgs[ 1 ] ) != 0 )
				g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "[SDX DEBUG] Success\n" );
			else
				g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "[SDX DEBUG] Inventory full\n" );
		}
		else
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "[SDX DEBUG] Invalid item\n" );
	}
	else
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "[SDX DEBUG] Usage: .debug_additem <Internal Name> - Add item to yourself\n" );
}

/* Force opens PlayerIntro( pPlayer, false ) menu to all players */
void ALL_PlayerIntro()
{
	for ( int i = 1; i <= g_Engine.maxClients; i++ )
	{
		CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( i );
		if ( pPlayer !is null && pPlayer.IsConnected() )
		{
			g_Scheduler.SetTimeout( "PlayerIntro", 0.01, i, false );
		}
	}
}

/* Runs a difficulty vote */
void CALL_DiffVote( const int& in iPlayerIndex, const int& in iNewDifficulty )
{
	// NO!
	if ( g_SurvivalMode.IsActive() )
		return;
	
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null && pPlayer.IsConnected() )
	{
		// Get the player's name
		string szName = pPlayer.pev.netname;
		szName.Replace( ' ', '_' ); // Prevent a players name being one of the difficulties from screwing around with the votes
		
		// Build the vote message
		string szMessage = szName;
		szMessage += " quiere cambiar la dificultad a ";
		switch ( iNewDifficulty )
		{
			case BEGINNER: szMessage += "Beginner"; break;
			case NORMAL: szMessage += "Normal"; break;
			case HARD: szMessage += "Hard"; break;
			case SUICIDE: szMessage += "Suicidal"; break;
			case HELL: szMessage += "Hell"; break;
		}
		szMessage += "\nEstas de acuerdo?";
		
		// Build the vote structure
		Vote diffvote( "DifficultyVote", szMessage, 10.0, ( iNewDifficulty == BEGINNER ? 65.0 : 55.0 ) );
		diffvote.ClearUserData();
		diffvote.SetVoteBlockedCallback( @vote_blocked );
		diffvote.SetVoteEndCallback( @DiffVoteEnd );
		
		// If the player is soloing, skip the vote entirely and assume win
		if ( g_PlayerFuncs.GetNumPlayers() == 1 )
			DiffVoteEnd( diffvote, true, 1 );
		else
			diffvote.Start(); // Start it
	}
	else
	{
		bVoting = false;
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] Votacion cancelada\n" );
	}
}
void DiffVoteEnd( Vote@ diffvote, bool fResult, int iVoters )
{
	if ( fResult )
	{
		string szVoteMessage = diffvote.GetVoteText();
		szVoteMessage.Replace( '\n', ' ' );
		
		// Get difficulty
		int iNewDifficulty = 0;
		
		// THE FUCKING STRING FUNCTIONS ARE USELESS. LONG LIVE AMXX RETARDS!
		array< string >@ szFixer = szVoteMessage.Split( ' ' );
		for ( uint i = 0; i < szFixer.length(); i++ )
		{
			if ( szFixer[ i ] == 'Beginner' ) iNewDifficulty = BEGINNER;
			else if ( szFixer[ i ] == 'Normal' ) iNewDifficulty = NORMAL;
			else if ( szFixer[ i ] == 'Hard' ) iNewDifficulty = HARD;
			else if ( szFixer[ i ] == 'Suicidal' ) iNewDifficulty = SUICIDE;
			else if ( szFixer[ i ] == 'Hell' ) iNewDifficulty = HELL;
		}
		
		switch ( iNewDifficulty )
		{
			case BEGINNER:
			{
				g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] La dificultad del mapa ha sido cambiada a Beginner\n" );
				g_Game.AlertMessage( at_logged, "[SDX] La dificultad del mapa ha sido cambiada a Beginner\n" );
				iDifficulty = BEGINNER;
				break;
			}
			case NORMAL:
			{
				g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] La dificultad del mapa ha sido cambiada a Normal\n" );
				g_Game.AlertMessage( at_logged, "[SDX] La dificultad del mapa ha sido cambiada a Normal\n" );
				iDifficulty = NORMAL;
				break;
			}
			case HARD:
			{
				g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] La dificultad del mapa ha sido cambiada a Hard\n" );
				g_Game.AlertMessage( at_logged, "[SDX] La dificultad del mapa ha sido cambiada a Hard\n" );
				iDifficulty = HARD;
				break;
			}
			case SUICIDE:
			{
				g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] La dificultad del mapa ha sido cambiada a Suicidal\n" );
				g_Game.AlertMessage( at_logged, "[SDX] La dificultad del mapa ha sido cambiada a Suicidal\n" );
				iDifficulty = SUICIDE;
				break;
			}
			case HELL:
			{
				g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] La dificultad del mapa ha sido cambiada a Hell\n" );
				g_Game.AlertMessage( at_logged, "[SDX] La dificultad del mapa ha sido cambiada a Hell\n" );
				iDifficulty = HELL;
				break;
			}
			default:
			{
				g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] ERROR: sz->Split->Search = NULL!\n" );
				break;
			}
		}
		
		ALL_PlayerIntro();
	}
	else
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] Votacion fallida\n" );
	
	bVoting = false;
}

void vote_blocked( Vote@ vote, float flTime )
{
	// Dummy
}

/* Converts a float value to a string, with a maximum of 2 decimals */
string fl2Decimals( const float& in value )
{
	// Convert float to string
	string original = "" + value;
	
	// Split string using decimal point
	array< string >@ pre_convert = original.Split( '.' );
	
	string decimals = "";
	
	// Check if our value has any decimal places
	if ( pre_convert.length() > 1 )
	{
		// It has at least one. Use it
		decimals += pre_convert[ 1 ][ 0 ];
		
		// Does it have a second decimal?
		if ( isdigit( pre_convert[ 1 ][ 1 ] ) )
		{
			// Yep, add it
			decimals += pre_convert[ 1 ][ 1 ];
		}
		else
		{
			// Does not. Add a zero manually
			decimals += "0";
		}
	}
	else
	{
		// No decimals, add zeros manually
		decimals += "00";
	}
	
	// Copy integer part
	string number = "" + pre_convert[ 0 ];
	
	// Now, build the full string
	string convert = "" + number + "." + decimals;
	
	return convert;
}

/* Add commas to integers */
string AddCommas( int& in iNum )
{
	string szOutput;
	string szTmp;
	uint iOutputPos = 0;
	uint iNumPos = 0;
	uint iNumLen;
	
	szTmp = string( iNum );
	iNumLen = szTmp.Length();
	
	if ( iNumLen <= 3 )
	{
		szOutput = szTmp;
	}
	else
	{
		szOutput = "????????????";
		while ( ( iNumPos < iNumLen ) ) 
		{
			szOutput.SetCharAt( iOutputPos++, char( szTmp[ iNumPos++ ] ) );
			
			if( ( iNumLen - iNumPos ) != 0 && !( ( ( iNumLen - iNumPos ) % 3 ) != 0 ) ) 
				szOutput.SetCharAt( iOutputPos++, char( "," ) );
		}
		szOutput.Replace( "?", "" );
	}
	
	return szOutput;
}

/* Load Player Data */
void LoadData( CBasePlayer@ pPlayer, int& out iError )
{
	int iPlayerIndex = pPlayer.entindex();
	
	string szSteamID = g_EngineFuncs.GetPlayerAuthId( pPlayer.edict() );
	string szPath = "" + PATH_DATA_PLAYERS + szSteamID + ".inf";
	szPath.Replace( ':', '_' );
	File@ fFile = g_FileSystem.OpenFile( szPath, OpenFile::READ );
	
	if ( fFile !is null )
	{
		if ( fFile.IsOpen() )
		{
			string line;
			fFile.ReadLine( line );
			line.Replace( '#', ' ' );
			array< string >@ pre_data = line.Split( ' ' );
			uint uiDataLength = pre_data.length();
			
			// Old data?
			if ( uiDataLength < 11 )
			{
				// Adapt the old data to the new savefile structure
				pre_data.resize( 11 );
				
				// Initialize empty values for the new vars
				pre_data[ 7 ] = "0";
				pre_data[ 8 ] = "7";
				pre_data[ 9 ] = "14";
				pre_data[ 10 ] = "0";
			}
			else if ( uiDataLength < 7 )
			{
				// The save file has been wiped!
				iError = 1;
				return;
			}
			
			for ( uint uiLength = 0; uiLength < uiDataLength; uiLength++ )
			{
				pre_data[ uiLength ].Trim();
			}
			plPerk[ iPlayerIndex ] = atoi( pre_data[ 0 ] );
			iHPHealing[ iPlayerIndex ] = atoi( pre_data[ 1 ] );
			iMeeleDamage[ iPlayerIndex ] = atoi( pre_data[ 2 ] );
			iHeadShots[ iPlayerIndex ] = atoi( pre_data[ 3 ] );
			iShotgunDamage[ iPlayerIndex ] = atoi( pre_data[ 4 ] );
			iExplosiveDamage[ iPlayerIndex ] = atoi( pre_data[ 5 ] );
			iRifleDamage[ iPlayerIndex ] = atoi( pre_data[ 6 ] );
			iOtherDamage[ iPlayerIndex ] = atoi( pre_data[ 7 ] );
			pl_iMaxItems[ iPlayerIndex ] = atoi( pre_data[ 8 ] );
			pl_iMaxStorage[ iPlayerIndex ] = atoi( pre_data[ 9 ] );
			bHasMGAccess[ iPlayerIndex ] = atoi( pre_data[ 10 ] );
			
			plLevel[ iPlayerIndex ] = GetLevel( iPlayerIndex, plPerk[ iPlayerIndex ] );
			bDoNotSave[ iPlayerIndex ] = false;
			
			fFile.Close();
		}
		else
		{
			// Couldn't not open file
			iError = 2;
		}
	}
	else
	{
		// File does not exists or other unknown error. SteamID is properly retrieved, right?
		if ( szSteamID.Length() == 0 )
		{
			// Client not yet authorized! (SteamID is pending)
			iError = 3;
		}
		else
		{
			// File does truly not exist, initialize new player data
			
			// Start with a random perk
			while ( plPerk[ iPlayerIndex ] == NONE )
			{
				int iNewPerk = Math.RandomLong( 1, 7 );
				if ( iNewPerk == SURVIVALIST )
					iNewPerk = NONE;
				plPerk[ iPlayerIndex ] = iNewPerk;
			}
			plLevel[ iPlayerIndex ] = 0;
			bDoNotSave[ iPlayerIndex ] = false;
		}
	}
}

/* Save Player Data */
void SaveData( CBasePlayer@ pPlayer )
{
	int iPlayerIndex = pPlayer.entindex();
	
	// Do not save!
	if ( bDoNotSave[ iPlayerIndex ] )
		return;
	
	string szSteamID = g_EngineFuncs.GetPlayerAuthId( pPlayer.edict() );
	string szPath = "" + PATH_DATA_PLAYERS + szSteamID + ".inf";
	szPath.Replace( ':', '_' );
	File@ fFile = g_FileSystem.OpenFile( szPath, OpenFile::WRITE );
	
	if ( fFile !is null )
	{
		if ( fFile.IsOpen() )
		{
			string szData;
			
			szData += "" + plPerk[ iPlayerIndex ] + "#";
			szData += "" + iHPHealing[ iPlayerIndex ] + "#";
			szData += "" + iMeeleDamage[ iPlayerIndex ] + "#";
			szData += "" + iHeadShots[ iPlayerIndex ] + "#";
			szData += "" + iShotgunDamage[ iPlayerIndex ] + "#";
			szData += "" + iExplosiveDamage[ iPlayerIndex ] + "#";
			szData += "" + iRifleDamage[ iPlayerIndex ] + "#";
			szData += "" + iOtherDamage[ iPlayerIndex ] + "#";
			szData += "" + pl_iMaxItems[ iPlayerIndex ] + "#";
			szData += "" + pl_iMaxStorage[ iPlayerIndex ] + "#";
			szData += "" + bHasMGAccess[ iPlayerIndex ];
			
			szData += "\n";
			fFile.Write( szData );
			fFile.Close();
		}
		else
		{
			// Could not open file for writing!
			g_Game.AlertMessage( at_logged, "[SDX] WARNING: Could not open file " + szPath + " for writing\n" );
		}
	}
	else
	{
		// WTF?
		if ( szSteamID.Length() == 0 )
			g_Game.AlertMessage( at_logged, "[SDX] WARNING: Attempted to write data on STEAM_ID_PENDING!\n" );
		else
			g_Game.AlertMessage( at_logged, "[SDX] WARNING: Pointer to file " + szPath + " is NULL!\n" );
	}
}

/* Save voted difficulty. Useful on map series */
void SaveDifficulty()
{
	File@ fFile = g_FileSystem.OpenFile( PATH_DATA_DIFFICULTY, OpenFile::WRITE );
	if ( fFile !is null && fFile.IsOpen() )
	{
		fFile.Write( string( iDifficulty ) );
		fFile.Close();
	}
}

/* Attempts to apply modifications of a map's .ent file */
void ApplyMapChanges()
{
	// ...if it exists
	string szPath = "" + PATH_MAPS_SETTINGS + szMapName + ".ent";
	File@ fFile = g_FileSystem.OpenFile( szPath, OpenFile::READ );
	if ( fFile !is null && fFile.IsOpen() )
	{
		int iLine = 0;
		string szLine;
		bool bInEtiquette = false;
		while ( !fFile.EOFReached() )
		{
			iLine++;
			fFile.ReadLine( szLine );
			
			// Blank line
			if ( szLine.Length() == 0 )
				continue;
			
			// Find etiquettes
			if ( szLine == '[GLOBAL]' )
				bInEtiquette = true;
			else if ( szLine == '[BEGINNER]' && iDifficulty == BEGINNER )
				bInEtiquette = true;
			else if ( szLine == '[NORMAL]' && iDifficulty == NORMAL )
				bInEtiquette = true;
			else if ( szLine == '[HARD]' && iDifficulty == HARD )
				bInEtiquette = true;
			else if ( szLine == '[SUICIDE]' && iDifficulty == SUICIDE )
				bInEtiquette = true;
			else if ( szLine == '[HELL]' && iDifficulty == HELL )
				bInEtiquette = true;
			else if ( szLine == '[/GLOBAL]' )
				bInEtiquette = false;
			else if ( szLine == '[/BEGINNER]' && iDifficulty == BEGINNER )
				bInEtiquette = false;
			else if ( szLine == '[/NORMAL]' && iDifficulty == NORMAL )
				bInEtiquette = false;
			else if ( szLine == '[/HARD]' && iDifficulty == HARD )
				bInEtiquette = false;
			else if ( szLine == '[/SUICIDE]' && iDifficulty == SUICIDE )
				bInEtiquette = false;
			else if ( szLine == '[/HELL]' && iDifficulty == HELL )
				bInEtiquette = false;
			
			// Add entity?
			if ( szLine == 'ADD_ENTITY' && bInEtiquette )
			{
				// Get the data
				iLine++;
				fFile.ReadLine( szLine );
				if ( szLine == '{' )
				{
					// Proper start, initialize entity creation
					iLine++;
					fFile.ReadLine( szLine );
					
					CBaseEntity@ pEntity = g_EntityFuncs.Create( "trigger_createentity", g_vecZero, g_vecZero, false );
					
					// It's the end of the entity structure?
					while ( szLine != '}' )
					{
						array< string >@ pre_data = szLine.Split( ' ' );
						if ( pre_data.length() > 2 )
						{
							// Split will remove all spaces on the value data. Fix them
							for ( uint i = 2; i < pre_data.length(); i++ )
							{
								pre_data[ 1 ] += " " + pre_data[ i ];
							}
							pre_data.resize( 2 );
						}
						
						// Remove quotes
						pre_data[ 0 ].Trim( '"' );
						pre_data[ 1 ].Trim( '"' );
						
						// Get keyvalues
						if ( pre_data[ 0 ] == 'origin' )
						{
							Vector temp_Vector;
							g_Utility.StringToVector( temp_Vector, pre_data[ 1 ] );
							g_EntityFuncs.SetOrigin( pEntity, temp_Vector );
						}
						else if ( pre_data[ 0 ] == 'classname' )
							pEntity.KeyValue( "m_iszCrtEntChildClass", pre_data[ 1 ] );
						else if ( pre_data[ 0 ] == 'targetname' )
							pEntity.KeyValue( "m_iszCrtEntChildName", pre_data[ 1 ] );
						else
							pEntity.KeyValue( "-" + pre_data[ 0 ], pre_data[ 1 ] );
						
						// Go to next line
						iLine++;
						fFile.ReadLine( szLine );
					}
					
					// Ended, give a name to the createentity
					pEntity.pev.targetname = "sdx_temp_createentity";
				}
				else
					g_Game.AlertMessage( at_logged, "[SDX] ERROR: Bad ADD_ENTITY structure on " + szPath + "! (Line " + iLine + ")\n" );
			}
			else
			{
				array< string >@ pre_data = szLine.Split( '=' );
				
				// Edit entity?
				if ( pre_data[ 0 ] == 'EDIT_ENTITY' && bInEtiquette )
				{
					// Get the data, first
					iLine++;
					fFile.ReadLine( szLine );
					array< string > KVD_Key;
					array< string > KVD_Value;
					if ( szLine == '{' )
					{
						// Proper start, initialize entity modification
						iLine++;
						fFile.ReadLine( szLine );
						int iKeyValues = 0;
						
						// It's the end of the entity structure?
						while ( szLine != '}' )
						{
							array< string >@ pre_KVD = szLine.Split( ' ' );
							if ( pre_KVD.length() > 2 )
							{
								// Using spaces on value
								for ( uint i = 2; i < pre_KVD.length(); i++ )
								{
									pre_KVD[ 1 ] += " " + pre_KVD[ i ];
								}
								pre_KVD.resize( 2 );
							}
							
							// Remove quotes
							pre_KVD[ 0 ].Trim( '"' );
							pre_KVD[ 1 ].Trim( '"' );
							
							// Get keyvalues
							iKeyValues++;
							
							KVD_Key.resize( iKeyValues );
							KVD_Value.resize( iKeyValues );
							
							KVD_Key[ iKeyValues - 1 ] = pre_KVD[ 0 ];
							KVD_Value[ iKeyValues - 1 ] = pre_KVD[ 1 ];
							
							// Go to next line
							iLine++;
							fFile.ReadLine( szLine );
						}
					}
					else
						g_Game.AlertMessage( at_logged, "[SDX] ERROR: Bad EDIT_ENTITY structure on " + szPath + "! (Line " + iLine + ")\n" );
					
					// Structure must not be empty!
					if ( KVD_Key.length() >= 1 )
					{
						// Attempt to locate entity
						//
						// Search goes at follows:
						// 1. Targetname
						// 2. Classname
						// 3. Brush model number
						bool bFound = false;
						CBaseEntity@ pEntity = null;
						while ( ( @pEntity = g_EntityFuncs.FindEntityByTargetname( pEntity, pre_data[ 1 ] ) ) !is null )
						{
							// Found at least one entity
							bFound = true;
							
							// Pass the keyvalues to the entity
							for ( uint i = 0; i < KVD_Key.length(); i++ )
							{
								pEntity.KeyValue( KVD_Key[ i ], KVD_Value[ i ] );
							}
						}
						
						if ( !bFound )
						{
							@pEntity = null;
							while ( ( @pEntity = g_EntityFuncs.FindEntityByClassname( pEntity, pre_data[ 1 ] ) ) !is null )
							{
								// Found at least one entity
								bFound = true;
								
								// Pass the keyvalues to the entity
								for ( uint i = 0; i < KVD_Key.length(); i++ )
								{
									pEntity.KeyValue( KVD_Key[ i ], KVD_Value[ i ] );
								}
							}
						}
						
						if ( !bFound )
						{
							@pEntity = null;
							while ( ( @pEntity = g_EntityFuncs.FindEntityByString( pEntity, "model", pre_data[ 1 ] ) ) !is null )
							{
								// Found at least one entity
								bFound = true;
								
								// Pass the keyvalues to the entity
								for ( uint i = 0; i < KVD_Key.length(); i++ )
								{
									pEntity.KeyValue( KVD_Key[ i ], KVD_Value[ i ] );
								}
							}
						}
						
						if ( !bFound )
							g_Game.AlertMessage( at_logged, "[SDX] WARNING: EDIT_ENTITY cannot find entity " + pre_data[ 1 ] + "!\n" );
					}
					else
						g_Game.AlertMessage( at_logged, "[SDX] ERROR: Empty EDIT_ENTITY structure on " + szPath + "!\n" );
				}
				else if ( pre_data[ 0 ] == 'DELETE_ENT_BY_TARGETNAME' && bInEtiquette ) // Delete by targetname?
				{
					// Attempt to locate entity
					bool bFound = false;
					CBaseEntity@ pEntity = null;
					while ( ( @pEntity = g_EntityFuncs.FindEntityByTargetname( pEntity, pre_data[ 1 ] ) ) !is null )
					{
						// Found at least one entity
						bFound = true;
						
						// Remove this entity
						g_EntityFuncs.Remove( pEntity );
					}
					
					if ( !bFound )
						g_Game.AlertMessage( at_logged, "[SDX] WARNING: DELETE_ENT_BY_TARGETNAME cannot find entity " + pre_data[ 1 ] + "!\n" );
				}
				else if ( pre_data[ 0 ] == 'DELETE_ENT_BY_CLASSNAME' && bInEtiquette ) // Delete by classname?
				{
					// Attempt to locate entity
					bool bFound = false;
					CBaseEntity@ pEntity = null;
					while ( ( @pEntity = g_EntityFuncs.FindEntityByClassname( pEntity, pre_data[ 1 ] ) ) !is null )
					{
						// Found at least one entity
						bFound = true;
						
						// Remove this entity
						g_EntityFuncs.Remove( pEntity );
					}
					
					if ( !bFound )
						g_Game.AlertMessage( at_logged, "[SDX] WARNING: DELETE_ENT_BY_CLASSNAME cannot find any " + pre_data[ 1 ] + " entities!\n" );
				}
				else if ( pre_data[ 0 ] == 'DELETE_ENT_BY_BRUSHMODEL' && bInEtiquette ) // Delete by brush model number?
				{
					if ( pre_data[ 1 ][ 0 ] == '*' )
					{
						// Attempt to locate entity
						bool bFound = false;
						CBaseEntity@ pEntity = null;
						while ( ( @pEntity = g_EntityFuncs.FindEntityByString( pEntity, "model", pre_data[ 1 ] ) ) !is null )
						{
							// Found at least one entity
							bFound = true;
							
							// Remove this entity
							g_EntityFuncs.Remove( pEntity );
						}
						
						if ( !bFound )
							g_Game.AlertMessage( at_logged, "[SDX] WARNING: DELETE_ENT_BY_BRUSHMODEL cannot find entity " + pre_data[ 1 ] + "!\n" );
					}
					else
						g_Game.AlertMessage( at_logged, "[SDX] ERROR: Not a brush entity on DELETE_ENT_BY_BRUSHMODEL! (Line " + iLine + ")\n" );
				}
			}
		}
		
		fFile.Close();
		
		// Spawn the created entities
		g_EntityFuncs.FireTargets( "sdx_temp_createentity", null, null, USE_TOGGLE, 0.0, 0.1 );
		
		// Remove the temporal entities
		g_Scheduler.SetTimeout( "DeleteTempEnts", 0.2 );
	}
	
	// Apply difficulty SKL CVars
	switch ( iDifficulty )
	{
		case BEGINNER:
		{
			g_EngineFuncs.CVarSetFloat( "sk_player_head", 0.75 );
			g_EngineFuncs.CVarSetFloat( "sk_player_chest", 0.75 );
			g_EngineFuncs.CVarSetFloat( "sk_player_stomach", 0.75 );
			g_EngineFuncs.CVarSetFloat( "sk_player_arm", 0.75 );
			g_EngineFuncs.CVarSetFloat( "sk_player_leg", 0.75 );
			
			g_EngineFuncs.CVarSetFloat( "sk_monster_head", 3.0 ); // Force default on these...
			g_EngineFuncs.CVarSetFloat( "sk_barnacle_bite", 8.0 );
			g_EngineFuncs.CVarSetFloat( "sk_hgrunt_pellets", 7.0 );
			g_EngineFuncs.CVarSetFloat( "sk_hgrunt_gspeed", 500.0 );
			g_EngineFuncs.CVarSetFloat( "sk_controller_speedball", 900.0 );
			g_EngineFuncs.CVarSetFloat( "sk_snark_dmg_bite", 10.0 );
			g_EngineFuncs.CVarSetFloat( "sk_snark_dmg_pop", 5.0 );
			g_EngineFuncs.CVarSetFloat( "sk_scientist_heal", 100.0 );
			g_EngineFuncs.CVarSetFloat( "sk_hwgrunt_minipellets", 1.0 );
			
			break;
		}
		case NORMAL:
		{
			g_EngineFuncs.CVarSetFloat( "sk_player_head", 1.00 );
			g_EngineFuncs.CVarSetFloat( "sk_player_chest", 1.00 );
			g_EngineFuncs.CVarSetFloat( "sk_player_stomach", 1.00 );
			g_EngineFuncs.CVarSetFloat( "sk_player_arm", 1.00 );
			g_EngineFuncs.CVarSetFloat( "sk_player_leg", 1.00 );
			
			g_EngineFuncs.CVarSetFloat( "sk_monster_head", 3.0 ); // Force default on these...
			g_EngineFuncs.CVarSetFloat( "sk_barnacle_bite", 8.0 );
			g_EngineFuncs.CVarSetFloat( "sk_hgrunt_pellets", 7.0 );
			g_EngineFuncs.CVarSetFloat( "sk_hgrunt_gspeed", 500.0 );
			g_EngineFuncs.CVarSetFloat( "sk_controller_speedball", 900.0 );
			g_EngineFuncs.CVarSetFloat( "sk_snark_dmg_bite", 10.0 );
			g_EngineFuncs.CVarSetFloat( "sk_snark_dmg_pop", 5.0 );
			g_EngineFuncs.CVarSetFloat( "sk_scientist_heal", 100.0 );
			g_EngineFuncs.CVarSetFloat( "sk_hwgrunt_minipellets", 1.0 );
			
			break;
		}
		case HARD:
		{
			g_EngineFuncs.CVarSetFloat( "sk_player_head", 1.25 );
			g_EngineFuncs.CVarSetFloat( "sk_player_chest", 1.25 );
			g_EngineFuncs.CVarSetFloat( "sk_player_stomach", 1.25 );
			g_EngineFuncs.CVarSetFloat( "sk_player_arm", 1.25 );
			g_EngineFuncs.CVarSetFloat( "sk_player_leg", 1.25 );
			
			g_EngineFuncs.CVarSetFloat( "sk_monster_head", 3.0 ); // Force default on these...
			g_EngineFuncs.CVarSetFloat( "sk_barnacle_bite", 8.0 );
			g_EngineFuncs.CVarSetFloat( "sk_hgrunt_pellets", 7.0 );
			g_EngineFuncs.CVarSetFloat( "sk_hgrunt_gspeed", 500.0 );
			g_EngineFuncs.CVarSetFloat( "sk_controller_speedball", 900.0 );
			g_EngineFuncs.CVarSetFloat( "sk_snark_dmg_bite", 10.0 );
			g_EngineFuncs.CVarSetFloat( "sk_snark_dmg_pop", 5.0 );
			g_EngineFuncs.CVarSetFloat( "sk_scientist_heal", 100.0 );
			g_EngineFuncs.CVarSetFloat( "sk_hwgrunt_minipellets", 1.0 );
			
			break;
		}
		case SUICIDE:
		{
			g_EngineFuncs.CVarSetFloat( "sk_player_head", 1.50 );
			g_EngineFuncs.CVarSetFloat( "sk_player_chest", 1.50 );
			g_EngineFuncs.CVarSetFloat( "sk_player_stomach", 1.50 );
			g_EngineFuncs.CVarSetFloat( "sk_player_arm", 1.50 );
			g_EngineFuncs.CVarSetFloat( "sk_player_leg", 1.50 );
			
			g_EngineFuncs.CVarSetFloat( "sk_monster_head", 2.0 ); // x3 default --> x2 suicide
			g_EngineFuncs.CVarSetFloat( "sk_barnacle_bite", 16.0 ); // 8 default --> 16 suicide
			g_EngineFuncs.CVarSetFloat( "sk_hgrunt_pellets", 8.0 ); // 7 default --> 8 suicide
			g_EngineFuncs.CVarSetFloat( "sk_hgrunt_gspeed", 600.0 ); // 500 default --> 600 suicide
			g_EngineFuncs.CVarSetFloat( "sk_controller_speedball", 1000.0 ); // 900 default --> 1000 suicide
			g_EngineFuncs.CVarSetFloat( "sk_snark_dmg_bite", 12.0 ); // 10 default --> 12 suicide
			g_EngineFuncs.CVarSetFloat( "sk_snark_dmg_pop", 7.0 ); // 5 default --> 7 suicide
			g_EngineFuncs.CVarSetFloat( "sk_scientist_heal", 50.0 ); // 100 default --> 50 suicide
			g_EngineFuncs.CVarSetFloat( "sk_hwgrunt_minipellets", 1.0 ); // 1 default --> 1 suicide
			
			break;
		}
		case HELL:
		{
			g_EngineFuncs.CVarSetFloat( "sk_player_head", 1.80 );
			g_EngineFuncs.CVarSetFloat( "sk_player_chest", 1.80 );
			g_EngineFuncs.CVarSetFloat( "sk_player_stomach", 1.80 );
			g_EngineFuncs.CVarSetFloat( "sk_player_arm", 1.80 );
			g_EngineFuncs.CVarSetFloat( "sk_player_leg", 1.80 );
			
			g_EngineFuncs.CVarSetFloat( "sk_monster_head", 1.0 ); // x3 default --> x1 hell
			g_EngineFuncs.CVarSetFloat( "sk_barnacle_bite", 32.0 ); // 8 default --> 32 hell
			g_EngineFuncs.CVarSetFloat( "sk_hgrunt_pellets", 9.0 ); // 7 default --> 9 hell
			g_EngineFuncs.CVarSetFloat( "sk_hgrunt_gspeed", 700.0 ); // 500 default --> 700 hell
			g_EngineFuncs.CVarSetFloat( "sk_controller_speedball", 1100.0 ); // 900 default --> 1100 hell
			g_EngineFuncs.CVarSetFloat( "sk_snark_dmg_bite", 14.0 ); // 10 default --> 14 hell
			g_EngineFuncs.CVarSetFloat( "sk_snark_dmg_pop", 9.0 ); // 5 default --> 9 hell
			g_EngineFuncs.CVarSetFloat( "sk_scientist_heal", 25.0 ); // 100 default --> 25 hell
			g_EngineFuncs.CVarSetFloat( "sk_hwgrunt_minipellets", 2.0 ); // 1 default --> 2 hell
			
			break;
		}
	}
	g_Engine.found_secrets = float( iDifficulty ); // Yes, I'm hacky as hell.
}
void DeleteTempEnts()
{
	CBaseEntity@ pCreate = null;
	while ( ( @pCreate = g_EntityFuncs.FindEntityByTargetname( pCreate, "sdx_temp_createentity" ) ) !is null )
	{
		g_EntityFuncs.Remove( pCreate );
	}
}

/* Shows a MOTD message to the player */
void ShowMOTD( CBasePlayer@ pPlayer, const string& in szTitle, const string& in szMessage )
{
	if ( pPlayer is null )
		return;
	
	NetworkMessage title( MSG_ONE_UNRELIABLE, NetworkMessages::ServerName, pPlayer.edict() );
	title.WriteString( szTitle );
	title.End();
	
	uint iChars = 0;
	string szSplitMsg = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
	
	for ( uint uChars = 0; uChars < szMessage.Length(); uChars++ )
	{
		szSplitMsg.SetCharAt( iChars, char( szMessage[ uChars ] ) );
		iChars++;
		if ( iChars == 32 )
		{
			NetworkMessage message( MSG_ONE_UNRELIABLE, NetworkMessages::MOTD, pPlayer.edict() );
			message.WriteByte( 0 );
			message.WriteString( szSplitMsg );
			message.End();
			
			iChars = 0;
		}
	}
	
	// If we reached the end, send the last letters of the message
	if ( iChars > 0 )
	{
		szSplitMsg.Truncate( iChars );
		
		NetworkMessage fix( MSG_ONE_UNRELIABLE, NetworkMessages::MOTD, pPlayer.edict() );
		fix.WriteByte( 0 );
		fix.WriteString( szSplitMsg );
		fix.End();
	}
	
	NetworkMessage endMOTD( MSG_ONE_UNRELIABLE, NetworkMessages::MOTD, pPlayer.edict() );
	endMOTD.WriteByte( 1 );
	endMOTD.WriteString( "\n" );
	endMOTD.End();
	
	NetworkMessage restore( MSG_ONE_UNRELIABLE, NetworkMessages::ServerName, pPlayer.edict() );
	restore.WriteString( g_EngineFuncs.CVarGetString( "hostname" ) );
	restore.End();
}

/* Helper function to find a player by name without being "exact" */
CBasePlayer@ UTIL_FindPlayer( const string& in szName, bool& out bMultiple = false )
{
	CBasePlayer@ pTarget = null;
	int iTargets = 0;
	
	for ( int i = 1; i <= g_Engine.maxClients; i++ )
	{
		CBasePlayer@ iPlayer = g_PlayerFuncs.FindPlayerByIndex( i );
		
		if ( iPlayer !is null && iPlayer.IsConnected() )
		{
			string szCheck = iPlayer.pev.netname;
			uint iCheck = szCheck.Find( szName, 0, String::CaseInsensitive );
			if ( iCheck == 0 )
			{
				iTargets++;
				@pTarget = iPlayer;
			}
		}
	}
	
	if ( iTargets == 1 )
		return pTarget;
	else if ( iTargets >= 2 )
		bMultiple = true;
	
	return null;
}

/* Mystery Gift */
void MysteryGift_CheckUnlock( SayParameters@ pParams )
{
	CBasePlayer@ pPlayer = pParams.GetPlayer();
	int index = pPlayer.entindex();
	
	CustomKeyvalues@ pKVD = pPlayer.GetCustomKeyvalues();
	
	CustomKeyvalue iMGUnlock_pre( pKVD.GetKeyvalue( "$i_mg_can_unlock" ) );
	
	int iMGUnlock = iMGUnlock_pre.GetInteger();
	
	const CCommand@ args = pParams.GetArguments();
	if ( args.ArgC() == 3 )
	{
		if ( bHasMGAccess[ index ] == 1 )
		{
			string szCheck1 = args[ 1 ].ToUppercase();
			string szCheck2 = args[ 2 ].ToUppercase();
			
			if ( szCheck1 == 'REDEEM' )
				g_Scheduler.SetTimeout( "MysteryGift_Search", 0.01, index, "SEARCH#REDEEM|" + szCheck2 );
			else if ( szCheck1 == 'PLAYER' )
			{
				bool bDummy = false; // !!! Something is overflowing the buffer, causing bMultiple to be forced to TRUE !!! This dummy here is to let that garbage data to go somewhere else
				bool bMultiple = false;
				CBasePlayer@ pTarget = UTIL_FindPlayer( szCheck2, bMultiple );
				
				if ( bMultiple )
					g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[SDX] Multiples jugadores encontrados. Se mas especifico\n" );
				else if ( pTarget !is null )
				{
					if ( pTarget is pPlayer )
						g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[SDX] Redimir un regalo hecho por ti mismo? No me hagas reir!\n" );
					else
						g_Scheduler.SetTimeout( "MysteryGift_Search", 0.01, index, "SEARCH#PLAYER|" + g_EngineFuncs.GetPlayerAuthId( pTarget.edict() ) );
				}
				else
					g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "[SDX] Imposible redimir regalo: El jugador no esta conectado o no existe\n" );
			}
		}
	}
	else if ( args.ArgC() == 1 )
	{
		if ( bHasMGAccess[ index ] == 1 )
			MysteryGift_Main( index );
		else
		{
			if ( iMGUnlock == 1 )
			{
				bHasMGAccess[ index ] = 1;
				MysteryGift_Main( index );
				MysteryGift_Welcome( index );
				
				g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] " + pPlayer.pev.netname + " ha desbloqueado el Mystery Gift!\n" );
				pKVD.SetKeyvalue( "$i_mg_can_unlock", 0 );
			}
		}
	}
}

void MysteryGift_Welcome( const int& in index )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( index );
	
	string szInfo = "Vaya! No esperaba que lograras resolver el puzzle secreto. Hoy es tu dia de suerte! Pues si, bienvenido a Mystery Gift (Regalo Misterioso)!";
	szInfo += "\n\nPero que es Mystery Gift? Bueno, no es algo que uno pueda describir facilmente, si bien son regalos que puedes dar y recibir, ";
	szInfo += "su utilidad va mucho mas alla de un mero sistema de recompensas.";
	szInfo += "\n\nMystery Gift no solamente puede darte las recompensas clasicas y demas. Tambien puede proveerte acceso a mapas/misiones exclusivas, ";
	szInfo += "e inclusive caracteristicas unicas que no creias que fueran posibles en este servidor.";
	szInfo += "\n\nBien, ahora que ya explique que es todo esto, te explicare los 3 diferentes tipos de regalos.";
	
	szInfo += "\n\n1. Recibir desde servidor\n\nEsta opcion busca algun regalo en el servidor que te encuentres. Estos regalos son unicos: ";
	szInfo += "Cada servidor provee un regalo diferente, y solamente pueden ser usados en dicho servidor. Estate atento a las noticias del servidor, ";
	szInfo += "los regalos de este tipo se anuncian desde ahi!";
	
	szInfo += "\n\n2. Recibir desde codigo\n\nEsta opcion puede usarse en cualquier lugar independientemente del servidor que te encuentres. ";
	szInfo += "Sin embargo, hay un detalle importante a destacar: Un mismo codigo puede proveer diferentes regalos segun el servidor que te encuentres. ";
	szInfo += "Puedes encontrar codigos resolviendo misiones, mapas y puzzles secretos esparcidos por todo el servidor. Tarea ardua, pero vale la pena!";
	
	szInfo += "\n\n3. Recibir desde jugador\n\nEsta opcion te permite a ti u otro jugador dar cualquier regalo a propio gusto. ";
	szInfo += "Solo ten en cuenta lo siguiente: Regalos creados por un jugador, solamente pueden ser redimidos en el mismo servidor que fueron creados. ";
	szInfo += "Asi que adelante, a repartir regalos!";
	
	szInfo += "\n\nFinalmente, una aclaracion: Todos los regalos, sin importar el tipo, solo pueden ser redimidos una sola vez.";
	szInfo += "\n\nAhora si! Esperamos que disfrutes de esta nueva caracteristica\n\n   -Staff ImperiumSC";
	
	ShowMOTD( pPlayer, "Mystery Gift", szInfo );
}

void MysteryGift_Main( const int& in index )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( index );
	MenuHandler@ state = MenuGetPlayer( pPlayer );
	
	state.InitMenu( pPlayer, MysteryGift_Main_CB );
	state.menu.SetTitle( "Bienvenido a Mystery Gift!\n\n" );
	
	state.menu.AddItem( "Recibir desde servidor\n", any( "item1" ) );
	state.menu.AddItem( "Recibir desde codigo\n", any( "item2" ) );
	state.menu.AddItem( "Recibir desde jugador", any( "item3" ) );
	
	state.OpenMenu( pPlayer, 0, 0 );
}

void MysteryGift_Main_CB( CTextMenu@ menu, CBasePlayer@ pPlayer, int page, const CTextMenuItem@ item )
{
	int index = pPlayer.entindex();
	if ( page == 10 ) return;
	
	string selection;
	item.m_pUserData.retrieve( selection );
	
	if ( selection == 'item1' )
		g_Scheduler.SetTimeout( "MysteryGift_Search", 0.01, index, "SEARCH#SERVER" );
	else if ( selection == 'item2' )
		g_Scheduler.SetTimeout( "MysteryGift_CodeHelp", 0.01, index );
	else if ( selection == 'item3' )
		g_Scheduler.SetTimeout( "MysteryGift_PlayerHelp", 0.01, index );
}

void MysteryGift_CodeHelp( const int& in index )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( index );
	MenuHandler@ state = MenuGetPlayer( pPlayer );
	
	state.InitMenu( pPlayer, MysteryGift_Cancel_CB );
	state.menu.SetTitle( "Recibir desde codigo\n\nIntroduce el codigo para\nredimir su recompensa\n\nUsa el comando /mystery redeem <codigo>\n" );
	
	state.menu.AddItem( "Cancelar", any( "item1" ) );
	
	state.OpenMenu( pPlayer, 0, 0 );
}

void MysteryGift_PlayerHelp( const int& in index )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( index );
	MenuHandler@ state = MenuGetPlayer( pPlayer );
	
	state.InitMenu( pPlayer, MysteryGift_Cancel_CB );
	state.menu.SetTitle( "Recibir desde jugador\n\nSi un jugador tiene un\nregalo para ti, introduce\nsu nombre para redimirla\n\nUsa el comando /mystery player <jugador>\n" );
	
	state.menu.AddItem( "Cancelar", any( "item1" ) );
	
	state.OpenMenu( pPlayer, 0, 0 );
}

void MysteryGift_Cancel_CB( CTextMenu@ menu, CBasePlayer@ pPlayer, int page, const CTextMenuItem@ item )
{
	int index = pPlayer.entindex();
	
	// Input cancel now
	pPlayer.pev.globalname = "";
	@pPlayer.pev.euser1 = null;
	
	if ( page == 10 ) return;
	
	string selection;
	item.m_pUserData.retrieve( selection );
	
	if ( selection == 'item1' )
		g_Scheduler.SetTimeout( "MysteryGift_Main", 0.01, index );
}

void MysteryGift_Search( const int& in index, const string& in szSearch )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( index );
	
	pPlayer.pev.globalname = szSearch;
	@pPlayer.pev.euser1 = pPlayer.edict();
	
	MenuHandler@ state = MenuGetPlayer( pPlayer );
	
	state.InitMenu( pPlayer, MysteryGift_Cancel_CB );
	state.menu.SetTitle( "Buscando algun regalo...\n\nNo te desconectes del servidor\n" );
	
	state.menu.AddItem( "Cancelar", any( "item1" ) );
	
	state.OpenMenu( pPlayer, 0, 0 );
}

void MysteryGift_Handler( CBasePlayer@ pPlayer )
{
	CustomKeyvalues@ pCustom = pPlayer.GetCustomKeyvalues();
	CustomKeyvalue iMGError_pre( pCustom.GetKeyvalue( "$i_mg_error" ) );
	int iMGError = iMGError_pre.GetInteger();
	if ( iMGError > 0 )
	{
		MenuHandler@ state = MenuGetPlayer( pPlayer );
		state.InitMenu( pPlayer, MysteryGift_Cancel_CB );
		
		switch ( iMGError )
		{
			case 1: state.menu.SetTitle( "Que mala suerte!\n\nNo hay ningun regalo aqui\n" ); break;
			case 2: state.menu.SetTitle( "Crei que me olvide\n\nYa has redimido este regalo\n" ); break;
			case 3: state.menu.SetTitle( "Estoy muy lejos de casa\n\nNo puedes redimir regalos en este momento\n" ); break;
			case 4: state.menu.SetTitle( "Esto no deberia pasar!\n\nError inesperado en el servidor\n" ); break;
			case 5: state.menu.SetTitle( "No soy metiche\n\nEste regalo no te pertenece\n" ); break;
			case 6: state.menu.SetTitle( "He llegado tarde\n\nEste regalo ya ha sido redimido\n" ); break;
			case 99: state.menu.SetTitle( "Listo!\n\nRegalo recibido satisfactoriamente\n" ); break; // Not an error message
		}
		
		state.menu.AddItem( "Regresar", any( "item1" ) );
		
		state.OpenMenu( pPlayer, 0, 0 );
		pCustom.SetKeyvalue( "$i_mg_error", 0 );
	}
	
	CustomKeyvalue szMGMessage_pre( pCustom.GetKeyvalue( "$s_mg_message" ) );
	string szMGMessage = szMGMessage_pre.GetString();
	if ( szMGMessage.Length() > 0 )
	{
		// Gift message
		szMGMessage.Replace( '-', ' ' );
		array< string >@ pre_data = szMGMessage.Split( '$' );
		string szFullMessage = "";
		
		for ( uint i = 1; i < pre_data.length(); i++ )
		{
			pre_data[ i ].Replace( '!n', '\n' );
			szFullMessage += pre_data[ i ];
		}
		
		ShowMOTD( pPlayer, pre_data[ 0 ], szFullMessage );
		
		// Really? You crash?
		//pCustom.SetKeyvalue( "$s_mg_message", "" );
		pPlayer.KeyValue( "$s_mg_message", "" );
	}
}
