' Helper functions for rewards
' Use like this
' 	rewards = SwrveReward()
'   rewards = rewards.AddSwrveReward(rewards, "currency", "BTC", 0.001)
'   rewards = rewards.AddSwrveReward(rewards, "item", "bundle_item02", 200)
Function SwrveReward() as Object
	this = {}
	this.rewardsData = {}
	this.AddSwrveReward = AddSwrveReward

	return this
End Function

Function AddSwrveReward(rewards as Object, rewardType as String, name as String, amount as Integer) as Object
	if rewards = invalid
		rewards = {}
	end if
	rewards.rewardsData.AddReplace(name, { "type": rewardType, "amount" : amount })
	return rewards
End Function