/*
	Survival DeluXe: Auxilliary Scripts
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

#pragma semicolon 1

#include <amxmodx>
#include <engine>
#include <hamsandwich>

new const szDataPath[] = "scripts/plugins/SDX"; // Main directory containing all data

new const msgSVC_TEMPENTITY = 23; // SVC_TEMPENTITY message
new msgTextMsg;

enum // e_iWeaponType
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

enum // e_iPlayerPerk
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

enum // e_iDifficulty
{
	UNDEFINED = 0,
	BEGINNER,
	NORMAL,
	HARD,
	SUICIDE,
	HELL
};

public plugin_init()
{
	register_plugin( "SDX Helper", "1.0", "Giegue" );
	
	// Preliminary
	msgTextMsg = get_user_msgid( "TextMsg" );
	
	// System hooks
	register_event( "CurWeapon", "CW_UpdateData", "b", "1=1" );
	RegisterHam( Ham_TakeDamage, "player", "plTakeDamage_Pre" );
	RegisterHam( Ham_TakeDamage, "player", "plTakeDamage_Post", 1 );
	RegisterHam( Ham_SC_TakeHealth, "player", "plTakeHealth" );
	RegisterHam( Ham_SC_TakeArmor, "player", "plTakeArmor" );
	register_message( msgSVC_TEMPENTITY, "plShowHealth" );
	register_message( msgTextMsg, "plTextMsg" );
	
	// Initialize external hooks 5 seconds after map start
	// This is to give time for any custom entity to register within the engine
	set_task( 5.0, "InitWeaponHooks" );
	set_task( 5.0, "InitMonsterHooks" );
	
	// Auxiliar hooks
	RegisterHam( Ham_TakeDamage, "monster_sentry", "score_disable" );
	RegisterHam( Ham_TakeDamage, "monster_miniturret", "score_disable" );
	RegisterHam( Ham_TakeDamage, "monster_turret", "score_disable" );
	RegisterHam( Ham_TakeDamage, "monster_robogrunt", "score_disable" );
	
	// Init map's maxhealth/maxarmor
	new iMaxHealth = 100;
	new iMaxArmor = 100;
	
	// Load map .cfg file if it exists
	new szMap[ 33 ], szFile[ 66 ], pointer;
	get_mapname( szMap, charsmax( szMap ) );
	formatex( szFile, charsmax( szFile ), "maps/%s.cfg", szMap );
	pointer = fopen( szFile, "r", true );
	if ( pointer )
	{
		new szLine[ 66 ], cvar[ 16 ], value[ 5 ];
		while ( fgets( pointer, szLine, charsmax( szLine ) ) )
		{
			// Replace newlines
			replace_string( szLine, charsmax( szLine ), "^n", "" );
			if ( !szLine[ 0 ] || szLine[ 0 ] == '#' || szLine[ 0 ] == '/' )
				continue;
			
			parse( szLine, cvar, charsmax( cvar ), value, charsmax( value ) );
			
			// Attempt to find .cfg configurations
			
			if ( equal( cvar, "starthealth" ) ) // Health
			{
				static iCFGHealth;
				iCFGHealth = str_to_num( value );
				if ( iCFGHealth > 100.0 )
					iMaxHealth = iCFGHealth; // Starting health is greater than 100, so max is going to be this much
			}
			else if ( equal( cvar, "maxhealth" ) )
			{
				static iCFGHealth;
				iCFGHealth = str_to_num( value );
				if ( iCFGHealth > 1.0 )
					iMaxHealth = iCFGHealth; // Force maxhealth to this value
			}
			else if ( equal( cvar, "startarmor" ) ) // Armor
			{
				static iCFGArmor;
				iCFGArmor = str_to_num( value );
				if ( iCFGArmor > 100.0 )
					iMaxArmor = iCFGArmor; // Starting armor is greater than 100, so max is going to be this much
			}
			else if ( equal( cvar, "maxarmor" ) )
			{
				static iCFGArmor;
				iCFGArmor = str_to_num( value );
				if ( iCFGArmor > 1.0 )
					iMaxArmor = iCFGArmor; // Force maxarmor to this value
			}
		}
		
		fclose( pointer );
	}
	
	// Create CVars for retrieval in AS main script
	new pMaxHealth = create_cvar( "_sdx_map_maxhealth", "100", FCVAR_NONE, "Internal SDX CVar ~ Map's Maximum Health", true, 1.0, true, 9999.0 );
	new pMaxArmor = create_cvar( "_sdx_map_maxarmor", "100", FCVAR_NONE, "Internal SDX CVar ~ Map's Maximum Armor", true, 1.0, true, 9999.0 );
	set_pcvar_num( pMaxHealth, iMaxHealth );
	set_pcvar_num( pMaxArmor, iMaxArmor );
}

public InitWeaponHooks()
{
	// Build path route
	new szFullPath[ 64 ];
	formatex( szFullPath, charsmax( szFullPath ), "%s/types.ini", szDataPath );
	
	// Attempt to open file "types.ini"
	new pFile = fopen( szFullPath, "r" );
	if ( pFile )
	{
		// File open successful, iterate through all entries
		new szLine[ 64 ];
		while ( fgets( pFile, szLine, charsmax( szLine ) ) )
		{
			// Replace newlines
			replace_string( szLine, charsmax( szLine ), "^n", "" );
			
			// Empty line or comment
			if ( !szLine[ 0 ] || szLine[ 0 ] == ';' )
				continue;
			
			// Parse the weapon classname and it's type
			static szClassname[ 32 ], szType[ 16 ], szFlag[ 16 ];
			copy( szFlag, charsmax( szFlag ), "" ); // Empty flag string, it's not used on all lines (static reset)
			parse( szLine, szClassname, charsmax( szClassname ), szType, charsmax( szType ), szFlag, charsmax( szFlag ) );
			
			// Create the entity
			static pEntity;
			pEntity = create_entity( szClassname );
			if ( pEntity )
			{
				// Register these hooks for these types of weapons
				if ( equal( szType, "medkit" ) )
				{
					RegisterHamFromEntity( Ham_Weapon_SendWeaponAnim, pEntity, "WeaponAnimation" );
				}
				else if ( !equal( szType, "meele" ) && !equal( szType, "shotgun" ) && !equal( szFlag, "ignore_reload" ) )
					RegisterHamFromEntity( Ham_Weapon_Reload, pEntity, "WeaponReload" );
				
				remove_entity( pEntity );
			}
		}
		
		// Done
		fclose( pFile );
	}
	else
	{
		// Could not open file!
		log_message( "[SDX] ERROR: Could not open system file %s", szFullPath );
	}
}

public InitMonsterHooks()
{
	// Build path route
	new szFullPath[ 64 ];
	formatex( szFullPath, charsmax( szFullPath ), "%s/monsters.ini", szDataPath );
	
	// Attempt to open file "monsters.ini"
	new pFile = fopen( szFullPath, "r" );
	if ( pFile )
	{
		// File open successful, iterate through all entries
		new szLine[ 64 ];
		while ( fgets( pFile, szLine, charsmax( szLine ) ) )
		{
			// Replace newlines
			replace_string( szLine, charsmax( szLine ), "^n", "" );
			
			// Empty line or comment
			if ( !szLine[ 0 ] || szLine[ 0 ] == ';' )
				continue;
			
			// Must be a valid monster entity
			if ( contain( szLine, "monster_" ) != -1 )
			{
				// Create the entity
				static pEntity;
				pEntity = create_entity( szLine );
				if ( pEntity )
				{
					// Register the hooks
					RegisterHamFromEntity( Ham_TakeDamage, pEntity, "mnTakeDamage" );
					RegisterHamFromEntity( Ham_Killed, pEntity, "mnKilled", 1 );
					
					remove_entity( pEntity );
				}
			}
			else
				log_message( "[SDX] WARNING: Non-monster classname %s on file %s", szLine, szFullPath );
		}
		
		// Done
		fclose( pFile );
	}
	else
	{
		// Could not open file!
		log_message( "[SDX] ERROR: Could not open system file %s", szFullPath );
	}
}

public CW_UpdateData( player )
{
	// Send update flag
	DispatchKeyValue( player, "$i_sdx_wpn_update", "1" );
}

public WeaponReload( weapon )
{
	static player;
	player = entity_get_edict( weapon, EV_ENT_owner );
	
	// Here's hoping this is the only time I have to do this shit...
	static szClassname[ 32 ];
	entity_get_string( weapon, EV_SZ_classname, szClassname, charsmax( szClassname ) );
	if ( equal( szClassname, "weapon_hlshotgun" ) )
		return HAM_IGNORED; // DO NOT OVERRIDE!
	
	DispatchKeyValue( player, "$i_sdx_wpn_doreload", "1" );
	
	// Let main system handle reload, always block here
	return HAM_SUPERCEDE;
}

public WeaponAnimation( weapon, iAnim, skiplocal, body )
{
	// Weapon must play the excepted animation for code to run
	static iTargetAnim;
	iTargetAnim = entity_get_int( weapon, EV_INT_iuser4 );
	
	if ( iAnim == iTargetAnim )
	{
		// OK. Let game know player performed this animation on the weapon
		static player;
		player = entity_get_edict( weapon, EV_ENT_owner );
		
		DispatchKeyValue( player, "$i_sdx_wpn_runheal", "1" );
	}
}

// MonsterInfo
public plShowHealth( msg_id, msg_dest, msg_entity )
{
	// Only care if the message is being sent to a player
	if ( msg_entity )
	{
		if ( entity_get_int( msg_entity, EV_INT_flags ) & FL_CLIENT )
		{
			// Hook TE_TEXTMESSAGE's ONLY.
			if ( get_msg_arg_int( 1 ) == TE_TEXTMESSAGE )
			{
				// Monster/Player info has exactly 17 arguments, so go there
				if ( get_msg_args() == 17 )
				{
					// Aiming at an enemy?
					// I literally had to dissassemble the message and bruteforce check :S
					if ( get_msg_arg_int( 6 ) == 171 && get_msg_arg_int( 7 ) == 23 && get_msg_arg_int( 8 ) == 7 /* && get_msg_arg_int( 10 ) == 207 && get_msg_arg_int( 11 ) == 23 && get_msg_arg_int( 12 ) == 7 */ )
					{
						// Retrieve cross-script data
						static Float:temp_VUser2[ 3 ];
						entity_get_vector( msg_entity, EV_VEC_vuser2, temp_VUser2 );
						
						// Get current perk
						static plPerk;
						plPerk = floatround( temp_VUser2[ 2 ], floatround_floor );
						
						// Commando perk only!
						if ( plPerk != COMMANDO )
							return PLUGIN_HANDLED; // Block the message, don't show enemy info!
						
						// Get target entity
						static pTarget, dummy;
						get_user_aiming( msg_entity, pTarget, dummy );
						
						// Calculate distance between player and target entity
						static Float:vecSelfOrigin[ 3 ], Float:vecTargetOrigin[ 3 ];
						entity_get_vector( msg_entity, EV_VEC_origin, vecSelfOrigin );
						
						// Target entity is a brush entity? (breakable with HUD info)
						static szModel[ 6 ];
						entity_get_string( pTarget, EV_SZ_model, szModel, charsmax( szModel ) );
						if ( szModel[ 0 ] == '*' )
							get_brush_entity_origin( pTarget, vecTargetOrigin );
						else
							entity_get_vector( pTarget, EV_VEC_origin, vecTargetOrigin );
						
						// Get viewable distance
						static iDistanceHealth;
						iDistanceHealth = floatround( temp_VUser2[ 1 ], floatround_floor );
						
						// 1 foot = 16 units
						// 1 foot = 304.80 milimeters
						// 1 meter = 3.28 foots
						// 1 meter = 52.48 units
						if ( get_distance_f( vecSelfOrigin, vecTargetOrigin ) > ( float( iDistanceHealth ) * 52.48 ) )
							return PLUGIN_HANDLED; // Too far away, cannot see enemy info
					}
				}
			}
		}
	}
	
	return PLUGIN_CONTINUE; // Ignore and show info
}

