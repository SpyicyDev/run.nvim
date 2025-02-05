local M = {}

local config = require("run.config")
local env = require("run.env")

-- Common notification wrapper
local notify = function(msg, level)
    vim.notify(msg, level or vim.log.levels.INFO, { title = "run.nvim" })
end

-- Validate command input
local validate_cmd = function(cmd)
    if not cmd then
        notify("Command is nil", vim.log.levels.ERROR)
        return false
    end
    if type(cmd) ~= "string" then
        notify("Command must be a string", vim.log.levels.ERROR)
        return false
    end
    return true
end

-- Process file path substitutions
M.fmt_cmd = function(cmd)
    if not validate_cmd(cmd) then return nil end

    if string.find(cmd, "%%f") then
        local buf_name = vim.api.nvim_buf_get_name(0)
        if not buf_name or buf_name == "" then
            notify("No buffer name available for %f substitution", vim.log.levels.ERROR)
            return nil
        end
        return string.gsub(cmd, "%%f", buf_name)
    end
    return cmd
end

-- Execute a single command
local execute_single_cmd = function(cmd, env_vars)
    if cmd:sub(1, 1) == ":" then
        local success, err = pcall(vim.cmd, cmd:sub(2))
        if not success then
            notify("Error executing vim command: " .. tostring(err), vim.log.levels.ERROR)
            return false
        end
        return true
    end

    local term = require("FTerm")
    if not term then
        notify("FTerm not found. Make sure it's installed", vim.log.levels.ERROR)
        return false
    end
    
    term.scratch({ cmd = cmd, env = env_vars })
    return true
end

-- Process command section and execute
M.run_cmd = function(cmd_section)
    if not cmd_section then
        notify("Command section is nil", vim.log.levels.ERROR)
        return false
    end

    if not config.proj or not config.proj[cmd_section] then
        notify("Command section not found in project configuration", vim.log.levels.ERROR)
        return false
    end

    local cmd_config = config.proj[cmd_section]
    local cmd = cmd_config.cmd

    -- Handle command chains
    if type(cmd) == "table" and #cmd > 0 then
        return M.run_command_chain(cmd, cmd_section)
    end

    -- Handle function commands
    if type(cmd) == "function" then
        local success, result = pcall(cmd)
        if not success then
            notify("Error executing command function: " .. tostring(result), vim.log.levels.ERROR)
            return false
        end
        cmd = result
        if cmd == nil then return true end
    end

    cmd = M.fmt_cmd(cmd)
    if not cmd or not validate_cmd(cmd) then return false end

    local processed_env = env.process_env(cmd_config.env)
    return execute_single_cmd(cmd, processed_env)
end

-- Improved command chain execution
M.run_command_chain = function(commands, cmd_section)
    local callbacks = {}
    local shell_commands = {}

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
                notify("Timeout waiting for condition", vim.log.levels.ERROR)
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
            notify("FTerm not found. Make sure it's installed", vim.log.levels.ERROR)
            return false
        end

        local combined_cmd = table.concat(shell_commands, " && ")
        -- Process environment variables from the command section
        local processed_env = env.process_env(config.proj[cmd_section] and config.proj[cmd_section].env)
        
        term.scratch({ 
            cmd = combined_cmd,
            env = processed_env
        })
    end

    if callbacks.on_success then
        callbacks.on_success()
    end

    return true
end

-- write config.proj to run.nvim.lua
function M.write_conf()
    local proj_file = vim.fn.findfile("run.nvim.lua", ".;")
    if not proj_file or proj_file == "" then
        notify("Could not find run.nvim.lua file", vim.log.levels.ERROR)
        return
    end

    local file = io.open(proj_file, "w")
    if not file then
        notify("Could not open run.nvim.lua for writing", vim.log.levels.ERROR)
        return
    end

    if not config.proj then
        notify("Project configuration is nil", vim.log.levels.ERROR)
        file:close()
        return
    end

    local inspect = require("inspect")
    if not inspect then
        notify("Could not load inspect module", vim.log.levels.ERROR)
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
        notify("Error writing configuration: " .. tostring(err), vim.log.levels.ERROR)
    end
end

return M
