--[[-------------------------------------------------------------------------
Xmas Lights Gun - Revision 1

This is almost complete rewrite of the original from archi who rewrote the 2011 version
however doesn't matter how cool the code is or how the lights work there's still a lot.

TODO:
	- Find better way to update lights, SWEP:Think only updates when you have the gun out.
	- Network the lights to client to allow use of DLight and Glow effects.
	- Optimize the fuck out of this since it puts quite payload on server.
	- Change the grenade viewmodel for lightbulb.
	- Make the framerate do something, after all i added it for a reason!
---------------------------------------------------------------------------]]

AddCSLuaFile();

SWEP.PrintName		= "#GMOD_XLights";		
SWEP.Author		= "Feihc, ArchiCZ, BlacK";
SWEP.Category		= "Fun";
SWEP.Instructions   	= "Left click to spawn a light, Right click to remove, Reload to remove all.";

SWEP.Contact        	= "";
SWEP.Purpose        	= "";
SWEP.Spawnable      	= true;
SWEP.AdminSpawnable 	= true;

SWEP.Slot		= 5;
SWEP.SlotPos		= 7;
SWEP.ViewModelFOV	= 70;

SWEP.UseHands	= true
SWEP.ViewModel	= "models/weapons/v_grenade.mdl";
SWEP.WorldModel	= "models/weapons/w_grenade.mdl";
SWEP.ShowViewModel	= true;
SWEP.ShowWorldModel	= true;

SWEP.Primary.Delay		= -1;
SWEP.Primary.ClipSize		= -1;
SWEP.Primary.DefaultClip	= -1;
SWEP.Primary.Automatic		= false;
SWEP.Primary.Ammo		= "none";

SWEP.Secondary.Delay		= -1;
SWEP.Secondary.ClipSize		= -1;
SWEP.Secondary.DefaultClip	= -1;
SWEP.Secondary.Automatic	= false;
SWEP.Secondary.Ammo		= "none";

SWEP.Sounds = {

	"physics/glass/glass_bottle_impact_hard1.wav",
	"physics/glass/glass_bottle_impact_hard2.wav",
	"physics/glass/glass_bottle_impact_hard3.wav",

}

SWEP.LightsLimit	= CreateConVar( "xlights_maxlights", 64, { FCVAR_NOTIFY, FCVAR_REPLICATED, FCVAR_UNLOGGED, FCVAR_ARCHIVE, FCVAR_DONTRECORD }, "Controls amount of lights player can spawn using xmas lights gun." );
SWEP.LightsRate		= CreateConVar( "xlights_framerate", 30, { FCVAR_NOTIFY, FCVAR_REPLICATED, FCVAR_UNLOGGED, FCVAR_ARCHIVE, FCVAR_DONTRECORD }, "Just like framerate of your game this is framerate of lights." );
--[[-------------------------------------------------------------------------
Just quick note to any retards who set the framerate to 144 or huge values
You won't get super smooth lights for multiple reasons and here they are.
1. cl_updaterate and sv_maxupdaterate must have higher or equal value.
2. Your framerate has to be higher or equal to framerate of the lights.
3. You need a monitor with refreshrate higher or equal to framerate of lights.
4. You need hell of a server to run 144 tickrate just for the lights to look smooth.

Hopefully you aren't one of the retards who set the framerate above 60 or 64 ;)
---------------------------------------------------------------------------]]

function SWEP:Initialize()

	for index, sound in next, self.Sounds do

		util.PrecacheSound( sound );

	end

end

function SWEP:Deploy()
	-- Don't bother doing anything on client --
	if ( SERVER and self.Owner ) then 
		-- We are a player or are we? --
		if ( self.Owner:IsPlayer() ) then 

			-- Bruh --
			self.Owner.Lights = self.Owner.Lights or {};

		else

			-- Explode if not handled by player to prevent any conflicts and problems --
			self.Owner:EmitSound( Sound( "vo/npc/female01/ohno.wav" ), 75, 100, 1, CHAN_AUTO );
			timer.Simple( 1.2, function() 
				-- Failsafe --
				if ( !IsValid( self ) or !IsValid( self.Owner ) ) then return; end

				local Explosion = ents.Create( "env_explosion" );
				-- Just in case, Better safe than sorry --
				if ( Explosion ) then

					Explosion:SetPos( self.Owner:GetPos() );
					Explosion:SetOwner( self.Owner );
					Explosion:Spawn();
					Explosion:SetKeyValue( "iMagnitude", "220" );
					Explosion:Fire( "Explode", 0, 0 );

				end

			end );

		end

	end

end

--[[-------------------------------------------------------------------------
This function is here in case someone tries to attach a light to parented entity,
however the parented entity can also be parented to another entity which is also parented.
You get what i mean don't you, Well this is a quite basic solution to it.

Note: This could cause infite loops if you parent two entities onto eachother.
---------------------------------------------------------------------------]]
function SWEP:GetPhysicalParent( entity )

	local parent = entity:GetParent();

	if ( IsValid( parent ) ) then 

		return self:GetPhysicalParent( parent );

	end

	return entity;

end

