// Blast Seed:
// OH MY GOD JC, A BOMB!

string BlastSeed_GetName( bool& in bDummy = false )
{
	return "Semilla Bomba";
}

string BlastSeed_GetInfo( bool& in bDummy = false )
{
	return "Semilla explosiva que, una vez lanzada,\nlastima a cualquiera que choque con esta.\n\nAfecta: Cualquiera";
}

bool BlastSeed_CanUse( int& in iPlayerIndex )
{
	return false;
}

bool BlastSeed_CanThrow( int& in iPlayerIndex )
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

void BlastSeed_Use( int& in iPlayerIndex )
{
	// Empty
}

void BlastSeed_Throw( int& in iPlayerIndex )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null )
	{
		// Add sound here
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] " + pPlayer.pev.netname + " lanzo una Semilla Bomba!\n" );
		g_Scheduler.SetTimeout( "BS_ThrowInit", 0.3, iPlayerIndex );
	}
}

// ----
void BS_ThrowInit( int& in iPlayerIndex )
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
				g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] " + pPlayer.pev.netname + " agarro el objeto \"Semilla Bomba\"\n" );
				AddItem( iPlayerIndex, "BlastSeed", true );
			}
			else
			{
				// Create the entity
				CItemPickup@ pItem = CreateThrownItem( tr.vecEndPos, "BlastSeed", g_Engine.v_forward * 1024, 1.0, "BS_Touch" );
				@pItem.pev.owner = pPlayer.edict();
			}
		}
		else
		{
			// Add sound here
			g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] " + pPlayer.pev.netname + " agarro el objeto \"Semilla Bomba\"\n" );
			AddItem( iPlayerIndex, "BlastSeed", true );
		}
	}
	else
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] El objeto \"Semilla Bomba\" se perdio!\n" );
}

void BS_Touch( CBaseEntity@ pItem, CBaseEntity@ pOther )
{
	// Turn item invisible
	pItem.pev.effects = EF_NODRAW;
	
	// Sound goes here
	
	// Who?
	if ( pOther.IsPlayer() )
	{
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] El objeto \"Semilla Bomba\" salio disparado hacia " + pOther.pev.netname + "!\n" );
		g_Scheduler.SetTimeout( "BS_Hurt", 0.3, pOther.entindex(), string( pOther.pev.netname ), pItem.entindex() );
	}
	else
	{
		// BaseItem will not allow something else than players or monsters to call this, so assume it's a monster
		CBaseMonster@ pMonster = cast< CBaseMonster@ >( pOther );
		string szMonsterName = pMonster.m_FormattedName;
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] El objeto \"Semilla Bomba\" salio disparado hacia " + szMonsterName + "!\n" );
		g_Scheduler.SetTimeout( "BS_Hurt", 0.3, pOther.entindex(), szMonsterName, pItem.entindex() );
	}
}

void BS_Hurt( const int& in iEntityIndex, const string& in szTargetName, const int& in iItemIndex )
{
	CBaseEntity@ pEntity = g_EntityFuncs.Instance( iEntityIndex );
	CBaseEntity@ pItem = g_EntityFuncs.Instance( iItemIndex );
	if ( pEntity !is null )
	{
		// Whatever caught the item must not be in the process of dying or already dead
		if ( pEntity.IsAlive() )
		{
			// Get proper Z offset
			Vector vecOrigin = pEntity.pev.origin;
			vecOrigin.z += UTIL_GetZOffset( pEntity );
			
			// Explosion effect
			g_EntityFuncs.CreateExplosion( vecOrigin, g_vecZero, null, 100, false ); // This explosion should not hurt others
			
			// Hurt!
			CBaseEntity@ pOwner = g_EntityFuncs.Instance( pItem.pev.owner );
			if ( pOwner !is null )
				pEntity.TakeDamage( pItem.pev, pOwner.pev, 58.0, DMG_LAUNCH );
			else
				pEntity.TakeDamage( pItem.pev, pItem.pev, 58.0, DMG_LAUNCH );
			
			// Now remove the item entity
			g_EntityFuncs.Remove( pItem );
		}
		else
			g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] No paso nada\n" );
	}
	else
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] No paso nada\n" );
}
