//Cooldown manager
//keeps track of all cooldowns

//Delay Tracker:
//setting an object's state to false for X seconds, manually retrieve the state




#include <sourcemod>
#include "W3SIncs/War3Source_Interface"




new bool:CooldownOnSpawn[MAXRACES][MAXSKILLCOUNT];
new bool:CooldownOnSpawnPrint[MAXRACES][MAXSKILLCOUNT];
new Float:CooldownOnSpawnDuration[MAXRACES][MAXSKILLCOUNT];
new String:CooldownOnSpawnSkillname[MAXRACES][MAXSKILLCOUNT][32];

new String:ultimateReadySound[]="war3source/ult_ready.wav";
new String:abilityReadySound[]="war3source/ability_refresh.mp3";

new Handle:g_CooldownExpiredForwardHandle;


new CooldownPointer[MAXPLAYERS][MAXRACES][MAXSKILLCOUNT];

enum CooldownClass
{
	Float:cexpiretime,
	cclient,
	crace,
	cskill,
	bool:cexpireonspawn,
	bool:cexpireondeath,
	bool:cprintmsgonexpire,
	String:cskillname[32],
	cnext,
}

#define MAXCOOLDOWNS 64*2
new Cooldown[MAXCOOLDOWNS][CooldownClass];








#define MAXTHREADS 2000
new Float:expireTime[MAXTHREADS];
new threadsLoaded;


public Plugin:myinfo= 
{
	name="War3Source Engine Cooldown Manager",
	author="Ownz",
	description="War3Source Core Plugins",
	version="1.0",
	url="http://war3source.com/"
};



public APLRes:AskPluginLoad2(Handle:myself,bool:late,String:error[],err_max)
{
	if(!InitNativesForwards())
	{
		LogError("[War3Source] There was a failure in creating the native / forwards based functions, definately halting.");
		return APLRes_Failure;
	}
	return APLRes_Success;
}

public OnPluginStart()
{
	CreateTimer(0.1,DeciSecondTimer,_,TIMER_REPEAT);

}
public OnMapStart(){
	for(new i=0;i<MAXTHREADS;i++){
		expireTime[i]=0.0;
	}
	War3_PrecacheSound(abilityReadySound);
	War3_PrecacheSound(ultimateReadySound);
	
	
	ClearAllCooldowns();
}

bool:InitNativesForwards()
{
	///LIST ALL THESE NATIVES IN INTERFACE
	CreateNative("War3_CooldownMGR",Native_War3_CooldownMGR);
	CreateNative("War3_CooldownRemaining",Native_War3_CooldownRMN);
	CreateNative("War3_CooldownReset",Native_War3_CooldownReset);
	CreateNative("War3_SkillNotInCooldown",Native_War3_SkillNIC);
	CreateNative("War3_PrintSkillIsNotReady",Native_War3_PrintSkillINR);
	
	
	CreateNative("War3_RegisterDelayTracker",NWar3_RegisterDelayTracker);
	CreateNative("War3_TrackDelay",NWar3_TrackDelay);
	CreateNative("War3_TrackDelayExpired",NWar3_TrackDelayExpired);
	
	CreateNative("W3SkillCooldownOnSpawn",NW3SkillCooldownOnSpawn);
	g_CooldownExpiredForwardHandle=CreateGlobalForward("OnCooldownExpired",ET_Ignore,Param_Cell,Param_Cell,Param_Cell,Param_Cell);
	
	return true;
}


public NWar3_RegisterDelayTracker(Handle:plugin,numParams)
{
	if(threadsLoaded<MAXTHREADS){
		return threadsLoaded++;
	}
	LogError("[War3Source Engine 1] DELAY TRACKER MAXTHREADS LIMIT REACHED! return -1");
	return -1;
}
public NWar3_TrackDelay(Handle:plugin,numParams)
{
	new index=GetNativeCell(1);
	new Float:delay=GetNativeCell(2);
	expireTime[index]=GetGameTime()+delay;
}
public NWar3_TrackDelayExpired(Handle:plugin,numParams)
{
	return GetGameTime()>expireTime[GetNativeCell(1)];
}
	
