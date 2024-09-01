--[=[
@class Atlas
Atlas is a framework module that provides utility functions for managing and interacting with objects and modules within a Roblox game. 
]=]

--!strict
--!native
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
type FrameworkType = {
	LoadLibrary: (self: FrameworkType, ModuleName: string) -> any?,
	GetObject: (self: FrameworkType, ObjectName: string) -> Instance?,
	New: (self: FrameworkType, ClassName: string) -> Instance?,
	BindToTag: (self: FrameworkType, Tag: string, Callback: (Instance: Instance) -> ()) -> RBXScriptConnection,
	GetObjects: (self: FrameworkType, Tag: string) -> {Instance},
	ApplySettings: (self: FrameworkType, Object: Instance, Settings: {[string]: any}) -> (),
	GenerateUniqueId: (self: FrameworkType) -> string,
	LogOperation: (self: FrameworkType, Operation: string, Details: {[string]: any}?) -> (),
	DeepClone: (self: FrameworkType, Object: Instance) -> Instance,
	TagObject: (self: FrameworkType, Object: Instance, Tag: string) -> (),
	RemoveTag: (self: FrameworkType, Object: Instance, Tag: string) -> (),
	GetObjectWithTag: (self: FrameworkType, Tag: string) -> {Instance},
}
local Framework = {}
Framework.__index = Framework
local function SanitizeName(Name: any): string
    if typeof(Name) ~= "string" or Name == "" then
        error("Invalid Name provided", 2)
    end
    return Name:lower()
end

--[=[
    Tags an object with a specific tag.
    @within Atlas
    @param Object Instance -- The object to tag.
    @param Tag string -- The tag to assign to the object.
]=]
local function TagObject(Object: Instance, Tag: string)
    if not CollectionService:HasTag(Object, Tag) then
        CollectionService:AddTag(Object, Tag)
    end
end

--[=[
@within Atlas
    Loads a library module by its name.
    @param ModuleName string -- The name of the module to load.
    @return any? -- Returns the loaded module or nil if not found.
]=]
function Framework:LoadLibrary(ModuleName: string): any?
    ModuleName = SanitizeName(ModuleName)

    local Modules = CollectionService:GetTagged("FrameworkModule")

    for _, Module in ipairs(Modules) do
        if Module:IsA("ModuleScript") and Module.Name:lower() == ModuleName then
            local Success, Result = pcall(function()
                return require(Module)
            end)
            if Success then
                return Result
            else
                warn("Failed to load Module '" .. ModuleName .. "': " .. tostring(Result))
                return nil
            end
        end
    end

    warn("Module '" .. ModuleName .. "' not found!")
    return nil
end

--[=[
    @within Atlas
    Retrieves an object by name with an optional timeout.
    @param ObjectName string -- The name of the object to retrieve.
    @param Timeout number? -- The optional timeout duration.
    @return Instance? -- Returns the object if found, or nil if not.
]=]
function Framework:GetObject(ObjectName: string, Timeout: number?): Instance?
    ObjectName = SanitizeName(ObjectName)
    local StartTime = tick()
    local Objects
    local Tries = 9
    local Attempt = 0

    repeat
        Attempt = Attempt + 1
        Objects = CollectionService:GetTagged("Framework")
        if #Objects == 0 then
            warn("Attempt " .. Attempt .. ": No objects found with the 'Framework' tag.")
        else
            local FoundObject = false
            for _, Obj in ipairs(Objects) do
                if Obj.Name:lower() == ObjectName then
                    return Obj
                end
            end
            if not FoundObject then
--                warn("Attempt " .. Attempt .. ": No object found with the name '" .. ObjectName .. "'.")
            end
        end

        if Timeout and (tick() - StartTime) >= Timeout then
            warn("Timeout reached after " .. Attempt .. " attempts.")
            break
        end

        game["Run Service"].Heartbeat:Wait()
    until Attempt >= Tries

    warn("Object '" .. ObjectName .. "' not found after " .. Tries .. " attempts.")
    return nil
end

--[=[
    @within Atlas
    Creates a new instance of a specified class.
    @param ClassName string -- The class name of the instance to create.
    @return Instance? -- Returns the newly created instance, or nil if the class name is invalid.
]=]
function Framework:New(ClassName: string): Instance?
    local Success, NewObject = pcall(function()
        return Instance.new(ClassName)
    end)

    if Success and NewObject then
        TagObject(NewObject, "Framework")
        return NewObject
    else
        warn("Invalid ClassName: '" .. ClassName .. "'")
        return nil
    end
end

