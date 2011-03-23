/**
 * File: War3Source_ShopItems.sp
 * Description: The shop items that come with War3Source.
 * Author(s): Anthony Iacono
 */
 
#pragma semicolon 1

#include <sourcemod>
#include "W3SIncs/War3Source_Interface"
#include <sdktools>

#undef REQUIRE_EXTENSIONS
#include <cstrike>
///not needed #define REQUIRE_EXTENSIONS

enum ITEMENUM{ ///
	POSTHASTE=0,
	TRINKET,
	LIFETUBE,
	/*
	//basic "Accessories"
	striders
	Fortified Bracelet
	soulscream ring , Alchemist's Bones, charged hammer
	Trinket of Restoration
	sustainer
	
	//support
	ring of the teacher
	Refreshing Ornament
	Shield of the Five
	helm
	headdress
	
	//protective
	Iron Shield
	daemonic breastplate
	frostfield plate	
	behe's heart
	snake bracelet
	barbed armor
	//combata
	spell shards??? needs some recoding
	thunderclaw
	modk of brilliance
	warclept - attack speed
	//morph 
	shiel dbreakder
	frostburn
	some leech 
	
	
	
	
	
	
	*/
}
new ItemID[ITEMENUM];

public Plugin:myinfo = 
{
	name = "War3Source - Shopitems2",
	author = "Ownz",
	description = "The shop items that come with War3Source.",
	version = "1.0.0.0",
	url = "http://war3source.com/"
};

public OnPluginStart()
{
	
	
}

public OnWar3LoadRaceOrItemOrdered(num)
{
	if(num==10){
		ItemID[POSTHASTE]=War3_CreateShopItem2("Post Haste","posthaste","+3% speed",0);
		ItemID[TRINKET]=War3_CreateShopItem2("Trinket of Restoraion","trinket","+0.5 HP regeneration",0);
		ItemID[LIFETUBE]=War3_CreateShopItem2("Lifetube","lifetube","+1 HP regeneration",0);
	}
}
public OnMapStart()
{
	
}

public OnItem2Purchase(client,item)
{
	if(item==ItemID[POSTHASTE] ) // boots of speed
	{
		War3_SetBuffItem2(client,fMaxSpeed2,ItemID[POSTHASTE],1.039);
	}
}

public OnItem2Lost(client,item){ //deactivate passives , client may have disconnected

	if(item==ItemID[POSTHASTE]){
		War3_SetBuffItem2(client,fMaxSpeed2,ItemID[POSTHASTE],1.0);
	}
	
}