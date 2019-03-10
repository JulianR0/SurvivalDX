// Sitrus Berry:
// Upgraded version of the Oran Berry

string SitrusBerry_GetName( bool& in bDummy = false )
{
	return "Baya Zidra";
}

string SitrusBerry_GetInfo( bool& in bDummy = false )
{
	string szInfo = "Alimento de otro mundo.\nRestaura la vida del objetivo.\n\n";
	szInfo += "Si se consume con la vida al maximo,\nla vida maxima del usuario aumenta.\n\n";
	szInfo += "Su efecto dura hasta el cambio de mapa.\n\nAfecta: Cualquiera";
	
	return szInfo;
}

bool SitrusBerry_CanUse( int& in iPlayerIndex )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null )
	{
		if ( pPlayer.IsAlive() )
			return true;
	}
	
	return false;
}

bool SitrusBerry_CanThrow( int& in iPlayerIndex )
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

void SitrusBerry_Use( int& in iPlayerIndex )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null )
	{
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] " + pPlayer.pev.netname + " comio la Baya Zidra\n" );
		g_Scheduler.SetTimeout( "SB_InitSound", 1.0, iPlayerIndex );
	}
}

void SitrusBerry_Throw( int& in iPlayerIndex )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null )
	{
		// Add sound here
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] " + pPlayer.pev.netname + " lanzo una Baya Zidra!\n" );
		g_Scheduler.SetTimeout( "SB_ThrowInit", 0.3, iPlayerIndex );
	}
}

// ----
void SB_InitSound( int& in iPlayerIndex )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null )
	{
		// Add sound here
		g_Scheduler.SetTimeout( "SB_HealUse", 0.3, iPlayerIndex );
	}
	else
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] No paso nada\n" );
}

void SB_HealUse( int& in iPlayerIndex )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null )
	{
		// Add sound here
		if ( pPlayer.pev.health >= pPlayer.pev.max_health )
		{
			// Sound override here
			pPlayer.pev.max_health = pPlayer.pev.max_health + 20.0;
			g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] La vida maxima de " + pPlayer.pev.netname + " aumento en 20 HP!\n" );
		}
		else
			g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] " + pPlayer.pev.netname + " ha recuperado toda su vida\n" );
		
		pPlayer.TakeHealth( 9999.0, DMG_GENERIC );
	}
	else
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] No paso nada\n" );
}

void SB_ThrowInit( int& in iPlayerIndex )
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
				g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] " + pPlayer.pev.netname + " agarro el objeto \"Baya Zidra\"\n" );
				AddItem( iPlayerIndex, "SitrusBerry", true );
			}
			else
			{
				// Create the entity
				CreateThrownItem( tr.vecEndPos, "SitrusBerry", g_Engine.v_forward * 1024, 1.0, "SB_Touch" );
			}
		}
		else
		{
			// Add sound here
			g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] " + pPlayer.pev.netname + " agarro el objeto \"Baya Zidra\"\n" );
			AddItem( iPlayerIndex, "SitrusBerry", true );
		}
	}
	else
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] El objeto \"Baya Zidra\" se perdio!\n" );
}

void SB_Touch( CBaseEntity@ pItem, CBaseEntity@ pOther )
{
	// Don't care who touches this. Remove the item and init healing process
	g_EntityFuncs.Remove( pItem );
	
	// Sound goes here
	
	// Okay, care JUST A LITTLE. Who?
	if ( pOther.IsPlayer() )
	{
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] El objeto \"Baya Zidra\" salio disparado hacia " + pOther.pev.netname + "!\n" );
		g_Scheduler.SetTimeout( "SB_HealThrow", 0.3, pOther.entindex(), string( pOther.pev.netname ) );
	}
	else
	{
		// BaseItem will not allow something else than players or monsters to call this, so assume it's a monster
		CBaseMonster@ pMonster = cast< CBaseMonster@ >( pOther );
		string szMonsterName = pMonster.m_FormattedName;
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] El objeto \"Baya Zidra\" salio disparado hacia " + szMonsterName + "!\n" );
		g_Scheduler.SetTimeout( "SB_HealThrow", 0.3, pOther.entindex(), szMonsterName );
	}
}

void SB_HealThrow( const int& in iEntityIndex, const string& in szTargetName )
{
	CBaseEntity@ pEntity = g_EntityFuncs.Instance( iEntityIndex );
	if ( pEntity !is null )
	{
		// Whatever caught the item must not be in the process of dying or already dead
		if ( pEntity.IsAlive() )
		{
			// Add sound here
			if ( pEntity.pev.health >= pEntity.pev.max_health )
			{
				// Sound override here
				pEntity.pev.max_health = pEntity.pev.max_health + 20.0;
				g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] La vida maxima de " + szTargetName + " aumento en 20 HP!\n" );
			}
			else
				g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] " + szTargetName + " ha recuperado toda su vida\n" );
			
			pEntity.TakeHealth( 9999.0, DMG_GENERIC );
		}
		else
			g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] No paso nada\n" );
	}
	else
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] No paso nada\n" );
}