// Death Message
public plTextMsg( msg_id, msg_dest, msg_entity )
{
	// Don't alter other messages
	if ( get_msg_arg_int( 1 ) == 1 )
	{
		// Get the death message
		new szMessage[ 256 ];
		get_msg_arg_string( 2, szMessage, charsmax( szMessage ) );
		
		// THIS. IS. RIDICULOUS.
		// But the text has no formatting and is sent directly, this makes it MUCH harder to find stuff!
		
		// Case 1: Attacker killed
		if ( contain( szMessage, "was gibbed." ) != -1 )
		{
			if ( contain( szMessage, "was killed by a" ) == -1 )
			{
				// Set new message
				replace_string( szMessage, charsmax( szMessage ), "was gibbed.", "though that it was funny to friendly fire partners." );
				set_msg_arg_string( 2, szMessage );
			}
		}
		else
		{
			// Case 2: Victim killed
			new iCursor;
			iCursor = contain( szMessage, ":" );
			if ( iCursor != -1 )
			{
				new szName1[ 32 ];
				new szName2[ 32 ];
				
				for ( new i = 0; i < iCursor - 1; i++ )
				{
					// Save attacker name
					szName1[ i ] = szMessage[ i ];
				}
				
				if ( szMessage[ iCursor - 1 ] == ' ' && szMessage[ iCursor ] == ':' && szMessage[ iCursor + 1 ] == ' ' )
				{
					// Erase the contents
					szMessage[ iCursor ] = '.';
					for ( new i = 0; i < strlen( szMessage ); i++ )
					{
						if ( szMessage[ i ] == ':' )
						{
							szMessage[ i ] = '.';
							szMessage[ i + 1 ] = '.';
							break;
						}
						else
							szMessage[ i ] = '.';
					}
					
					// Set new message
					replace_string( szMessage, charsmax( szMessage ), ".", "" );
					replace_string( szMessage, charsmax( szMessage ), "^n", "" );
					copy( szName2, charsmax( szName2 ), szMessage ); // Save victim name
					formatex( szMessage, charsmax( szMessage ), "%s was killed by its teammate %s.^n", szName2, szName1 );
					set_msg_arg_string( 2, szMessage );
				}
			}
		}
	}
}

