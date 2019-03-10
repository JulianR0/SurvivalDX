// Reviver Seed
// Fully revives a dead player

string ReviverSeed_GetName( bool& in bDummy = false )
{
	return "Semilla Revivir";
}

string ReviverSeed_GetInfo( bool& in bDummy = false )
{
	string szInfo = "Semilla energetica que reanima\npor completo a un miembro caido.\n\n";
	szInfo += "Si el portador de este objeto\ncae en combate, la semilla\nes automaticamente usada.";
	szInfo += "\n\nAfecta: Un jugador";
	
	return szInfo;
}

bool ReviverSeed_CanUse( int& in iPlayerIndex )
{
	return true;
}

bool ReviverSeed_CanThrow( int& in iPlayerIndex )
{
	return false;
}

void ReviverSeed_Use( int& in iPlayerIndex )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null )
	{
		// Only show use message if player is alive
		if ( pPlayer.IsAlive() )
			g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] " + pPlayer.pev.netname + " comio la Semilla Revivir\n" );
		g_Scheduler.SetTimeout( "RS_Check", 1.0, iPlayerIndex );
	}
}

void ReviverSeed_Throw( int& in iPlayerIndex )
{
	// Empty
}

// ----
void RS_Check( int& in iPlayerIndex )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null )
	{
		// Reviver Seed only affects dead players
		if ( pPlayer.IsAlive() )
			g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] No paso nada\n" );
		else
		{
			// Dead. On observer mode?
			if ( pPlayer.GetObserver().IsObserver() )
			{
				// Observing, player has a corpse left behind?
				if ( pPlayer.GetObserver().HasCorpse() )
				{
					// We do, normal revive
					pPlayer.Revive();
				}
				else
				{
					// Nope, respawn the player
					pPlayer.Revive(); // So Spawn() ain't called
					g_PlayerFuncs.RespawnPlayer( pPlayer, true, true );
				}
			}
			else
			{
				// Player has been gibbed?
				if ( ( pPlayer.pev.effects & EF_NODRAW ) != 0 )
				{
					// Yes, respawn the player
					pPlayer.pev.takedamage = DAMAGE_NO; // In the event a player died in the middle of a trigger_hurt or just a bad place
					pPlayer.Revive();
					g_PlayerFuncs.RespawnPlayer( pPlayer, true, true );
				}
				else
				{
					// Nope, normal revive
					pPlayer.Revive();
				}
			}
			
			// Revive handling is done, fully heal the player now
			pPlayer.TakeHealth( 9999.0, DMG_GENERIC );
			pPlayer.TakeArmor( 9999.0, DMG_GENERIC );
			
			// Yield a bit of extra ammo
			for ( uint j = 0; j < MAX_WEAPONS; j++ )
			{
				// Uses ammo?
				int iMaxAmmo = pPlayer.GetMaxAmmo( j );
				if ( iMaxAmmo > 0 )
				{
					// Add 20% of max ammo, rounded down
					int iAmmo = pPlayer.m_rgAmmo( j );
					int iExtraAmmo = int( float( iMaxAmmo ) * 20.0 / 100.0 );
					pPlayer.m_rgAmmo( j, ( iAmmo + iExtraAmmo ) );
				}
			}
			
			// Make sure we don't go over the limit
			pPlayer.RemoveAllExcessAmmo();
			
			// Effects here
			
			// Arise!
			g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] Se reanimo a " + pPlayer.pev.netname + "!\n" );
			
			// Restore takedamage flag
			pPlayer.pev.takedamage = DAMAGE_AIM;
		}
	}
	else
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] No paso nada\n" );
}