public NW3SkillCooldownOnSpawn(Handle:plugin,numParams)
{
	new raceid=GetNativeCell(1);
	new skillid=GetNativeCell(2);
	new Float:cooldowntime=GetNativeCell(3);
	new bool:print=GetNativeCell(4);
	CooldownOnSpawn[raceid][skillid]=true;
	CooldownOnSpawnPrint[raceid][skillid]=print;
	CooldownOnSpawnDuration[raceid][skillid]=cooldowntime;
	Format(CooldownOnSpawnSkillname[raceid][skillid],32,"ERR deprecated cooldown on spawn");
}

	
	
	
	
	
	
	

	
	
	
	

	
	
	
public Native_War3_CooldownMGR(Handle:plugin,numParams)
{
	if(numParams>=4){
		new client = GetNativeCell(1);
		new Float:cooldownTime= GetNativeCell(2);
		new raceid = GetNativeCell(3);
		new skillNum = GetNativeCell(4); ///can use skill numbers
		new bool:resetOnSpawn=true;
		if(numParams>4){
			resetOnSpawn = GetNativeCell(5);
		}
		new bool:resetOnDeath=true;
		if(numParams>5){
			resetOnDeath = GetNativeCell(6);
		}
		new bool:printMsgOnExpireByTime=true;
		if(numParams>6){
			printMsgOnExpireByTime = GetNativeCell(7);
		}
		new String:skillNameStr[64];
		//if(numParams>7){
		//	GetNativeString(8,skillNameStr,sizeof(skillNameStr));
		//}
		Format(skillNameStr,sizeof(skillNameStr),"ERR deprecated cooldown ");
		Internal_CreateCooldown(client,cooldownTime,raceid,skillNum,resetOnSpawn,resetOnDeath,printMsgOnExpireByTime,skillNameStr);
	}
}
public Native_War3_CooldownRMN(Handle:plugin,numParams) //cooldown remaining time
{
	if(numParams==3){
		new client = GetNativeCell(1);
		new raceid = GetNativeCell(2);
		new skillNum = GetNativeCell(3); ///can use skill numbers
		
		new index=GetCooldownIndexByCRS(client,raceid,skillNum);
		if(index>0){
			return RoundToCeil(Cooldown[index][cexpiretime]-GetGameTime());
		}
		return _:0.0;
	}
	return -1;
}
public Native_War3_CooldownReset(Handle:plugin,numParams)
{
	if(numParams==3){
		new client = GetNativeCell(1);
		new raceid = GetNativeCell(2);
		new skillNum = GetNativeCell(3); ///can use skill numbers
		CooldownResetByCRS(client,raceid,skillNum);
	}
	return -1;
}
public Native_War3_SkillNIC(Handle:plugin,numParams) //NOT IN COOLDOWN , skill available
{
	if(numParams>=3){
		new client = GetNativeCell(1);
		new raceid = GetNativeCell(2);
		new skillNum = GetNativeCell(3); ///can use skill numbers
		new bool:printTextIfNotReady=false;
		if(numParams>3){
			printTextIfNotReady=GetNativeCell(4);
		}
		new bool:result= InternalIsSkillNotInCooldown(client,raceid,skillNum);
		if(result==false&&printTextIfNotReady){
			Internal_PrintSkillNotAvailable(GetCooldownIndexByCRS(client,raceid,skillNum));
		}
		return result;
	}
	return -1;
}
public Native_War3_PrintSkillINR(Handle:plugin,numParams)
{
	if(numParams==3){
		new client = GetNativeCell(1);
		new raceid = GetNativeCell(2);
		new skillNum = GetNativeCell(3); ///can use skill numbers
		
		
		Internal_PrintSkillNotAvailable(GetCooldownIndexByCRS(client,raceid,skillNum)); //cooldown inc
	}
	return -1;
}
	
	
	
	
public OnClientPutInServer(client){
	
}
		
ClearAllCooldowns()
{

			///we just dump the entire linked list
	for(new i=0;i<MAXCOOLDOWNS;i++){
		//we need to "unenable" aka free each cooldown
		Cooldown[i][cexpiretime]=0.0;
		
	}
	Cooldown[0][cnext]=0;
	
	
	for(new i=1;i<=MaxClients;i++)
	{
		for(new raceid=0;raceid< MAXRACES;raceid++)
		{
			for(new skillNum=0;skillNum<MAXSKILLCOUNT;skillNum++)
			{
				//CooldownExpireTime[i][raceid][skillNum]=0.0;
				
		
				
				CooldownPointer[i][raceid][skillNum]=0;
			}
		}
	}
}


