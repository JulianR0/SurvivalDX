// Add items here
#include "oranberry"
#include "sitrusberry"
#include "reviverseed"

// Base vars
array< bool > ItemSelfMode;
array< string > ItemInternal;
array< string > ItemName;
array< string > ItemDescription;
array< string > ItemUseCallback;
array< string > ItemThrowCallback;
array< string > ItemCanUseCallback;
array< string > ItemCanThrowCallback;
int iItemCursor;

// Item handling
// Returns true if item exists and it's properly registered
bool ItemExists( const string& in szInternalName )
{
	int iItemID = -1;
	iItemID = ItemInternal.find( szInternalName );
	if ( iItemID >= 0 )
	{
		if ( ItemName[ iItemID ] == 'BAD ITEM' )
			return false;
		else
			return true;
	}
	
	return false;
}

// Attempts to add an item to a player's inventory
// Returns:
// 1 on success
// 0 if player's inventory is full
// -1 if item is invalid
// -2 if player does not exist
int AddItem( const int& in iPlayerIndex, const string& in szInternalName, bool& in bForce = false )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null && pPlayer.IsConnected() )
	{
		if ( ItemExists( szInternalName ) )
		{
			if ( GetInventoryCapacity( iPlayerIndex ) < pl_iMaxItems[ iPlayerIndex ] || bForce )
			{
				int iItemID = -1;
				iItemID = ItemInternal.find( szInternalName );
				pl_iItemData[ iPlayerIndex ][ iItemID ]++; // If item exists, then an aditional check is not needed
				return 1;
			}
			
			return 0;
		}
		
		return -1;
	}
	
	return -2;
}

// Attempts to remove an item to a player's inventory
// Returns:
// 1 on success
// -1 if item is invalid
// -2 if player does not exist
int RemoveItem( const int& in iPlayerIndex, const string& in szInternalName, uint& in uiAmount = 1 )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null && pPlayer.IsConnected() )
	{
		if ( ItemExists( szInternalName ) )
		{
			if ( uiAmount >= 1 )
			{
				int iItemID = -1;
				iItemID = ItemInternal.find( szInternalName );
				pl_iItemData[ iPlayerIndex ][ iItemID ] -= uiAmount;
				
				if ( pl_iItemData[ iPlayerIndex ][ iItemID ] < 0 )
					pl_iItemData[ iPlayerIndex ][ iItemID ] = 0;
				
				return 1;
			}
			
			//return 0; // AS Engine will throw an error if uiAmount is invalid
		}
		
		return -1;
	}
	
	return -2;
}

// Returns true if player has ANY number of the specified item
bool HasItem( const int& in iPlayerIndex, const string& in szInternalName )
{
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null && pPlayer.IsConnected() )
	{
		if ( ItemExists( szInternalName ) )
		{
			int iItemID = -1;
			iItemID = ItemInternal.find( szInternalName );
			
			if ( pl_iItemData[ iPlayerIndex ][ iItemID ] >= 1 )
				return true;
			
			return false;
		}
		
		return false;
	}
	
	return false;
}

// Returns total amount of items a player has
int GetInventoryCapacity( const int& in iPlayerIndex )
{
	int iTotalItems = 0;
	
	CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayerIndex );
	if ( pPlayer !is null && pPlayer.IsConnected() )
	{
		for ( uint ItemID = 0; ItemID < MAX_ITEMS; ItemID++ )
		{
			int iAmount = 0;
			if ( pl_iItemData[ iPlayerIndex ][ ItemID ] >= 1 )
			{
				while ( iAmount < pl_iItemData[ iPlayerIndex ][ ItemID ] )
				{
					iAmount++;
					iTotalItems++;
				}
			}
		}
	}
	
	return iTotalItems;
}

