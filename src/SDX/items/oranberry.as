// Oran Berry:
// Medicinal food that restores 100 HP to an entity

string OranBerry_GetName( bool& in bDummy = false )
{
	return "Baya Aranja";
}

string OranBerry_GetInfo( bool& in bDummy = false )
{
	return "Alimento de otro mundo.\nRestaura la vida del objetivo.\n\nAfecta: Cualquiera";
}

bool OranBerry_CanUse( int& in iPlayerIndex )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null )
	{
		if ( pPlayer.IsAlive() )
			return true;
	}
	
	return false;
}

bool OranBerry_CanThrow( int& in iPlayerIndex )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null )
	{
		if ( pPlayer.IsAlive() )
		{
			// Trace forward and see if our path ain't blocked
			TraceResult tr;
			g_EngineFuncs.MakeVectors( pPlayer.pev.v_angle );
			g_Utility.TraceHull( pPlayer.pev.origin + pPlayer.pev.view_ofs, pPlayer.pev.origin + g_Engine.v_forward * 64, dont_ignore_monsters, head_hull, pPlayer.edict(), tr );
			if ( tr.flFraction == 1.0 && FNullEnt( tr.pHit ) )
			{
				// Not hitting anything, item will be stuck if spawned here?
				if ( tr.fAllSolid == 1 || tr.fStartSolid == 1 || tr.fInOpen == 0 )
				{
					// Stuck!
					return false;
				}
				else
				{
					// All clear!
					return true;
				}
			}
		}
	}
	
	return false;
}

void OranBerry_Use( int& in iPlayerIndex )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null )
	{
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] " + pPlayer.pev.netname + " comio la Baya Aranja\n" );
		g_Scheduler.SetTimeout( "OB_InitSound", 1.0, iPlayerIndex );
	}
}

void OranBerry_Throw( int& in iPlayerIndex )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null )
	{
		// Add sound here
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] " + pPlayer.pev.netname + " lanzo una Baya Aranja!\n" );
		g_Scheduler.SetTimeout( "OB_ThrowInit", 0.3, iPlayerIndex );
	}
}

// ----
void OB_InitSound( int& in iPlayerIndex )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null )
	{
		// Add sound here
		g_Scheduler.SetTimeout( "OB_HealUse", 0.3, iPlayerIndex );
	}
	else
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] No paso nada\n" );
}

void OB_HealUse( int& in iPlayerIndex )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null )
	{
		// Add sound here
		if ( pPlayer.pev.health >= pPlayer.pev.max_health )
			g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] La vida de " + pPlayer.pev.netname + " no ha cambiado\n" );
		else if ( ( pPlayer.pev.health + 100.0 ) > pPlayer.pev.max_health )
			g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] " + pPlayer.pev.netname + " ha recuperado toda su vida\n" );
		else
			g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] " + pPlayer.pev.netname + " recupero 100 HP\n" );
		
		pPlayer.TakeHealth( 100.0, DMG_GENERIC );
	}
	else
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] No paso nada\n" );
}

void OB_ThrowInit( int& in iPlayerIndex )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null )
	{
		// Attempt to create the entity
		TraceResult tr;
		g_EngineFuncs.MakeVectors( pPlayer.pev.v_angle );
		g_Utility.TraceHull( pPlayer.pev.origin + pPlayer.pev.view_ofs, pPlayer.pev.origin + g_Engine.v_forward * 64, dont_ignore_monsters, head_hull, pPlayer.edict(), tr );
		if ( tr.flFraction == 1.0 && FNullEnt( tr.pHit ) )
		{
			// Not hitting anything, item will be stuck if spawned here?
			if ( tr.fAllSolid == 1 || tr.fStartSolid == 1 || tr.fInOpen == 0 )
			{
				// Add sound here
				g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] " + pPlayer.pev.netname + " agarro el objeto \"Baya Aranja\"\n" );
				AddItem( iPlayerIndex, "OranBerry", true );
			}
			else
			{
				// Create the entity
				CreateThrownItem( tr.vecEndPos, "OranBerry", g_Engine.v_forward * 1024, 1.0, "OB_Touch" );
			}
		}
		else
		{
			// Add sound here
			g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] " + pPlayer.pev.netname + " agarro el objeto \"Baya Aranja\"\n" );
			AddItem( iPlayerIndex, "OranBerry", true );
		}
	}
	else
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] El objeto \"Baya Aranja\" se perdio!\n" );
}

void OB_Touch( CBaseEntity@ pItem, CBaseEntity@ pOther )
{
	// Don't care who touches this. Remove the item and init healing process
	g_EntityFuncs.Remove( pItem );
	
	// Sound goes here
	
	// Okay, care JUST A LITTLE. Who?
	if ( pOther.IsPlayer() )
	{
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] El objeto \"Baya Aranja\" salio disparado hacia " + pOther.pev.netname + "!\n" );
		g_Scheduler.SetTimeout( "OB_HealThrow", 0.3, pOther.entindex(), string( pOther.pev.netname ) );
	}
	else
	{
		// BaseItem will not allow something else than players or monsters to call this, so assume it's a monster
		CBaseMonster@ pMonster = cast< CBaseMonster@ >( pOther );
		string szMonsterName = pMonster.m_FormattedName;
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] El objeto \"Baya Aranja\" salio disparado hacia " + szMonsterName + "!\n" );
		g_Scheduler.SetTimeout( "OB_HealThrow", 0.3, pOther.entindex(), szMonsterName );
	}
}

void OB_HealThrow( const int& in iEntityIndex, const string& in szTargetName )
{
	CBaseEntity@ pEntity = g_EntityFuncs.Instance( iEntityIndex );
	if ( pEntity !is null )
	{
		// Whatever caught the item must not be in the process of dying or already dead
		if ( pEntity.IsAlive() )
		{
			if ( pEntity.pev.health >= pEntity.pev.max_health )
				g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] La vida de " + szTargetName + " no ha cambiado\n" );
			else if ( ( pEntity.pev.health + 100.0 ) > pEntity.pev.max_health )
				g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] " + szTargetName + " ha recuperado toda su vida\n" );
			else
				g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] " + szTargetName + " recupero 100 HP\n" );
			
			pEntity.TakeHealth( 100.0, DMG_GENERIC );
		}
		else
			g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] No paso nada\n" );
	}
	else
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] No paso nada\n" );
}