Internal_CreateCooldown(client,Float:cooldownTime,raceid,skillNum,bool:resetOnSpawn,bool:resetOnDeath,bool:printMsgOnExpireByTime,String:skillNameStr[]){

	new indextouse=-1;
	new bool:createlinks=true;
	if(CooldownPointer[client][raceid][skillNum]>0){ //already has a cooldown
		indextouse=CooldownPointer[client][raceid][skillNum];
		createlinks=false;
	}
	else{
		for(new i=1;i<MAXCOOLDOWNS;i++){
			if(Cooldown[i][cexpiretime]<1.0){ //consider this one empty
				indextouse=i;
				break;
				
			}
		}
	}
	
	if(indextouse==-1){
		LogError("ERROR, UNABLE TO CREATE COOLDOWN");
	}
	else{
		if(createlinks){ //if u create links again and u are already link from the prevous person, u will infinite loop
			Cooldown[indextouse][cnext]=Cooldown[indextouse-1][cnext]; //this next is the previous guy's next
			Cooldown[indextouse-1][cnext]=indextouse; //previous guy points to you
		}
		
		Cooldown[indextouse][cexpiretime]=GetGameTime()+cooldownTime;
		Cooldown[indextouse][cclient]=client;
		Cooldown[indextouse][crace]=raceid;
		Cooldown[indextouse][cskill]=skillNum;
		Cooldown[indextouse][cexpireonspawn]=resetOnSpawn;
		Cooldown[indextouse][cexpireondeath]=resetOnDeath;
		Cooldown[indextouse][cprintmsgonexpire]=printMsgOnExpireByTime;
		Format(Cooldown[indextouse][cskillname],64,"%s",skillNameStr);
		
		CooldownPointer[client][raceid][skillNum]=indextouse;
	}
}
public Action:DeciSecondTimer(Handle:h,any:data){
	
	CheckCooldownsForExpired(false,false);
}
CheckCooldownsForExpired(bool:expirespawn,bool:expiredeath,client=0)
{
	
	new Float:currenttime=GetGameTime();
	new tempnext;
	new skippedfrom;
	for(new i=0;i<MAXCOOLDOWNS;i++){
		if(Cooldown[i][cexpiretime]>1.0) //enabled
		{
			//PrintToChatAll("ENABLED");
			new bool:expired;
			new bool:bytime;
			if(currenttime>Cooldown[i][cexpiretime]){
				expired=true;
				bytime=true;
			}
			else if(expirespawn&&Cooldown[i][cclient]==client&&Cooldown[i][cexpireonspawn]){
				expired=true;
			}
			
			else if(expiredeath&&Cooldown[i][cclient]==client&&Cooldown[i][cexpireondeath]){
				expired=true;
			}
			
			
			if(expired)
			{
				//PrintToChatAll("EXPIRED");
				CooldownExpired(i, bytime);
				Cooldown[i][cexpiretime]=0.0;
				
				if(i>0){ //not front do some pointer changes
					Cooldown[skippedfrom][cnext]=Cooldown[i][cnext];
					//PrintToChatAll("changing next at %d to %d",skippedfrom,Cooldown[i][cnext]);
					
					
				}
				
				//PrintToChatAll("CD expired %d %d %d",Cooldown[i][cclient],Cooldown[i][crace],Cooldown[i][cskill]);
				
				i=skippedfrom;
			}
		}
		tempnext=Cooldown[i][cnext];
		
		//PrintToChatAll("cooldown for: %d %d %d %s @ %f, skip to %d",Cooldown[i][cclient],Cooldown[i][crace],Cooldown[i][cskill],Cooldown[i][cskillname],Cooldown[i][cexpiretime],tempnext);
		
		if(tempnext==0){
			//PrintToChatAll("DeciSecondTimer break because next is zero at index %d",i);
			break;
		}	
		skippedfrom=i;
		i=tempnext-1;
	}
}