// Registers an item. If bSelfOnly is true, no "Player Select" menu will appear upon item usage
void RegisterItem( const string& in szInternalName, bool& in bSelfOnly = false )
{
	iItemCursor++;
	int iNewArraySize = iItemCursor + 1;
	
	ItemSelfMode.resize( iNewArraySize );
	ItemInternal.resize( iNewArraySize );
	ItemName.resize( iNewArraySize );
	ItemDescription.resize( iNewArraySize );
	ItemUseCallback.resize( iNewArraySize );
	ItemThrowCallback.resize( iNewArraySize );
	ItemCanUseCallback.resize( iNewArraySize );
	ItemCanThrowCallback.resize( iNewArraySize );
	
	string szNameCallback = szInternalName + "_GetName";
	string szDescriptionCallback = szInternalName + "_GetInfo";
	string szUseCallback = szInternalName + "_Use";
	string szThrowCallback = szInternalName + "_Throw";
	string szCanUseCallback = szInternalName + "_CanUse";
	string szCanThrowCallback = szInternalName + "_CanThrow";
	
	// Get the items data
	Reflection::Function@ fNameFunction = Reflection::g_Reflection.Module.FindGlobalFunction( szNameCallback );
	if ( fNameFunction !is null )
	{
		// Name
		any@ aName = fNameFunction.Call( false ).ToAny();
		string szName;
		aName.retrieve( szName );
		ItemName[ iItemCursor ] = szName;
		
		// Information
		Reflection::Function@ fInfoFunction = Reflection::g_Reflection.Module.FindGlobalFunction( szDescriptionCallback );
		any@ aInfo = fInfoFunction.Call( false ).ToAny();
		string szInfo;
		aInfo.retrieve( szInfo );
		ItemDescription[ iItemCursor ] = szInfo;
		
		// "Can" checks callbacks
		ItemCanUseCallback[ iItemCursor ] = szCanUseCallback;
		ItemCanThrowCallback[ iItemCursor ] = szCanThrowCallback;
		
		// Use/Throw callbacks
		ItemUseCallback[ iItemCursor ] = szUseCallback;
		ItemThrowCallback[ iItemCursor ] = szThrowCallback;
	}
	else
	{
		// Bad item!
		ItemName[ iItemCursor ] = "BAD ITEM";
		ItemDescription[ iItemCursor ] = "Objeto invalido. Reporta este error a un Admin\ninformandoles del siguiente mensaje:\n\nERR_BAD_INTERNAL (" + szInternalName + ")";
		
		ItemCanUseCallback[ iItemCursor ] = "NULLItem_DummyBool";
		ItemCanThrowCallback[ iItemCursor ] = "NULLItem_DummyBool";
		
		ItemUseCallback[ iItemCursor ] = "NULLItem_DummyVoid";
		ItemThrowCallback[ iItemCursor ] = "NULLItem_DummyVoid";
		
		g_Game.AlertMessage( at_logged, "[SDX] ERROR: RegisterItem() cannot locate functions for internal \"" + szInternalName + "\"!\n" );
	}
	
	ItemInternal[ iItemCursor ] = szInternalName;
	ItemSelfMode[ iItemCursor ] = bSelfOnly;
}

// BASE ITEM
// All items go through here and call their respective callbacks
// Allows easy add/removal of items by simple adding/deleting the include file and RegisterItem() directives
void BaseItem_Init()
{
	iItemCursor = -1;
	ItemSelfMode.resize( 0 );
	ItemInternal.resize( 0 );
	ItemName.resize( 0 );
	ItemDescription.resize( 0 );
	ItemUseCallback.resize( 0 );
	ItemThrowCallback.resize( 0 );
	ItemCanUseCallback.resize( 0 );
	ItemCanThrowCallback.resize( 0 );
	g_CustomEntityFuncs.RegisterCustomEntity( "CItemPickup", "item_sdxobject" );
	g_Game.PrecacheOther( "item_sdxobject" );
}

bool BaseItem_CanUse( const int& in iPlayerIndex, const string& in szInternalName )
{
	bool bReturn = false;
	int iItemID = -1;
	iItemID = ItemInternal.find( szInternalName );
	if ( iItemID >= 0 )
	{
		// A little ridiculous, don't you think?
		Reflection::Function@ fCanUse = Reflection::g_Reflection.Module.FindGlobalFunction( ItemCanUseCallback[ iItemID ] );
		any@ aInfo = fCanUse.Call( iPlayerIndex ).ToAny();
		aInfo.retrieve( bReturn );
		return bReturn;
	}
	
	return false;
}

bool BaseItem_CanThrow( const int& in iPlayerIndex, const string& in szInternalName )
{
	bool bReturn = false;
	int iItemID = -1;
	iItemID = ItemInternal.find( szInternalName );
	if ( iItemID >= 0 )
	{
		Reflection::Function@ fCanThrow = Reflection::g_Reflection.Module.FindGlobalFunction( ItemCanThrowCallback[ iItemID ] );
		any@ aInfo = fCanThrow.Call( iPlayerIndex ).ToAny();
		aInfo.retrieve( bReturn );
		return bReturn;
	}
	
	return false;
}

