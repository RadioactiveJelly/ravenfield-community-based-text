-- Register the behaviour
behaviour("CommunityBasedText")

opposite_team = {[Team.Blue] = Team.Red, [Team.Red] = Team.Blue}

function CommunityBasedText:Awake()
	self.gameObject.name = "CBT"

	self.onMatchBeginLines = {}
	self.onVictoryLines = {}
	self.onDefeatLines = {}
	self.onKillEnemyLines = {}
	self.onKillFriendlyLines = {}
	self.onKilledByEnemyLines = {}
	self.onKilledByFriendlyLines = {}
	self.onAttackCapturePointLines = {}
	self.onDefendCapturePointLines = {}
	self.onRoamCapturePointLines = {}


	self.onKillEnemyChance = self.script.mutator.GetConfigurationRange("OnKillEnemyChance")/100
	self.onKillFriendlyChance = self.script.mutator.GetConfigurationRange("OnKillFriendlyChance")/100
	self.onKilledByEnemyChance = self.script.mutator.GetConfigurationRange("OnKilledByEnemyChance")/100
	self.onKilledByFriendlyChance = self.script.mutator.GetConfigurationRange("OnKilledByFriendlyChance")/100

	self.onMatchBeginChance = self.script.mutator.GetConfigurationRange("OnMatchBeginChance")/100
	self.onVictoryChance = self.script.mutator.GetConfigurationRange("OnVictoryChance")/100
	self.onDefeatChance = self.script.mutator.GetConfigurationRange("OnDefeatChance")/100

	self.onAttackChance = self.script.mutator.GetConfigurationRange("OnAttackPointChance")/100
	self.onDefendChance = self.script.mutator.GetConfigurationRange("OnDefendPointChance")/100
	self.onRoamChance = self.script.mutator.GetConfigurationRange("OnRoamPointChance")/100

	self.delay = 0.5
	self.delayVariance = 0.5

	self.maxLines = 10
	self.lines = {}
	for i=1,self.maxLines do
		self.lines[i] = ""
	end

	self:UpdateText()

	GameEvents.onMatchEnd.AddListener(self,"OnMatchEnd")
	GameEvents.onActorDiedInfo.AddListener(self,"OnActorDied")
	GameEvents.onActorSpawn.AddListener(self,"OnActorSpawn")
	GameEvents.onSquadAssignedNewOrder.AddListener(self, "OnSquadAssignedNewOrder");

	self.hasSpawned = false
	self.isMatchDone = false
end

function CommunityBasedText:OnActorDied(actor, damageInfo, isSilentKill)
	if isSilentKill then return end
	if damageInfo.sourceActor == nil then return end

	if not actor.isPlayer then
		if actor.team ~= damageInfo.sourceActor.team and RandomChance(self.onKilledByEnemyChance) then
			self.script.StartCoroutine(self:GetAndPushLineAfterDelay(actor,damageInfo.sourceActor,self.onKilledByEnemyLines))
		elseif actor.team == damageInfo.sourceActor.team and RandomChance(self.onKilledByFriendlyChance) then
			self.script.StartCoroutine(self:GetAndPushLineAfterDelay(actor,damageInfo.sourceActor,self.onKilledByFriendlyLines))
		end
	end

	if not damageInfo.sourceActor.isPlayer then
		if actor.team ~= damageInfo.sourceActor.team and RandomChance(self.onKillEnemyChance) then
			self.script.StartCoroutine(self:GetAndPushLineAfterDelay(damageInfo.sourceActor,actor,self.onKillEnemyLines))
		elseif actor.team == damageInfo.sourceActor.team and RandomChance(self.onKillFriendlyChance) then
			self.script.StartCoroutine(self:GetAndPushLineAfterDelay(damageInfo.sourceActor,actor,self.onKillFriendlyLines))
		end
		
	end
end

function CommunityBasedText:OnMatchEnd(team)
	self.script.StartCoroutine(self:SequentialTextSequence(team, self.onVictoryLines,self.onVictoryChance))
	self.script.StartCoroutine(self:SequentialTextSequence(opposite_team[team], self.onDefeatLines,self.onDefeatChance))

	self.isMatchDone = true
end

function CommunityBasedText:OnActorSpawn(actor)
	if self.hasSpawned then return end

	self.script.StartCoroutine(self:SequentialTextSequence(Team.Blue, self.onMatchBeginLines, self.onMatchBeginChance))
	self.script.StartCoroutine(self:SequentialTextSequence(Team.Red, self.onMatchBeginLines, self.onMatchBeginChance))
	
	self.hasSpawned = true
end