// Player takedamage (Pre)
public plTakeDamage_Pre( victim, inflictor, attacker, Float:dmg, dmgbits )
{
	// Retrieve cross-script data
	static Float:temp_VUser2[ 3 ];
	entity_get_vector( victim, EV_VEC_vuser2, temp_VUser2 );
	
	// Get current perk
	static plPerk;
	plPerk = floatround( temp_VUser2[ 2 ], floatround_floor );
	
	switch ( plPerk )
	{
		case FIELD_MEDIC:
		{
			// Damaged by poison?
			if ( dmgbits & DMG_POISON )
			{
				// Get poison resistance
				static iPoisonResistance;
				iPoisonResistance = floatround( temp_VUser2[ 0 ], floatround_floor );
				
				// Calculate new damage
				static Float:flNewDmg;
				flNewDmg = dmg * ( 100.0 - float( iPoisonResistance ) ) / 100.0;
				
				// Set new damage
				SetHamParamFloat( 4, flNewDmg );
			}
		}
		case BERSERKER:
		{
			// Damaged by poison?
			if ( dmgbits & DMG_POISON )
			{
				// Get poison resistance
				static iPoisonResistance;
				iPoisonResistance = floatround( temp_VUser2[ 0 ], floatround_floor );
				
				// Calculate new damage
				static Float:flNewDmg;
				flNewDmg = dmg * ( 100.0 - float( iPoisonResistance ) ) / 100.0;
				
				// Set new damage
				SetHamParamFloat( 4, flNewDmg );
			}
			else
			{
				// EXCLUDE falldamage!
				if ( attacker )
				{
					// Get damage resistance
					static iDamageResistance;
					iDamageResistance = floatround( temp_VUser2[ 1 ], floatround_floor );
					
					// Calculate new damage
					static Float:flNewDmg;
					flNewDmg = dmg * ( 100.0 - float( iDamageResistance ) ) / 100.0;
					
					// Set new damage
					SetHamParamFloat( 4, flNewDmg );
				}
			}
		}
		case SUPPORT_SPECIALIST:
		{
			// Falldamage ONLY!
			if ( !attacker )
			{
				// Get damage resistance
				static iDamageResistance;
				iDamageResistance = floatround( temp_VUser2[ 1 ], floatround_floor );
				
				// Calculate new damage
				static Float:flNewDmg;
				flNewDmg = dmg * ( 100.0 - float( iDamageResistance ) ) / 100.0;
				
				// Set new damage
				SetHamParamFloat( 4, flNewDmg );
			}
		}
		case SURVIVALIST:
		{
			// EXCLUDE falldamage!
			if ( attacker )
			{
				// Use this var to check level
				static szPoisonResistance[ 5 ], iPoisonResistance;
				entity_get_string( victim, EV_SZ_noise1, szPoisonResistance, charsmax( szPoisonResistance ) );
				iPoisonResistance = str_to_num( szPoisonResistance );
				
				// Level 1+?
				if ( iPoisonResistance )
				{
					// Don't let the player gib, ever.
					SetHamParamInteger( 5, ( dmgbits | DMG_NEVERGIB ) &~ DMG_ALWAYSGIB );
				}
			}
		}
		case DEMOLITIONS:
		{
			// Damaged by explosion?
			if ( dmgbits & DMG_BLAST )
			{
				// Get damage resistance
				static iDamageResistance;
				iDamageResistance = floatround( temp_VUser2[ 1 ], floatround_floor );
				
				// Calculate new damage
				static Float:flNewDmg;
				flNewDmg = dmg * ( 100.0 - float( iDamageResistance ) ) / 100.0;
				
				// Set new damage
				SetHamParamFloat( 4, flNewDmg );
			}
		}
	}
	
	// The damage came from another player?
	if ( entity_get_int( attacker, EV_INT_flags ) & FL_CLIENT )
	{
		static szClassname[ 32 ], dummy1, dummy2;
		get_weaponname( get_user_weapon( attacker, dummy1, dummy2 ), szClassname, charsmax( szClassname ) );
		
		// Exclude these weapons, prevent unintentional damage
		if ( equal( szClassname, "weapon_shockrifle" ) || equal( szClassname, "weapon_grapple" ) )
			return HAM_IGNORED;
		
		// Friendly Fire!
		
		// Change classify to allow damage
		DispatchKeyValue( victim, "classify", "-1" ); // -1 = CLASS_NONE
		
		static Float:flVictimDmg; // Victim retrieves this much damage
		static Float:flAttackerDmg; // Attacker retrieves this much damage (mirrored damage)
		flVictimDmg = 0.0;
		flAttackerDmg = 0.0;
		
		// Get map's difficulty
		switch ( floatround( get_global_float( GL_found_secrets ), floatround_floor ) )
		{
			case BEGINNER:
			{
				flVictimDmg = dmg * 20.0 / 100.0;
				flAttackerDmg = dmg * 30.0 / 100.0;
			}
			case NORMAL:
			{
				flVictimDmg = dmg * 30.0 / 100.0;
				flAttackerDmg = dmg * 40.0 / 100.0;
			}
			case HARD:
			{
				flVictimDmg = dmg * 40.0 / 100.0;
				flAttackerDmg = dmg * 50.0 / 100.0;
			}
			case SUICIDE:
			{
				flVictimDmg = dmg * 50.0 / 100.0;
				flAttackerDmg = dmg * 70.0 / 100.0;
			}
			case HELL:
			{
				flVictimDmg = dmg * 60.0 / 100.0;
				flAttackerDmg = dmg * 80.0 / 100.0;
			}
		}
		
		// Set damage to VICTIM
		SetHamParamFloat( 4, flVictimDmg );
		SetHamParamInteger( 5, ( dmgbits | DMG_NEVERGIB ) &~ DMG_ALWAYSGIB ); // Victim should never be gibbed from friendly fire. Reduces damage done by trolls
		
		// Mirror the damage. MIRROR Friendly Fire
		fakedamage( attacker, "Mirror Friendly Fire", flAttackerDmg, DMG_ALWAYSGIB ); // Attacker should always be gibbed from mirrored damage. Punishes trolls
	}
	
	return HAM_IGNORED;
}