void BaseItem_Use( const int& in iPlayerIndex, const string& in szInternalName )
{
	int iItemID = -1;
	iItemID = ItemInternal.find( szInternalName );
	if ( iItemID >= 0 )
	{
		Reflection::Function@ fUse = Reflection::g_Reflection.Module.FindGlobalFunction( ItemUseCallback[ iItemID ] );
		fUse.Call( iPlayerIndex );
	}
}

void BaseItem_Throw( const int& in iPlayerIndex, const string& in szInternalName )
{
	int iItemID = -1;
	iItemID = ItemInternal.find( szInternalName );
	if ( iItemID >= 0 )
	{
		Reflection::Function@ fThrow = Reflection::g_Reflection.Module.FindGlobalFunction( ItemThrowCallback[ iItemID ] );
		fThrow.Call( iPlayerIndex );
	}
}

// NULL ITEM
// If an item registration goes wrong, prevent the item to be usable at all
// !!! Forcing the usage/throw of a null item WILL result in data loss !!!
bool NULLItem_DummyBool( bool& in bDummy = false ) { return false; }
void NULLItem_DummyVoid( int& in iPlayerIndex ) { }

// Item entity
class CItemPickup : ScriptBaseEntity
{
	string szInternalItem;
	int iItemID;
	
	float flFlyTime;
	string szTouchCallback;
	