--[=[
    @within Atlas
    Binds a callback function to a tag. The callback is invoked for all existing objects with the tag and whenever a new object is tagged.
    @param Tag string -- The tag to bind the callback to.
    @param Callback function -- The callback function to execute when an object with the tag is found.
    @return RBXScriptConnection -- The connection to the event, which can be disconnected if needed.
]=]
function Framework:BindToTag(Tag: string, Callback: (Instance: Instance) -> ()): RBXScriptConnection
    if typeof(Tag) ~= "string" or typeof(Callback) ~= "function" then
        error("Invalid arguments for BindToTag", 2)
    end

    for _, Instance in ipairs(CollectionService:GetTagged(Tag)) do
        task.spawn(Callback, Instance)
    end

    return CollectionService:GetInstanceAddedSignal(Tag):Connect(function(Instance)
        task.spawn(Callback, Instance)
    end)
end

--[=[
    @within Atlas
    Retrieves all objects with a specific tag.
    @param Tag string -- The tag to search for.
    @return {Instance} -- Returns a table of all objects found with the tag.
]=]
function Framework:GetObjects(Tag: string): {Instance}
    if typeof(Tag) ~= "string" then
        error("Invalid Tag name", 2)
    end

    local Objects = CollectionService:GetTagged(Tag)

    if #Objects == 0 then
        warn("No objects found with Tag '" .. Tag .. "'")
    end
    return Objects
end

--[=[
    @within Atlas
    Applies a set of settings to an object.
    @param Object Instance -- The object to apply the settings to.
    @param Settings {[string]: any} -- A table of settings to apply.
]=]
function Framework:ApplySettings(Object: Instance, Settings: {[string]: any})
    if typeof(Object) ~= "Instance" or typeof(Settings) ~= "table" then
        error("Invalid arguments for ApplySettings", 2)
    end

    for Property, Value in pairs(Settings) do
        local Success = pcall(function()
            Object[Property] = Value
        end)
        if not Success then
            warn("Failed to apply setting '" .. Property .. "' on Object '" .. Object.Name .. "'")
        end
    end
end

--[=[
    @within Atlas
    Generates a unique ID using a GUID.
    @return string -- Returns a unique ID string.
]=]
function Framework:GenerateUniqueId(): string
    local Id = HttpService:GenerateGUID(false)
    return Id
end

--[=[
    @within Atlas
    Logs an operation with optional details.
    @param Operation string -- The operation to log.
    @param Details {[string]: any}? -- Optional details about the operation.
]=]
function Framework:LogOperation(Operation: string, Details: DetailsType)
    Operation = SanitizeName(Operation)

    Details = Details or {}
    for Key, Value in pairs(Details) do
        -- Removed debug logs
    end
end

--[=[
    @within Atlas
    Deep clones an object and tags all its descendants.
    @param Object Instance -- The object to clone.
    @return Instance -- Returns the cloned object.
]=]
function Framework:DeepClone(Object: Instance): Instance
    if not Object then
        error("No Object provided for cloning", 2)
    end

    local ClonedObject = Object:Clone()

    for _, Descendant in ipairs(ClonedObject:GetDescendants()) do
        TagObject(Descendant, "Framework")
    end

    return ClonedObject
end

--[=[
    @within Atlas
    Tags an object with a specific tag.
    @param Object Instance -- The object to tag.
    @param Tag string -- The tag to assign.
]=]
function Framework:TagObject(Object: Instance, Tag: string)
    Tag = SanitizeName(Tag)
    if typeof(Object) ~= "Instance" then
        error("Invalid Object for tagging", 2)
    end

    TagObject(Object, Tag)
end

--[=[
    Removes an object with a specific tag.
    @within Atlas
    @param Object Instance -- The object to tag.
    @param Tag string -- The tag to assign.
]=]
function Framework:RemoveTag(Object: Instance, Tag: string)
    Tag = SanitizeName(Tag)
    if typeof(Object) ~= "Instance" then
        error("Invalid Object for untagging", 2)
    end

    CollectionService:RemoveTag(Object, Tag)
end

--[=[
    @within Atlas
    Retrieves all objects with a specific tag.
    @param Tag string -- The tag to search for.
    @return {Instance} -- Returns a table of all objects found with the tag.
]=]
function Framework:GetObjectWithTag(Tag: string): {Instance}
    Tag = SanitizeName(Tag)
    if typeof(Tag) ~= "string" then
        error("Invalid Tag name", 2)
    end

    local Objects = CollectionService:GetTagged(Tag)

    if #Objects == 0 then
        warn("No objects found with Tag '" .. Tag .. "'")
    end

    return Objects
end

return Framework
