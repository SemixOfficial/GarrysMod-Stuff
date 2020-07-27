--[[-------------------------------------------------------------------------
How to win every HvH, https://github.com/SemixOfficial/GarrysMod-Stuff/
---------------------------------------------------------------------------]]

AddCSLuaFile();

SWEP.PrintName			= "#GMOD_Owned";		
SWEP.Author				= "BlacK";
SWEP.Category			= "Fun";
SWEP.Instructions   	= "Hold left mouse button to destroy everyone...";

SWEP.Contact        	= "";
SWEP.Purpose        	= "Become the greatest and unbeatable HvH god in less than a minute!";
SWEP.Spawnable      	= true;
SWEP.AdminSpawnable 	= true;

SWEP.Slot			= 2;
SWEP.SlotPos		= 7;
SWEP.ViewModelFOV	= 70;
SWEP.ViewModelFlip	= true;
SWEP.CSMuzzleFlashes	= true;

SWEP.AutoSwitchTo 	= true;
SWEP.AutoSwitchFrom = false;

SWEP.UseHands	= true
SWEP.ViewModel	= "models/weapons/v_rif_ak47.mdl";
SWEP.WorldModel	= "models/weapons/w_rif_ak47.mdl";

SWEP.Primary.Delay			= 0.1;
SWEP.Primary.ClipSize		= -1;
SWEP.Primary.DefaultClip	= -1;
SWEP.Primary.Automatic		= true;
SWEP.Primary.Ammo			= "none";
SWEP.Primary.Sound			= "weapons/ak47/ak47-1.wav";

SWEP.Secondary.Delay		= -1;
SWEP.Secondary.ClipSize		= -1;
SWEP.Secondary.DefaultClip	= -1;
SWEP.Secondary.Automatic	= false;
SWEP.Secondary.Ammo			= "none";
SWEP.Secondary.Sound		= "none";

SWEP.IsZS = engine.ActiveGamemode() == "zombiesurvival";

function SWEP:Initialize()
	self:SetHoldType("ar2");
	self:SetDeploySpeed(0.9);
	util.PrecacheSound(self.Primary.Sound);
	util.PrecacheSound("player/bhit_helmet-1.wav");
end

function SWEP:Deploy()
	if (self.Owner and !self.Owner:IsPlayer()) then 
		self:Remove();
	end
end

function SWEP:FindClosestToCrosshair()
	local tblPlayers	= player.GetAll();
	local vecAimVector	= self.Owner:GetAimVector();
	local vecShootPos	= self.Owner:GetShootPos();
	local flClosestFoV	= math.huge;
	local flCurrentTime	= CurTime();
	local plyClosest	= false;

	for i = 1, #tblPlayers do
		local plyPlayer = tblPlayers[i];
		if (plyPlayer:Alive() and plyPlayer != self.Owner) then 
			if (plyPlayer.m_flLastShot and (flCurrentTime - plyPlayer.m_flLastShot) <= self.Primary.Delay) then 
				continue; end

			-- ZS compatibility --
			if (self.IsZS and plyPlayer:Team() == self.Owner:Team()) then
				continue; end

			local vecPostion	= plyPlayer:LocalToWorld(plyPlayer:OBBCenter());
			local vecDirection	= (vecPostion - vecShootPos):GetNormalized();
			local flDotToTarget	= vecAimVector:Dot(vecDirection);
			local flFoVToTarget = math.deg(math.acos(flDotToTarget));

			if (flFoVToTarget < flClosestFoV) then 
				flClosestFoV	= flFoVToTarget;
				plyClosest		= plyPlayer;
			end
		end
	end
	return plyClosest;
end