function CommunityBasedText:GetAndPushLine(speaker, target, messages)
	local line = self:GetLine(speaker, target, messages)
	if line ~= "" then
		self:PushLine(line)
	end
end

function CommunityBasedText:GetLine(speaker, target, messages)
	if speaker == nil then return "" end
	if messages == nil then return "" end
	if #messages < 1 then return "" end

	local line = messages[math.random(#messages)]

	if target then
		line = string.format(line, target.name)
	end

	local speakerName = self:FormatActorName(speaker)

	return speakerName .. ": " .. line
end

function CommunityBasedText:PushLine(line)
	for i=1,self.maxLines-1 do
		self.lines[i] = self.lines[i+1]
	end
	self.lines[self.maxLines] = line

	self:UpdateText()
end

function CommunityBasedText:UpdateText()
	local finalString = ""

	for i=1,self.maxLines do
		if self.lines[i] ~= "" then
			finalString = finalString .. self.lines[i] .. "\n"
		end
	end

	self.targets.ChatBox.text = finalString
end

function CommunityBasedText:OnSquadAssignedNewOrder(squad, order)
	if Player.actor and Player.actor.team ~= squad.leader.team then
		return
	end

	if self.isMatchDone then return end

	local chance = 0
	local messages = nil
	if order.type == OrderType.Attack then
		chance = self.onAttackChance
		messages = self.onAttackCapturePointLines
	elseif order.type == OrderType.Defend then
		chance = self.onDefendChance
		messages = self.onDefendCapturePointLines
	elseif order.type == OrderType.Roam then
		chance = self.onRoamChance
		messages = self.onRoamCapturePointLines
	else
		return
	end

	if not RandomChance(chance) then
		return
	end

	if messages == nil then return end
	if #messages < 1 then return end

	local sourceActor = squad.leader;
	local memberCount = #squad.members;
	if squad.hasPlayerLeader then
		if(memberCount == 1) then
			return
		else
			sourceActor = squad.members[2]
			memberCount = memberCount - 1;
		end
	end

	self:GetAndPushLine(sourceActor, order.targetPoint, messages)
end

function CommunityBasedText:AddLinePack(linePack)
	for i, line in ipairs(linePack.onMatchBeginLines) do
		table.insert(self.onMatchBeginLines, line)
	end

	for i, line in ipairs(linePack.onVictoryLines) do
		table.insert(self.onVictoryLines, line)
	end

	for i, line in ipairs(linePack.onDefeatLines) do
		table.insert(self.onDefeatLines, line)
	end

	for i, line in ipairs(linePack.onKillEnemyLines) do
		table.insert(self.onKillEnemyLines, line)
	end

	for i, line in ipairs(linePack.onKillFriendlyLines) do
		table.insert(self.onKillFriendlyLines, line)
	end

	for i, line in ipairs(linePack.onKilledByEnemyLines) do
		table.insert(self.onKilledByEnemyLines, line)
	end

	for i, line in ipairs(linePack.onKilledByFriendlyLines) do
		table.insert(self.onKilledByFriendlyLines, line)
	end

	for i, line in ipairs(linePack.onAttackCapturePointLines) do
		table.insert(self.onAttackCapturePointLines, line)
	end

	for i, line in ipairs(linePack.onDefendCapturePointLines) do
		table.insert(self.onDefendCapturePointLines, line)
	end

	for i, line in ipairs(linePack.onRoamCapturePointLines) do
		table.insert(self.onRoamCapturePointLines, line)
	end
end


function CommunityBasedText:GetAndPushLineAfterDelay(speaker, target, messages)
	return function()
		coroutine.yield(WaitForSeconds(self.delay + math.random() * self.delayVariance))
		self:GetAndPushLine(speaker,target,messages)
	end
end

function CommunityBasedText:FormatActorName(actor)
	return ColorScheme.FormatTeamColor(actor.name, actor.team, ColorVariant.Bright)
end

function RandomChance(chance)
	return math.random() < chance
end

function CommunityBasedText:SequentialTextSequence(team, messages, chance)
	return function()
		local baseInterval = 0.5
		local intervalVariance = 0.5

		local interval = baseInterval + math.random() * intervalVariance
		local intervalTimer = 0 

		for i, actor in ipairs(ActorManager.GetActorsOnTeam(team)) do
			if not actor.isPlayer then
				while(intervalTimer < interval) do
					intervalTimer = intervalTimer + Time.deltaTime
					coroutine.yield(nil)
				end
				intervalTimer = 0
				if RandomChance(chance) then
					self:GetAndPushLine(actor, nil, messages)
				end
			end
			coroutine.yield(nil)
		end
	end
end