	int iGibModel;
	
	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		if ( szKey == "item" )
		{
			szInternalItem = szValue;
			return true;
		}
		else if ( szKey == "flytime" )
		{
			flFlyTime = g_Engine.time + atof( szValue );
			return true;
		}
		else if ( szKey == "touchcallback" )
		{
			szTouchCallback = szValue;
			return true;
		}
		else
			return BaseClass.KeyValue( szKey, szValue );
	}
	
	void Spawn()
	{
		Precache();
		
		if ( ItemExists( szInternalItem ) && szInternalItem.Length() > 0 )
			iItemID = ItemInternal.find( szInternalItem );
		else
		{
			// NOPE
			g_Game.AlertMessage( at_logged, "[SDX] WARNING: Attempted to spawn invalid item \"" + szInternalItem + "\"!\n" );
			g_EntityFuncs.Remove( self );
			return;
		}
		
		g_EntityFuncs.SetModel( self, "models/error.mdl" ); // :U
		g_EntityFuncs.SetOrigin( self, self.pev.origin );
		
		g_EntityFuncs.SetSize( self.pev, Vector( -16, -16, 0 ), Vector( 16, 16, 16 ) );
	}
	
	void Precache()
	{
		g_EntityFuncs.PrecacheMaterialSounds( matWood );
		iGibModel = g_Game.PrecacheModel( "models/woodgibs.mdl" );
	}
	
	// Types of item. Standard item pickup or this is a thrown item
	void InitNormal()
	{
		self.pev.gravity = 1.0;
		self.pev.movetype = MOVETYPE_TOSS;
		self.pev.solid = SOLID_BBOX;
		
		SetTouch( TouchFunction( PlayerTouchItem ) );
	}
	
	void InitThrown()
	{
		self.pev.movetype = MOVETYPE_FLYMISSILE;
		self.pev.solid = SOLID_BBOX;
		
		SetThink( ThinkFunction( ThrowThink ) );
		SetTouch( TouchFunction( ThrowTouch ) );
		self.pev.nextthink = g_Engine.time + 0.1;
	}
	
	// Standard Item: Touch
	void PlayerTouchItem( CBaseEntity@ pOther )
	{
		// Players only, and must be alive
		if ( pOther.IsPlayer() && pOther.IsAlive() )
		{
			// Attempt to add the item to the player's inventory
			if ( AddItem( pOther.entindex(), szInternalItem ) != 0 )
			{
				// Add sound here
				g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] " + pOther.pev.netname + " agarro el objeto \"" + ItemName[ iItemID ] + "\"\n" );
				
				// Remove this item from the world
				g_EntityFuncs.Remove( self );
			}
			else
			{
				// Let player know both inventory full, and what is this item
				g_PlayerFuncs.ClientPrint( cast< CBasePlayer@ >( pOther ), HUD_PRINTCENTER, "" + ItemName[ iItemID ] + "\n\nEl inventario esta lleno\n" );
			}
		}
	}
	
	// Thrown item: Think
	void ThrowThink()
	{
		// Analyze current fly time. It is time to start falling?
		if ( g_Engine.time > flFlyTime )
		{
			// Start falling, let gravity do it's job
			self.pev.gravity = 0.9;
			self.pev.friction = 0.8;
			self.pev.movetype = MOVETYPE_BOUNCE;
			
			SetThink( ThinkFunction( ThrowFallThink ) );
		}
		
		self.pev.nextthink = g_Engine.time + 0.1;
	}
	
	// Thrown item: Falling Think
	void ThrowFallThink()
	{
		// Wait for the item to fall to the ground and stop moving entirely
		if ( self.pev.velocity.Length() <= 2 && self.pev.FlagBitSet( FL_ONGROUND ) )
		{
			// Force stop
			self.pev.velocity = g_vecZero;
			
			// Okay, check water
			if ( self.pev.waterlevel == WATERLEVEL_HEAD )
			{
				// Submerged in water. What kind of water this is?
				CONTENTS cLocation = g_EngineFuncs.PointContents( self.pev.origin );
				if ( cLocation == CONTENTS_LAVA || cLocation == CONTENTS_SLIME )
				{
					// RIP
					g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] El objeto \"" + ItemName[ iItemID ] + "\" se perdio!\n" );
					
					// Remove this item from the world
					g_EntityFuncs.Remove( self );
				}
				else
				{
					g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] El objeto \"" + ItemName[ iItemID ] + "\" se sumergio en el agua\n" );
					InitNormal();
					SetThink( null );
				}
			}
			else if ( self.pev.waterlevel != WATERLEVEL_DRY )
			{
				// Not submerged but still in water. Get water type again
				CONTENTS cLocation = g_EngineFuncs.PointContents( self.pev.origin );
				if ( cLocation == CONTENTS_LAVA )
				{
					// Lava instantly destroys the item
					g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] El objeto \"" + ItemName[ iItemID ] + "\" se perdio!\n" );
					
					// Break effect
					NetworkMessage nmBreak( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, self.pev.origin );
					nmBreak.WriteByte( TE_BREAKMODEL );
					nmBreak.WriteCoord( self.pev.origin.x );
					nmBreak.WriteCoord( self.pev.origin.y );
					nmBreak.WriteCoord( self.pev.origin.z );
					nmBreak.WriteCoord( 16 ); // size x
					nmBreak.WriteCoord( 16 ); // size y
					nmBreak.WriteCoord( 16 ); // size z
					nmBreak.WriteCoord( Math.RandomLong( -50, 50 ) ); // velocity x
					nmBreak.WriteCoord( Math.RandomLong( -50, 50 ) ); // velocity y
					nmBreak.WriteCoord( 25 ); // velocity z
					nmBreak.WriteByte( 10 ); // random velocity
					nmBreak.WriteShort( iGibModel );
					nmBreak.WriteByte( 10 ); // gib count
					nmBreak.WriteByte( 25 ); // gib life
					nmBreak.WriteByte( 0x08 ); // flags ( BREAK_WOOD )
					nmBreak.End();
					
					// Remove this item from the world
					g_EntityFuncs.Remove( self );
				}
				else if ( cLocation == CONTENTS_SLIME )
				{
					// Slime acid slowly destroys the item
					g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] El objeto \"" + ItemName[ iItemID ] + "\" cayo al acido!\n" );
					
					// Player has some short time to grab the item before the acid completely destroys the item
					self.pev.movetype = MOVETYPE_NONE;
					flFlyTime = g_Engine.time + 10.0;
					
					SetThink( ThinkFunction( ThrowAcid ) );
					SetTouch( TouchFunction( PlayerTouchItem ) );
				}
				else
				{
					// Standard water
					g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] El objeto \"" + ItemName[ iItemID ] + "\" cayo al agua\n" );
					InitNormal();
					SetThink( null );
				}
			}
			else
			{
				// Totally NOT on water
				g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] El objeto \"" + ItemName[ iItemID ] + "\" cayo al suelo\n" );
				InitNormal();
				SetThink( null );
			}
		}
		else
		{
			if ( self.pev.FlagBitSet( FL_ONGROUND ) )
			{
				// Slow down a little
				self.pev.velocity = self.pev.velocity * 0.7;
			}
		}
		
		self.pev.nextthink = g_Engine.time + 0.1;
	}
	
	// Thrown item: "Fall to acid" think
	void ThrowAcid()
	{
		// Time to go "bye-bye"?
		if ( g_Engine.time > flFlyTime )
		{
			// Game over!
			g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] El objeto \"" + ItemName[ iItemID ] + "\" se perdio!\n" );
			
			// Break effect
			NetworkMessage nmBreak( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, self.pev.origin );
			nmBreak.WriteByte( TE_BREAKMODEL );
			nmBreak.WriteCoord( self.pev.origin.x );
			nmBreak.WriteCoord( self.pev.origin.y );
			nmBreak.WriteCoord( self.pev.origin.z );
			nmBreak.WriteCoord( 16 ); // size x
			nmBreak.WriteCoord( 16 ); // size y
			nmBreak.WriteCoord( 16 ); // size z
			nmBreak.WriteCoord( Math.RandomLong( -50, 50 ) ); // velocity x
			nmBreak.WriteCoord( Math.RandomLong( -50, 50 ) ); // velocity y
			nmBreak.WriteCoord( 25 ); // velocity z
			nmBreak.WriteByte( 10 ); // random velocity
			nmBreak.WriteShort( iGibModel );
			nmBreak.WriteByte( 10 ); // gib count
			nmBreak.WriteByte( 25 ); // gib life
			nmBreak.WriteByte( 0x08 ); // flags ( BREAK_WOOD )
			nmBreak.End();
			
			// Remove this item from the world
			g_EntityFuncs.Remove( self );
		}
		else
		{
			// Hurt sounds
			switch ( Math.RandomLong( 1, 3 ) )
			{
				case 1: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "debris/wood1.wav", Math.RandomFloat( 0.75, 1.00 ), ATTN_NORM, 0, 95 + Math.RandomLong( 0, 34 ) ); break;
				case 2: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "debris/wood2.wav", Math.RandomFloat( 0.75, 1.00 ), ATTN_NORM, 0, 95 + Math.RandomLong( 0, 34 ) ); break;
				case 3: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "debris/wood3.wav", Math.RandomFloat( 0.75, 1.00 ), ATTN_NORM, 0, 95 + Math.RandomLong( 0, 34 ) ); break;
			}
			
			self.pev.nextthink = g_Engine.time + 0.5;
		}
	}
	
	// Thrown item: Touch
	void ThrowTouch( CBaseEntity@ pOther )
	{
		// Touching someone?
		if ( pOther.IsMonster() || pOther.IsPlayer() )
		{
			// Call the function, pass the toucher as argument
			Reflection::Function@ fTouch = Reflection::g_Reflection.Module.FindGlobalFunction( szTouchCallback );
			if ( fTouch !is null )
			{
				// Transform the item into a dummy one
				// Item itself must handle themselves how to behave from this point
				SetThink( null );
				SetTouch( null );
				
				fTouch.Call( @self, @pOther );
			}
			else
			{
				// Invalid callback. ABORT!
				g_PlayerFuncs.ClientPrintAll( HUD_PRINTTALK, "[SDX] El objeto \"" + ItemName[ iItemID ] + "\" se perdio!\n" );
				g_Game.AlertMessage( at_logged, "[SDX] ERROR: Spawned thrown item \"" + szInternalItem + "\" with invalid callback!\n" );
				g_EntityFuncs.Remove( self );
			}
		}
		else
		{
			// Touched a wall, start falling to the ground
			flFlyTime = 0.0;
		}
	}
}