// Player takedamage (Post)
public plTakeDamage_Post( victim, inflictor, attacker, Float:dmg, dmgbits )
{
	// The damage came from another player?
	if ( entity_get_int( attacker, EV_INT_flags ) & FL_CLIENT )
	{
		// Restore player classify
		DispatchKeyValue( victim, "classify", "2" ); // 2 = CLASS_PLAYER
	}
}

// Player takehealth
public plTakeHealth( player, Float:health, damagebits, health_cap )
{
	// Retrieve cross-script data
	static Float:temp_VUser2[ 3 ];
	entity_get_vector( player, EV_VEC_vuser2, temp_VUser2 );
	
	// Get current perk
	static plPerk;
	plPerk = floatround( temp_VUser2[ 2 ], floatround_floor );
	
	// Survivalist perk ONLY!
	if ( plPerk == SURVIVALIST )
	{
		// Get extra health increase
		static iExtraHealth;
		iExtraHealth = floatround( temp_VUser2[ 1 ], floatround_floor );
		
		// Calculate new health
		static Float:flNewHealth;
		flNewHealth = health * ( 100.0 + float( iExtraHealth ) ) / 100.0;
		
		// Set new health
		SetHamParamFloat( 2, flNewHealth );
	}
}

// Player takearmor
public plTakeArmor( player, Float:armor, damagebits, armor_cap )
{
	// Retrieve cross-script data
	static Float:temp_VUser2[ 3 ];
	entity_get_vector( player, EV_VEC_vuser2, temp_VUser2 );
	
	// Get current perk
	static plPerk;
	plPerk = floatround( temp_VUser2[ 2 ], floatround_floor );
	
	// Medic perk ONLY!
	if ( plPerk == FIELD_MEDIC )
	{
		// Get extra armor increase
		static iExtraArmor;
		iExtraArmor = floatround( temp_VUser2[ 1 ], floatround_floor );
		
		// Calculate new armor
		static Float:flNewArmor;
		flNewArmor = armor * ( 100.0 + float( iExtraArmor ) ) / 100.0;
		
		// Set new armor
		SetHamParamFloat( 2, flNewArmor );
	}
}

