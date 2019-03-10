// Plain Seed
// A dummy test item that does absolutely nothing.

// <internal>_GetName
// Returns the full name of this item
string PlainSeed_GetName( bool& in bDummy = false )
{
	return "Semilla Comun";
}

// <internal>_GetInfo
// Returns full information about this item
string PlainSeed_GetInfo( bool& in bDummy = false )
{
	return "Semilla corriente que no provee\nde ningun efecto especial.\n\nAfecta: Un jugador";
}

// <internal>_CanUse
// Establishes conditions, determines if it's possible to use this item
bool PlainSeed_CanUse( int& in iPlayerIndex )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null )
	{
		if ( pPlayer.IsAlive() )
			return true;
	}
	
	return false;
}

// <internal>_CanThrow
// Establishes conditions, determines if it's possible to throw this item
bool PlainSeed_CanThrow( int& in iPlayerIndex )
{
	return false;
}

// <internal>_Use
// Item Use. Calling this directly allows to forcefully use this item, even if CanUse() returns false
void PlainSeed_Use( int& in iPlayerIndex )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null )
	{
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] " + pPlayer.pev.netname + " comio la Semilla Comun\n" );
		g_Scheduler.SetTimeout( "PS_Dummy", 1.0 );
	}
}

// <internal>_Throw
// Item Throw. NOT recommended to forcefully call this function
void PlainSeed_Throw( int& in iPlayerIndex )
{
	// This dummy item cannot be thrown and we do not want it to be throwable at all.
	// So leave this function empty.
}

// ----
void PS_Dummy()
{
	g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] No paso nada\n" );
}