CItemPickup@ CreateThrownItem( Vector& in vecOrigin, string& in szItemName, Vector& in vecVelocity, float& in flFlyTime, string& in szTouchCallback )
{
	CBaseEntity@ pre_pItem = g_EntityFuncs.CreateEntity( "item_sdxobject", null, false );
	CItemPickup@ pItem = cast< CItemPickup@ >( CastToScriptClass( pre_pItem ) );
	
	pItem.pev.origin = vecOrigin; // Spawn() will call SetOrigin()
	g_EntityFuncs.DispatchKeyValue( pItem.self.edict(), "item", szItemName );
	g_EntityFuncs.DispatchKeyValue( pItem.self.edict(), "flytime", string( flFlyTime ) );
	g_EntityFuncs.DispatchKeyValue( pItem.self.edict(), "touchcallback", szTouchCallback );
	pItem.Spawn();
	
	pItem.InitThrown();
	pItem.pev.velocity = vecVelocity;
	
	return pItem;
}

CItemPickup@ CreateItem( Vector& in vecOrigin, string& in szItemName )
{
	CBaseEntity@ pre_pItem = g_EntityFuncs.CreateEntity( "item_sdxobject", null, false );
	CItemPickup@ pItem = cast< CItemPickup@ >( CastToScriptClass( pre_pItem ) );
	
	pItem.pev.origin = vecOrigin;
	g_EntityFuncs.DispatchKeyValue( pItem.self.edict(), "item", szItemName );
	pItem.Spawn();
	
	pItem.InitNormal();
	
	return pItem;
}

