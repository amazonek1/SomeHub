--!strict

return function(checkExecutor, chuj1, chuj2)
    for i, v in next, checkExecutor do
        if not getgenv().i or not i(v) then
            return game.Players.LocalPlayer:Kick(`Something went wrong with {tostring(i)}`)
        end
    end
end, getgenv()
