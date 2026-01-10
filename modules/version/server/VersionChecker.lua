Version = Version or {}

local function parseVersion(versionString)
    return versionString and versionString:match('%d+%.%d+%.%d+') or versionString
end

local function padVersion(version)
    local parts = {}
    for num in version:gmatch("%d+") do
        table.insert(parts, tonumber(num))
    end
    while #parts < 3 do
        table.insert(parts, 0)
    end
    return parts
end

local function compareVersions(v1, v2)
    local a, b = padVersion(v1), padVersion(v2)
    for i = 1, 3 do
        if a[i] < b[i] then
            return -1
        elseif a[i] > b[i] then
            return 1
        end
    end
    return 0
end

local function buildPatchNotesUrl(branch, repoPath)
    local username, reponame = repoPath:match("([^/]+)/([^/]+)")
    return ('https://raw.githubusercontent.com/%s/%s/%s/resources.json'):format(username, reponame, branch)
end

local function getDownloadUrl(repoPath, isTebex, actualRepoPath)
    if isTebex then
        return "https://portal.cfx.re/assets/granted-assets"
    elseif actualRepoPath then
        local username, reponame = actualRepoPath:match("([^/]+)/([^/]+)")
        if username and reponame then return ('https://github.com/%s/%s/releases/latest'):format(username, reponame) end
    end
    return nil
end

local function printUpdateAvailable(resource, localVersion, downloadUrl)
    print(('^1An update is available for %s (current version: %s)\r\n - ^5Please download the latest version from %s^7'):format(resource, localVersion, downloadUrl))
end

local function printPatchNotes(notesToPrint)
    print('^3Patch Notes:^7')
    for _, entry in ipairs(notesToPrint) do
        print(('^2Version %s:^7'):format(entry.version))
        for _, line in ipairs(entry.notes) do
            print((' - %s'):format(line))
        end
    end
end

local function validateRepoPath(repoPath)
    local username, reponame = repoPath:match("([^/]+)/([^/]+)")
    if not username or not reponame then return false, print('Invalid repository format. Expected format: username/reponame') end
    return true, username, reponame
end

local function getLocalVersion(resource)
    local localVersionRaw = GetResourceMetadata(resource, "version", 0)
    if not localVersionRaw then
        return nil, print('No version metadata found for resource "%s". Ensure fxmanifest.lua contains a valid version string.'):format(resource)
    end
    local version = parseVersion(localVersionRaw)
    if not version then return nil, print('Invalid version format for resource "%s". Expected format: "x.x.x"'):format(resource) end
    return version
end

local function processVersions(allVersions, localVersion)
    local notesToPrint = {}

    for versionStr, notes in pairs(allVersions) do
        if compareVersions(versionStr, localVersion) > 0 and type(notes) == "table" then
            table.insert(notesToPrint, { version = versionStr, notes = notes })
        end
    end

    table.sort(notesToPrint, function(a, b)
        return compareVersions(a.version, b.version) < 0
    end)

    return notesToPrint
end

local function fetchPatchNotes(branch, resource, repoPath, localVersion)
    local url = buildPatchNotesUrl(branch, repoPath)

    PerformHttpRequest(url, function(noteStatus, noteBody)
        if noteStatus == 200 then
            local patchData = json.decode(noteBody)
            if not patchData then return end

            local resourceData = patchData[resource]
            if resourceData and type(resourceData) == "table" then
                local actualRepoPath = resourceData.repo or resourceData.actualRepoPath
                local isTebex = not actualRepoPath -- If no repo path, it's Tebex
                local allVersions = resourceData.versions or resourceData -- Support both new and old format
                local notesToPrint = processVersions(allVersions, localVersion)

                if #notesToPrint > 0 then
                    local downloadUrl = getDownloadUrl(repoPath, isTebex, actualRepoPath) or url
                    printUpdateAvailable(resource, localVersion, downloadUrl)
                    printPatchNotes(notesToPrint)
                end
            end
        elseif branch == "main" then
            -- Fallback to master branch if main doesn't exist
            fetchPatchNotes("master", resource, repoPath, localVersion)
        end
    end, 'GET')
end

--- Pass a github username and repo name to check for the latest version of the resource.
--- Tebex is a optional boolean to determine if the message should be for a escrowed resource or not.
--- Example: Version.VersionChecker("TheOrderFivem/community_bridge", false)
--- @param repoPath string
--- @param tebex boolean | nil
--- @return nil
function Version.VersionChecker(repoPath, tebex)
    local username, reponame = repoPath:match("([^/]+)/([^/]+)")
    local resource = reponame and repoPath:match("([^/]+)$")
    if not username or not reponame or not resource then return print('^1Invalid repository format. Expected format: "username/reponame"^0') end

    local version = GetResourceMetadata(resource, "version", 0)
    if not version then return end

    version = version:match('%d+%.%d+%.%d+')
    if not version then return end

    PerformHttpRequest(('https://api.github.com/repos/%s/%s/releases/latest'):format(username, reponame),
        function(status, response)
            if status ~= 200 then return end
            local latest = json.decode(response).tag_name:match('%d+%.%d+%.%d+')
            if not latest or latest == version or version:gsub('%D', '') >= latest:gsub('%D', '') then return end

            local url = tebex and "https://portal.cfx.re/assets/granted-assets" or json.decode(response).html_url
            print(('^1An update is available for %s (current version: %s)\r\n - ^5Please download the latest version from %s^7'):format(resource, version, url))
        end,
    'GET')
end

--- Advanced version checker with patch notes support
--- Reads Tebex information and repo path directly from the resources.json file
--- @param repoPath string GitHub repository path for patch notes in format "username/reponame"
--- @param resourceName string The actual resource name to check
--- @return nil
function Version.AdvancedVersionChecker(repoPath, resourceName)
    local isValid, username, reponame = validateRepoPath(repoPath)
    if not isValid then return print(('^1[ERROR]^7 %s'):format(username)) end

    local resource = resourceName
    local localVersion, errorMsg = getLocalVersion(resource)
    if not localVersion then return print(('^1[ERROR]^7 %s'):format(username)) end
    fetchPatchNotes("main", resource, repoPath, localVersion)
end

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Version.AdvancedVersionChecker("MrNewb/patchnotes", resourceName)
end)

return Version