// Utility stock for effects
float UTIL_GetZOffset( CBaseEntity@ pEntity )
{
	string szClassname = pEntity.pev.classname;
	float flOffset;
	
	if ( szClassname == "monster_alien_babyvoltigore" )
		flOffset = 18.0;
	else if ( szClassname == "monster_alien_controller" )
		flOffset = 40.0;
	else if ( szClassname == "monster_alien_grunt" )
		flOffset = 48.0;
	else if ( szClassname == "monster_alien_slave" )
		flOffset = 36.0;
	else if ( szClassname == "monster_alien_tor" )
		flOffset = 48.0;
	else if ( szClassname == "monster_alien_voltigore" )
		flOffset = 50.0;
	else if ( szClassname == "monster_apache" )
		flOffset = 32.0;
	else if ( szClassname == "monster_babycrab" )
		flOffset = 4.0;
	else if ( szClassname == "monster_babygarg" )
		flOffset = 54.0;
	else if ( szClassname == "monster_barney" )
		flOffset = 42.0;
	else if ( szClassname == "monster_bigmomma" )
		flOffset = 94.0;
	else if ( szClassname == "monster_blkop_apache" )
		flOffset = 32.0;
	else if ( szClassname == "monster_blkop_osprey" )
		flOffset = 45.0;
	else if ( szClassname == "monster_bodyguard" )
		flOffset = 42.0;
	else if ( szClassname == "monster_bullchicken" )
		flOffset = 20.0;
	else if ( szClassname == "monster_cleansuit_scientist" )
		flOffset = 40.0;
	else if ( szClassname == "monster_gargantua" )
		flOffset = 110.0;
	else if ( szClassname == "monster_gonome" )
		flOffset = 44.0;
	else if ( szClassname == "monster_headcrab" )
		flOffset = 8.0;
	else if ( szClassname == "monster_houndeye" )
		flOffset = 24.0;
	else if ( szClassname == "monster_human_assassin" )
		flOffset = 40.0;
	else if ( szClassname == "monster_human_grunt" )
		flOffset = 40.0;
	else if ( szClassname == "monster_human_grunt_ally" )
		flOffset = 40.0;
	else if ( szClassname == "monster_human_torch_ally" )
		flOffset = 42.0;
	else if ( szClassname == "monster_hwgrunt" )
		flOffset = 38.0;
	else if ( szClassname == "monster_kingpin" )
		flOffset = 62.0;
	else if ( szClassname == "monster_male_assassin" )
		flOffset = 42.0;
	else if ( szClassname == "monster_miniturret" )
		flOffset = 8.0;
	else if ( szClassname == "monster_osprey" )
		flOffset = 45.0;
	else if ( szClassname == "monster_otis" )
		flOffset = 40.0;
	else if ( szClassname == "monster_pitdrone" )
		flOffset = 30.0;
	else if ( szClassname == "monster_robogrunt" )
		flOffset = 40.0;
	else if ( szClassname == "monster_scientist" )
		flOffset = 38.0;
	else if ( szClassname == "monster_sentry" )
		flOffset = 28.0;
	else if ( szClassname == "monster_shocktrooper" )
		flOffset = 52.0;
	else if ( szClassname == "monster_stukabat" )
		flOffset = 22.0;
	else if ( szClassname == "monster_turret" )
		flOffset = 12.0;
	else if ( szClassname == "monster_zombie" )
		flOffset = 40.0;
	else if ( szClassname == "monster_zombie_barney" )
		flOffset = 40.0;
	else if ( szClassname == "monster_zombie_soldier" )
		flOffset = 40.0;
	else // No valid monster found, assume it's a player
		flOffset = 8.0;
	
	// Adjust scale
	flOffset *= pEntity.pev.scale;
	
	return flOffset;
}