function SWEP:Think()

	if ( SERVER and self.Owner and self.Owner.Lights ) then 

		local Step = 1 - ( 1 / #self.Owner.Lights );

		for Index, Light in next, self.Owner.Lights do

			if ( Light and Light.Sprite ) then 

				local Pulse		= 0.2 - math.abs( math.sin( CurTime() ) * 0.2 );
				local ColHue	= 360 * ( Step * Index ); 
				local HueAdd	= 60 * CurTime();
				local Color		= HSVToColor( ( ColHue + HueAdd ) % 360, 0.7 + Pulse, 1 );
				local R, G, B	= Color.r, Color.g, Color.b;
				local String	= string.format( "%s %s %s", R, G, B );

				Light.Sprite:SetKeyValue( "rendercolor", String );

			end

		end

	end

end

function SWEP:CreateLight()

	local Light = ents.Create( "prop_physics" );
	local Trace = self.Owner:GetEyeTrace();

	-- Did the light we just created even exist or did the creation fail ? :c --
	if ( IsValid( Light ) ) then 

		local Sound		= Sound( table.Random( self.Sounds ) );
		local Lights	= self.Owner.Lights;
		local Count		= #Lights;

		-- Setting the light --
		Light:SetModel( "models/maxofs2d/light_tubular.mdl" );
		Light:SetPos( Trace.HitPos );
		Light:SetAngles( Trace.HitNormal:Angle() - Angle( 90, 0, 0 ) );
		Light:Spawn();
		Light:Activate();
		Light:EmitSound( Sound, 75, 100, 1, CHAN_AUTO );
		Light.Index = Count;

		-- Physics! --
		local Phys = Light:GetPhysicsObject();
		if ( IsValid( Phys ) ) then 

			--[[-------------------------------------------------------------------------
			Yes 25kg tubular light i get it it's kinda retarded but who gives a shit lol
			like you are playing garry's mod, what the hell is your problem jesus christ.

			Btw drag coefficient is modified to prevent ropes from making the lights go wild.
			---------------------------------------------------------------------------]]
			Phys:SetMaterial( "glass" );
			Phys:EnableMotion( false );
			Phys:EnableDrag( true );
			Phys:SetDragCoefficient( 2.5 );
			Phys:SetMass( 25 );
			Phys:Wake();

		end

		-- Connecting the lights together --
		if ( Count != 0 ) then 
			-- The last light created right before this one --
			local LightEx = Lights[ Count ];
			-- Does it still exist or did it magically disappear from our world ? --
			if ( IsValid( LightEx ) ) then 

				-- This needs rewrite, Seriously --
				local Length = ( LightEx:GetPos() - Light:GetPos() ):Length();
				constraint.Rope( LightEx, Light, 0, 0, Vector( 0, 0, 5 ), Vector( 0, 0, 5 ), 60 + Length, 0, 0, 2, "models/rendertarget", false );

			else

				-- The light doesn't exist anyways soo ?? --
				table.remove( self.Owner.Lights, Count );

			end

		end

		if ( Trace.Entity ) then 

			local Entity = Trace.Entity;

			if ( !Entity:IsWorld() or Entity:IsPlayer() ) then 

				local Parent = self:GetPhysicalParent( Entity );
				Light:SetParent( Parent );

			end

		end

		table.insert( self.Owner.Lights, Light );
		return Light;

	end

	return false;

end

function SWEP:FestivizeLight( Entity )

	local Sprite = ents.Create( "env_sprite" );

	if ( Sprite ) then

		Sprite:SetPos( Entity:LocalToWorld( Vector( 0, 0, -4 ) ) );
		Sprite:SetKeyValue( "renderfx", "4" );
		Sprite:SetKeyValue( "model", "sprites/glow1.vmt" );
		Sprite:SetKeyValue( "spawnflags", "1" );
		Sprite:SetKeyValue( "angles", "0 0 0" );
		Sprite:SetKeyValue( "rendermode", "9" );
		Sprite:SetKeyValue( "renderamt", "255" );
		Sprite:SetKeyValue( "HDRColorScale", "0.85" );
		Sprite:SetKeyValue( "rendercolor", "255 255 255" );
		Sprite:Spawn();
		Sprite:Activate();
		Sprite:SetParent( Entity );

		Entity.Sprite = Sprite;

	end

end

function SWEP:PrimaryAttack()

	if ( self.Owner and self.Owner.Lights ) then 

		local Lights	= self.Owner.Lights;
		local Count		= #Lights;
		local MaxLights	= self.LightsLimit:GetInt();

		if ( Count < MaxLights or MaxLights == 0 ) then 

			self.Owner:LagCompensation( true );

			local Light = self:CreateLight();

			if ( Light ) then 

				self:FestivizeLight( Light );

			end

			self.Owner:LagCompensation( false );

		end

	end

end

function SWEP:SecondaryAttack()

	if ( self.Owner and self.Owner.Lights ) then 

		local Count	= #self.Owner.Lights;
		local Light	= self.Owner.Lights[ Count ];

		-- Does the light even exist or did it somehow disappear into the void ? :o --
		if ( IsValid( Light ) ) then 

			constraint.RemoveAll( Light );
			Light:Remove();

		end

		table.remove( self.Owner.Lights, Count );

	end

end

function SWEP:Reload()

	if ( self.Owner and self.Owner.Lights ) then 

		for Index, Light in next, self.Owner.Lights do

			if ( IsValid( Light ) ) then 

				constraint.RemoveAll( Light );
				Light:Remove();

			end

			table.remove( self.Owner.Lights, Index );

		end

	end

end

function SWEP:Holster()

	return true;

end

function SWEP:OnRemove()
--[[-------------------------------------------------------------------------
Would propably be worth deleting all the lights here but it doesn't matter,
Lights are stored on player not swep itself so as long as player exists we fine.

It's really up to you what you put here, I felt like leaving this blank.
---------------------------------------------------------------------------]]
end
