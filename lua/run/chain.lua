local M = {}

local utils = require("run.utils")

-- Execute a single command in the chain
local function execute_single(cmd_config)
    if type(cmd_config) == "string" then
        return utils.run_cmd(cmd_config)
    end

    -- Check conditions
    if cmd_config.when and not cmd_config.when() then
        return true -- Skip but don't count as failure
    end

    -- Execute with environment if specified
    local success = utils.run_cmd(cmd_config.cmd, cmd_config.env)

    -- Handle wait_for condition
    if success and cmd_config.wait_for then
        local timeout = cmd_config.timeout or 30
        local start_time = vim.loop.now()
        while true do
            if cmd_config.wait_for() then
                break
            end
            if (vim.loop.now() - start_time) / 1000 > timeout then
                vim.notify("Timeout waiting for condition", vim.log.levels.ERROR)
                return false
            end
            vim.cmd("sleep 500m") -- Wait 500ms between checks
        end
    end

    return success
end

-- Execute commands in sequence
function M.run_sequence(sequence, options)
    options = options or {}
    local failed_cmd = nil

    for _, cmd in ipairs(sequence) do
        local success = execute_single(cmd)
        if not success and not (cmd.continue_on_error or options.continue_on_error) then
            failed_cmd = type(cmd) == "string" and cmd or cmd.cmd
            break
        end
    end

    -- Handle cleanup commands marked as always_run
    for _, cmd in ipairs(sequence) do
        if type(cmd) == "table" and cmd.always_run and not execute_single(cmd) then
            vim.notify("Cleanup command failed: " .. cmd.cmd, vim.log.levels.WARN)
        end
    end

    if failed_cmd then
        if options.on_error then
            options.on_error(failed_cmd)
        end
        return false
    end

    if options.on_success then
        options.on_success()
    end
    return true
end

-- Execute commands in parallel
function M.run_parallel(commands, options)
    options = options or {}
    local jobs = {}
    local failed = false

    -- Start all commands
    for _, cmd in ipairs(commands) do
        local cmd_str = type(cmd) == "string" and cmd or cmd.cmd
        local term = require("FTerm")
        
        -- Configure terminal if specified
        local term_opts = {}
        if type(cmd) == "table" and cmd.terminal then
            term_opts = vim.tbl_extend("force", term_opts, cmd.terminal)
        end

        -- Create new terminal instance
        local term_instance = term:new(term_opts)
        term_instance:run(cmd_str)
        
        table.insert(jobs, term_instance)
    end

    -- Note: In a real terminal multiplexer implementation,
    -- we would track job completion and handle cleanup
    return true
end

-- Main entry point for command chain execution
function M.execute(cmd_config)
    if not cmd_config then return false end

    -- Handle sequence
    if cmd_config.sequence then
        return M.run_sequence(cmd_config.sequence, {
            on_success = cmd_config.on_success,
            on_error = cmd_config.on_error,
            continue_on_error = cmd_config.continue_on_error
        })
    end

    -- Handle parallel
    if cmd_config.parallel then
        return M.run_parallel(cmd_config.parallel, {
            on_success = cmd_config.on_success,
            on_error = cmd_config.on_error
        })
    end

    -- Handle single command
    return execute_single(cmd_config)
end

return M