function SWEP:PrimaryAttack()
	if (SERVER) then 
		local Target = self:FindClosestToCrosshair();
		if (Target) then 
			Target:GodDisable();
			Target:EmitSound(Sound("player/bhit_helmet-1.wav"));
			Target:TakeDamage(Target:Health(), self.Owner, self);

			local vecPosition	= Target:LocalToWorld(Vector(0, 0, Target:OBBMaxs().z * 0.85));
			local vecDirection	= (vecPosition - self.Owner:GetShootPos()):GetNormalized();

			self.Owner:SetEyeAngles(vecDirection:Angle());

			Target.m_flLastShot = CurTime();
		end

		self.Owner:FireBullets({
			Attacker	= self,
			Damage		= 0,
			Force		= 100,
			Tracer		= 2,
			Dir			= self.Owner:GetAimVector(),
			Src			= self.Owner:GetShootPos(),
		});
	end

	self:ShootEffects();
	self:EmitSound(Sound(self.Primary.Sound));
	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay);
end


function SWEP:GetEspBoxBounds(entEntity)
	local tblBox = { x = math.huge, y = math.huge, w = math.huge * -1, h = math.huge * -1 };
	local vecBoxMins, vecBoxMaxs = entEntity:OBBMins(), entEntity:OBBMaxs();
	local vecBoundaryBoxCenter = entEntity:LocalToWorld(entEntity:OBBCenter()):ToScreen();
	local tblBoxBounds = { 

		Vector(vecBoxMins.x, vecBoxMins.y, vecBoxMins.z),
		Vector(vecBoxMins.x, vecBoxMins.y, vecBoxMaxs.z),
		Vector(vecBoxMins.x, vecBoxMaxs.y, vecBoxMins.z),
		Vector(vecBoxMins.x, vecBoxMaxs.y, vecBoxMaxs.z),
		Vector(vecBoxMaxs.x, vecBoxMins.y, vecBoxMins.z),
		Vector(vecBoxMaxs.x, vecBoxMins.y, vecBoxMaxs.z),
		Vector(vecBoxMaxs.x, vecBoxMaxs.y, vecBoxMins.z),
		Vector(vecBoxMaxs.x, vecBoxMaxs.y, vecBoxMaxs.z)

	};

	for i = 1, #tblBoxBounds do
		local vecBoundOrigin = entEntity:LocalToWorld(tblBoxBounds[i]):ToScreen();
		tblBox.x = math.min(tblBox.x, vecBoundOrigin.x, vecBoundaryBoxCenter.x - 2);
		tblBox.y = math.min(tblBox.y, vecBoundOrigin.y, vecBoundaryBoxCenter.y - 2);
		tblBox.w = math.max(tblBox.w, vecBoundOrigin.x, vecBoundaryBoxCenter.x + 2);
		tblBox.h = math.max(tblBox.h, vecBoundOrigin.y, vecBoundaryBoxCenter.y + 2);
	end

	-- values returned by ToScreen are never a float and never have decimal places and yet they fucking do --
	tblBox.x = math.floor(tblBox.x);
	tblBox.y = math.floor(tblBox.y);
	tblBox.w = math.ceil(tblBox.w - tblBox.x);
	tblBox.h = math.ceil(tblBox.h - tblBox.y);

	return tblBox;
end

function SWEP:IsValidEspPlayer(plyPlayer)
	if (!plyPlayer:IsDormant() and plyPlayer != LocalPlayer()) then 
		if (plyPlayer:Alive()) then 
			return true;
		end
	end
	return false;
end

function SWEP:DrawEspPlayer(plyPlayer)
	local Box = self:GetEspBoxBounds(plyPlayer);
	local Friendly = IsZS and (plyPlayer:Team() == LocalPlayer():Team());

	surface.SetDrawColor(Friendly and Color(0, 255, 0, 255) or Color(220, 40, 40, 255));
	surface.DrawOutlinedRect(Box.x, Box.y, Box.w, Box.h);

	surface.SetDrawColor(Color(0, 0, 0, 255));
	surface.DrawOutlinedRect(Box.x - 1, Box.y - 1, Box.w + 2, Box.h + 2);
end

function SWEP:DrawPlayerEsp()
	local tblPlayers = player.GetAll();
	for i = 1, #tblPlayers do
		local plyPlayer = tblPlayers[i];
		if (self:IsValidEspPlayer(plyPlayer)) then 
			self:DrawEspPlayer(plyPlayer);
		end
	end
end

function SWEP:DrawHUD()
	self:DrawPlayerEsp();
end