CooldownResetByCRS(client,raceid,skillnum){
	if(CooldownPointer[client][raceid][skillnum]>0){
		Cooldown[CooldownPointer[client][raceid][skillnum]][cexpiretime]=GetGameTime(); ///lol
	}
}
CooldownExpired(i,bool:expiredByTimer)
{	
	new client=Cooldown[i][cclient]
	new raceid=Cooldown[i][crace]
	new skillNum=Cooldown[i][cskill];
	CooldownPointer[client][raceid][skillNum]=-1;

	if(expiredByTimer){
		if(ValidPlayer(client,true)&&Cooldown[i][cprintmsgonexpire]&&War3_GetRace(client)==raceid){ //if still the same race and alive
			if(War3_GetSkillLevel(client,raceid,skillNum)>0){
			//if(War3_IsSkillUltimate(raceid,skillNum)){
				new String:skillname[64];
				SetTrans(client);
				W3GetRaceSkillName(raceid,skillNum,skillname,sizeof(skillname));
			//	if(strlen(Cooldown[i][cskillname])>0){
				PrintHintText(client,"%T","{ultimate} Is Ready",client,skillname);
			//	PrintHintText(client,"%T","{ultimate} Is Ready",client,Cooldown[i][cskillname]);
				//}
			//	else{
				//	PrintHintText(client,"%T","Ultimate Is Ready",client);
			//	}
			//}
			//else{
		//		if(strlen(Cooldown[i][cskillname])>0){
		//			PrintHintText(client,"%T","{ability} Is Ready",client,Cooldown[i][cskillname]);
			//	}
			//	else{
			//		PrintHintText(client,"%T","Ability Is Ready",client);
			//	}
		//	}
			
				EmitSoundToAll( War3_IsSkillUltimate(raceid,skillNum)?ultimateReadySound:abilityReadySound , client);
			}
		}
	}

	Call_StartForward(g_CooldownExpiredForwardHandle);
	Call_PushCell(client);
	Call_PushCell(raceid);
	Call_PushCell(skillNum);
	Call_PushCell(expiredByTimer);
	new result;
	Call_Finish(result); //this will be returned to ?
}


public bool:InternalIsSkillNotInCooldown(client,raceid,skillNum){
	new index=GetCooldownIndexByCRS(client,raceid,skillNum);
	if(index>0){
		return false; //has record = in cooldown
	}
	return true; //no cooldown record
}
GetCooldownIndexByCRS(client,raceid,skillNum){
	
	return CooldownPointer[client][raceid][skillNum];

}

public Internal_PrintSkillNotAvailable(cooldownindex){
	new client=Cooldown[cooldownindex][cclient];
	//new String:skillname[64];
	new race=Cooldown[cooldownindex][crace];
	new skill=Cooldown[cooldownindex][cskill];
	//Format(skillname,sizeof(skillname),"%s",Cooldown[cooldownindex][cskillname]);
	if(ValidPlayer(client,true)){
		new String:skillname[64];
		SetTrans(client);
		W3GetRaceSkillName(race,skill,skillname,sizeof(skillname));
		PrintHintText(client,"%T","{skill} Is Not Ready. {amount} Seconds Remaining",client,skillname,War3_CooldownRemaining(client,race,skill));
		/*if(strlen(skillname)>0)
		{
			PrintHintText(client,"%T","{skill} Is Not Ready. {amount} Seconds Remaining",client,skillname,War3_CooldownRemaining(client,race,skill));
		}
		else
		{
			if(War3_IsSkillUltimate(race,skill))
			{
				PrintHintText(client,"%T","Ultimate Is Not Ready. {amount} Seconds Remaining",client,War3_CooldownRemaining(client,race,skill));
			}
			else
			{
				PrintHintText(client,"%T","Ability Is Not Ready. {amount} Seconds Remaining",client,War3_CooldownRemaining(client,race,skill));
			}
		}*/
	}
}

public OnWar3EventSpawn(client){
	

	CheckCooldownsForExpired(true,false,client)
	
	new race=War3_GetRace(client);
	for(new i=0;i<MAXSKILLCOUNT;i++){
		if(CooldownOnSpawn[race][i]){ //only his race
			
			Internal_CreateCooldown(client,CooldownOnSpawnDuration[race][i],race,i,false,true,CooldownOnSpawnPrint[race][i],CooldownOnSpawnSkillname[race][i]);
		}
		
	}
}
public OnWar3EventDeath(victim){
	CheckCooldownsForExpired(false,true,victim)
}