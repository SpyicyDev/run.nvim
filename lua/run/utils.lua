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
    local callbacks = {}
    local shell_commands = {}
    local chain_env = {}

    -- Extract callbacks and chain-wide env
    for i = #commands, 1, -1 do
        local cmd = commands[i]
        if type(cmd) == "table" then
            if cmd.on_success then
                callbacks.on_success = cmd.on_success
                table.remove(commands, i)
            elseif cmd.on_error then
                callbacks.on_error = cmd.on_error
                table.remove(commands, i)
            elseif cmd.env then
                -- Process chain-wide env
                chain_env = M.resolve_env_value(cmd.env)
                table.remove(commands, i)
            end
        end
    end

    -- Process each command
    for _, cmd in ipairs(commands) do
        -- Skip if condition not met
        if type(cmd) == "table" and cmd.when and not cmd.when() then
            goto continue
        end

        -- Handle wait conditions
        if type(cmd) == "table" and cmd.wait_for then
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

        -- Process the command
        local cmd_str
        if type(cmd) == "string" then
            cmd_str = cmd
        elseif type(cmd) == "table" and cmd.cmd then
            if type(cmd.cmd) == "function" then
                local success, result = pcall(cmd.cmd)
                if not success then
                    if callbacks.on_error then
                        callbacks.on_error("Error in function: " .. tostring(result))
                    end
                    if not cmd.continue_on_error then
                        return false
                    end
                    goto continue
                end
                cmd_str = result
            else
                cmd_str = cmd.cmd
            end
        elseif type(cmd) == "function" then
            local success, result = pcall(cmd)
            if not success then
                if callbacks.on_error then
                    callbacks.on_error("Error in function: " .. tostring(result))
                end
                goto continue
            end
            cmd_str = result
        end

        if cmd_str then
            -- Handle vim commands separately
            if cmd_str:sub(1, 1) == ":" then
                local success, err = pcall(vim.cmd, cmd_str:sub(2))
                if not success then
                    if callbacks.on_error then
                        callbacks.on_error("Error in vim command: " .. tostring(err))
                    end
                    if not (type(cmd) == "table" and cmd.continue_on_error) then
                        return false
                    end
                end
            else
                -- Format the command with error handling
                local error_check = type(cmd) == "table" and cmd.continue_on_error and "|| true" or ""
                cmd_str = M.fmt_cmd(cmd_str)
                if cmd_str then
                    table.insert(shell_commands, cmd_str .. " " .. error_check)
                end
            end
        end

        ::continue::
    end

    -- If we have shell commands, run them in a single terminal
    if #shell_commands > 0 then
        local term = require("FTerm")
        if not term then
            vim.notify("FTerm not found. Make sure it's installed", vim.log.levels.ERROR, {
                title = "run.nvim"
            })
            return false
        end

        local combined_cmd = table.concat(shell_commands, " && ")
        term.scratch({ 
            cmd = combined_cmd,
            env = chain_env  -- Pass environment directly to FTerm
        })
    end

    if callbacks.on_success then
        callbacks.on_success()
    end

    return true
end

-- Helper function to resolve environment values
M.resolve_env_value = function(env_config)
    local resolved = {}
    
    for k, v in pairs(env_config) do
        local value
        if type(v) == "function" then
            value = v()
        elseif type(v) == "table" then
            if v.prompt then
                if v.type == "secret" then
                    value = vim.fn.inputsecret(v.prompt .. ": ")
                else
                    value = vim.fn.input(v.prompt .. ": ")
                end
            elseif v.when then
                if v.when() then
                    value = v.value
                end
            else
                value = v.value
            end
        else
            value = v
        end
        
        if value ~= nil then
            resolved[k] = tostring(value)
        end
    end
    
    return resolved
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