// Monster takedamage
public mnTakeDamage( victim, inflictor, attacker, Float:dmg, dmgbits )
{
	// Attacker has to be valid
	if ( !is_valid_ent( attacker ) )
		return HAM_IGNORED;
	
	// Victim must NOT be player ally (Prevent's perk farm exploitation)
	if ( entity_get_int( victim, EV_INT_iuser4 ) )
		return HAM_IGNORED;
	
	// Only care about TakeDamage if attacker is player
	if ( entity_get_int( attacker, EV_INT_flags ) & FL_CLIENT )
	{
		// Retrieve cross-script data
		static Float:temp_VUser2[ 3 ];
		entity_get_vector( attacker, EV_VEC_vuser2, temp_VUser2 );
		
		// Get current perk
		static plPerk;
		plPerk = floatround( temp_VUser2[ 2 ], floatround_floor );
		
		// Get weapon type
		static szWeaponType_pre[ 2 ], iWeaponType;
		entity_get_string( attacker, EV_SZ_noise2, szWeaponType_pre, charsmax( szWeaponType_pre ) );
		iWeaponType = str_to_num( szWeaponType_pre );
		
		// Get BASE damage increase (if applicable later on)
		static szExtraBaseDamage_pre[ 4 ], iExtraBaseDamage;
		entity_get_string( attacker, EV_SZ_noise3, szExtraBaseDamage_pre, charsmax( szExtraBaseDamage_pre ) );
		iExtraBaseDamage = str_to_num( szExtraBaseDamage_pre );
		
		// Get HEADSHOT damage increase (if applicable later on)
		static Float:flExtraHSDamage;
		flExtraHSDamage = temp_VUser2[ 0 ];
		
		// Get hitzone
		static dummy, iHitZone;
		get_user_aiming( attacker, dummy, iHitZone );
		
		// Meele damage?
		static iMeeleDamage;
		iMeeleDamage = 0;
		if ( iWeaponType == MEELE )
		{
			// Add current damage
			iMeeleDamage = floatround( dmg, floatround_floor );
		}
		
		// Shotgun damage?
		static iShotgunDamage;
		iShotgunDamage = 0;
		if ( iWeaponType == SHOTGUN )
		{
			// Add current damage
			iShotgunDamage = floatround( dmg, floatround_floor );
		}
		
		// Explosive damage?
		static iExplosiveDamage;
		iExplosiveDamage = 0;
		if ( dmgbits & DMG_BLAST )
		{
			// Add current damage
			iExplosiveDamage = floatround( dmg, floatround_floor );
		}
		
		// Rifle damage?
		static iRifleDamage;
		iRifleDamage = 0;
		if ( iWeaponType == RIFLE )
		{
			// Add current damage
			iRifleDamage = floatround( dmg, floatround_floor );
		}
		
		// Other damage?
		static iOtherDamage;
		iOtherDamage = 0;
		if ( iWeaponType == OTHER )
		{
			// Must NOT be explosive damage
			if ( dmgbits & DMG_BLAST )
			{
				// Dummy
			}
			else
			{
				// Add current damage
				iOtherDamage = floatround( dmg, floatround_floor );
			}
		}
		
		// Player is using perk...
		switch ( plPerk )
		{
			case BERSERKER:
			{
				// Using meele weapon?
				if ( iWeaponType == MEELE )
				{
					// Increase BASE damage
					static Float:flNewDmg;
					flNewDmg = dmg * ( 100.0 + float( iExtraBaseDamage ) ) / 100.0;
					
					// Set new damage
					SetHamParamFloat( 4, flNewDmg );
					
					// Add new damage to perk status
					iMeeleDamage += floatround( flNewDmg - dmg, floatround_floor );
				}
			}
			case SHARPSHOOTER:
			{
				// Pistol or Sniper(Crossbow) weapon?
				if ( iWeaponType == PISTOL || iWeaponType == SNIPER )
				{
					// Increase BASE damage
					static Float:flNewDmg;
					flNewDmg = dmg * ( 100.0 + float( iExtraBaseDamage ) ) / 100.0;
					
					// Player hit the monster with a HeadShot?
					if ( iHitZone == 1 ) // On SC, headshots are HitZone 1
					{
						// Increase HEADSHOT damage
						flNewDmg = flNewDmg * ( 100.0 + flExtraHSDamage ) / 100.0;
					}
					
					// Set new damage
					SetHamParamFloat( 4, flNewDmg );
				}
			}
			case SUPPORT_SPECIALIST:
			{
				// Affect Shotguns
				if ( iWeaponType == SHOTGUN )
				{
					// Increase BASE damage
					static Float:flNewDmg;
					flNewDmg = dmg * ( 100.0 + float( iExtraBaseDamage ) ) / 100.0;
					
					// Player hit the monster with a HeadShot?
					if ( iHitZone == 1 ) // On SC, headshots are HitZone 1
					{
						// Increase HEADSHOT damage
						flNewDmg = flNewDmg * ( 100.0 + flExtraHSDamage ) / 100.0;
					}
					
					// Set new damage
					SetHamParamFloat( 4, flNewDmg );
					
					// Add new damage to perk status
					iShotgunDamage += floatround( flNewDmg - dmg, floatround_floor );
				}
				
				// Grenade?
				static szClassname[ 32 ];
				entity_get_string( inflictor, EV_SZ_classname, szClassname, charsmax( szClassname ) );
				if ( equal( szClassname, "grenade" ) )
				{
					// HAND Grenade?
					if ( entity_get_float( inflictor, EV_FL_friction ) == 0.8 )
					{
						// Get handgrenade damage increase
						static szExtraHGDamage_pre[ 4 ], iExtraHGDamage;
						entity_get_string( attacker, EV_SZ_noise1, szExtraHGDamage_pre, charsmax( szExtraHGDamage_pre ) );
						iExtraHGDamage = str_to_num( szExtraHGDamage_pre );
						
						// Increase the damage of the grenade
						static Float:flNewDmg;
						flNewDmg = dmg * ( 100.0 + float( iExtraHGDamage ) ) / 100.0;
						
						// Set new damage
						SetHamParamFloat( 4, flNewDmg );
					}
				}
			}
			case DEMOLITIONS:
			{
				// Any weapon that relies on explosions?
				if ( dmgbits & DMG_BLAST )
				{
					// Increase BASE damage
					static Float:flNewDmg;
					flNewDmg = dmg * ( 100.0 + float( iExtraBaseDamage ) ) / 100.0;
					
					// Set new damage
					SetHamParamFloat( 4, flNewDmg );
					
					// Add new damage to perk status
					iExplosiveDamage += floatround( flNewDmg - dmg, floatround_floor );
				}
			}
			case COMMANDO:
			{
				// Rifle weapon?
				if ( iWeaponType == RIFLE )
				{
					// Increase BASE damage
					static Float:flNewDmg;
					flNewDmg = dmg * ( 100.0 + float( iExtraBaseDamage ) ) / 100.0;
					
					// Set new damage
					SetHamParamFloat( 4, flNewDmg );
					
					// Add new damage to perk status
					iRifleDamage += floatround( flNewDmg - dmg, floatround_floor );
				}
			}
			case SURVIVALIST:
			{
				// Other type of weapons?
				if ( iWeaponType == OTHER )
				{
					// Must NOT be explosive damage
					if ( dmgbits & DMG_BLAST )
					{
						// Dummy
					}
					else
					{
						// Increase BASE damage
						static Float:flNewDmg;
						flNewDmg = dmg * ( 100.0 + float( iExtraBaseDamage ) ) / 100.0;
						
						// Player hit the monster with a HeadShot?
						if ( iHitZone == 1 ) // On SC, headshots are HitZone 1
						{
							// Increase HEADSHOT damage
							flNewDmg = flNewDmg * ( 100.0 + flExtraHSDamage ) / 100.0;
						}
						
						// Set new damage
						SetHamParamFloat( 4, flNewDmg );
						
						// Add new damage to perk status
						iOtherDamage += floatround( flNewDmg - dmg, floatround_floor );
					}
				}
			}
		}
		
		// Perk status updates
		if ( !entity_get_int( victim, EV_INT_iuser3 ) )
		{
			if ( iHitZone == 1 )
			{
				if ( iWeaponType == PISTOL || iWeaponType == SNIPER )
				{
					// Tell main system that we did a headshot
					DispatchKeyValue( attacker, "$i_sdx_add_headshot", "1" );
				}
			}
		}
		else
		{
			// Do not "re-add" to the total if monster was already killed before (this is a revive)
			iMeeleDamage = 0;
			iShotgunDamage = 0;
			iExplosiveDamage = 0;
			iRifleDamage = 0;
			iOtherDamage = 0;
		}
		
		static szMeeleDamage[ 5 ], szShotgunDamage[ 5 ], szExplosiveDamage[ 5 ], szRifleDamage[ 5 ], szOtherDamage[ 5 ];
		formatex( szMeeleDamage, charsmax( szMeeleDamage ), "%i", iMeeleDamage );
		formatex( szShotgunDamage, charsmax( szShotgunDamage ), "%i", iShotgunDamage );
		formatex( szExplosiveDamage, charsmax( szExplosiveDamage ), "%i", iExplosiveDamage );
		formatex( szRifleDamage, charsmax( szRifleDamage ), "%i", iRifleDamage );
		formatex( szOtherDamage, charsmax( szOtherDamage ), "%i", iOtherDamage );
		DispatchKeyValue( attacker, "$i_sdx_add_meeledmg", szMeeleDamage );
		DispatchKeyValue( attacker, "$i_sdx_add_shotgundmg", szShotgunDamage );
		DispatchKeyValue( attacker, "$i_sdx_add_blastdmg", szExplosiveDamage );
		DispatchKeyValue( attacker, "$i_sdx_add_rifledmg", szRifleDamage );
		DispatchKeyValue( attacker, "$i_sdx_add_otherdmg", szOtherDamage );
	}
	
	return HAM_IGNORED;
}

// Monster killed
public mnKilled( victim, attacker, shouldgib )
{
	// Are we still valid?
	if ( is_valid_ent( victim ) )
	{
		// Save "dead" flag
		entity_set_int( victim, EV_INT_iuser3, 1 );
	}
}

/* Disable score giving from wrench repairing */
public score_disable( victim, inflictor, attacker, Float:dmg, dmgbits )
{
	// Players only
	if ( entity_get_int( attacker, EV_INT_flags ) & FL_CLIENT )
	{
		// !!! Only care if player ally !!!
		if ( entity_get_int( victim, EV_INT_iuser4 ) )
		{	
			// Affect wrench repair only
			if ( get_user_weapon( attacker ) == 20 )
			{
				static Float:flHealth, Float:flMaxHealth;
				flHealth = entity_get_float( victim, EV_FL_health );
				flMaxHealth = entity_get_float( victim, EV_FL_max_health );
				
				if ( ( flHealth + dmg ) > flMaxHealth )
					entity_set_float( victim, EV_FL_health, flMaxHealth );
				else
					entity_set_float( victim, EV_FL_health, ( flHealth + dmg ) );
				
				SetHamParamFloat( 4, 0.0 );
			}
		}
	}
}
