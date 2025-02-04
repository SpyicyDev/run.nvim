local M = {}

local config = require("run.config")

-- do any preprocessing to the cmd string
M.fmt_cmd = function(cmd)
    if not cmd then
        vim.notify("Command string is nil", vim.log.levels.ERROR, {
            title = "run.nvim"
        })
        return nil
    end

    if type(cmd) ~= "string" then
        vim.notify("Command must be a string", vim.log.levels.ERROR, {
            title = "run.nvim"
        })
        return nil
    end

    if string.find(cmd, "%%f") then
        local buf_name = vim.api.nvim_buf_get_name(0)
        if not buf_name or buf_name == "" then
            vim.notify("No buffer name available for %f substitution", vim.log.levels.ERROR, {
                title = "run.nvim"
            })
            return nil
        end
        cmd = string.gsub(cmd, "%%f", buf_name)
    end

    return cmd
end

-- run a cmd, either in term, vim command, or a lua function that optionally returns one of those
M.run_cmd = function(cmd)
    if not cmd then
        vim.notify("Command is nil", vim.log.levels.ERROR, {
            title = "run.nvim"
        })
        return false
    end

    -- Handle command chains
    if type(cmd) == "table" and #cmd > 0 then
        return M.run_command_chain(cmd)
    end

    -- Handle complex single command
    if type(cmd) == "table" and cmd.cmd then
        -- Check conditions
        if cmd.when and not cmd.when() then
            return true -- Skip but don't count as error
        end

        -- Handle wait conditions
        if cmd.wait_for then
            local start_time = vim.loop.now()
            local timeout = (cmd.timeout or 30) * 1000 -- Convert to ms
            
            while vim.loop.now() - start_time < timeout do
                if cmd.wait_for() then
                    break
                end
                vim.loop.sleep(1000) -- Check every second
            end
            
            if vim.loop.now() - start_time >= timeout then
                vim.notify("Timeout waiting for condition", vim.log.levels.ERROR, {
                    title = "run.nvim"
                })
                return false
            end
        end

        -- Set command environment if specified
        local old_env = {}
        if cmd.env then
            for k, v in pairs(cmd.env) do
                old_env[k] = vim.env[k]
                vim.env[k] = v
            end
        end

        local success = M.run_cmd(cmd.cmd)

        -- Restore environment
        if cmd.env then
            for k, v in pairs(old_env) do
                vim.env[k] = v
            end
        end

        return success
    end

    if type(cmd) == "function" then
        local success, result = pcall(cmd)
        if not success then
            vim.notify("Error executing command function: " .. tostring(result), vim.log.levels.ERROR, {
                title = "run.nvim"
            })
            return false
        end
        cmd = result
        if cmd == nil then
            return true
        end
    end

    cmd = M.fmt_cmd(cmd)
    if not cmd then
        return false
    end

    if type(cmd) ~= "string" then
        vim.notify("Command must be a string", vim.log.levels.ERROR, {
            title = "run.nvim"
        })
        return false
    end

    if cmd:sub(1, 1) == ":" then
        local success, err = pcall(vim.cmd, cmd:sub(2))
        if not success then
            vim.notify("Error executing vim command: " .. tostring(err), vim.log.levels.ERROR, {
                title = "run.nvim"
            })
            return false
        end
        return true
    end

    local term = require("FTerm")
    if not term then
        vim.notify("FTerm not found. Make sure it's installed", vim.log.levels.ERROR, {
            title = "run.nvim"
        })
        return false
    end
    
    term.scratch({ cmd = cmd })
    return true
end

-- Handle a chain of commands
M.run_command_chain = function(commands)
    local success = true
    local callbacks = {}

    -- Extract callbacks if they exist
    for i = #commands, 1, -1 do
        local cmd = commands[i]
        if type(cmd) == "table" then
            if cmd.on_success then
                callbacks.on_success = cmd.on_success
                table.remove(commands, i)
            elseif cmd.on_error then
                callbacks.on_error = cmd.on_error
                table.remove(commands, i)
            end
        end
    end

    -- Run each command in sequence
    for _, cmd in ipairs(commands) do
        local cmd_success = M.run_cmd(cmd)
        
        if not cmd_success then
            success = false
            if type(cmd) == "table" then
                if callbacks.on_error then
                    callbacks.on_error(cmd.cmd or cmd)
                end
            else
                if callbacks.on_error then
                    callbacks.on_error(cmd)
                end
            end
            
            -- Check if we should continue
            if not (type(cmd) == "table" and cmd.continue_on_error) then
                break
            end
        end

        -- Handle always_run commands even if previous failed
        if not success and type(cmd) == "table" and not cmd.always_run then
            goto continue
        end

        ::continue::
    end

    if success and callbacks.on_success then
        callbacks.on_success()
    end

    return success
end

-- write config.proj to run.nvim.lua
function M.write_conf()
    local proj_file = vim.fn.findfile("run.nvim.lua", ".;")
    if not proj_file or proj_file == "" then
        vim.notify("Could not find run.nvim.lua file", vim.log.levels.ERROR, {
            title = "run.nvim"
        })
        return
    end

    local file = io.open(proj_file, "w")
    if not file then
        vim.notify("Could not open run.nvim.lua for writing", vim.log.levels.ERROR, {
            title = "run.nvim"
        })
        return
    end

    if not config.proj then
        vim.notify("Project configuration is nil", vim.log.levels.ERROR, {
            title = "run.nvim"
        })
        file:close()
        return
    end

    local inspect = require("inspect")
    if not inspect then
        vim.notify("Could not load inspect module", vim.log.levels.ERROR, {
            title = "run.nvim"
        })
        file:close()
        return
    end

    local conf_string = inspect.inspect(config.proj)
    conf_string = "return " .. conf_string

    local success, err = pcall(function()
        file:write(conf_string)
        file:close()
    end)

    if not success then
        vim.notify("Error writing configuration: " .. tostring(err), vim.log.levels.ERROR, {
            title = "run.nvim"
        })
    end
end

return M
