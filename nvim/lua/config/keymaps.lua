vim.g.mapleader = " "
local map = vim.keymap.set

-- 缓存常用API以提高性能
local api = vim.api
local fn = vim.fn
local cmd = vim.cmd
local diagnostic = vim.diagnostic

map("i", "jk", "<ESC>")
map("v", "J", ":m '>+1<CR>gv=gv")
map("v", "K", ":m '<-2<CR>gv=gv")
map("n", "<leader>sv", "<C-w>v")
map("n", "<leader>sh", "<C-w>s")
map("n", "<leader>nh", "<cmd>nohl<CR>")

map({ "n", "i" }, "<F4>", "<cmd>write<CR>")
map("i", "o0", "<C-o>")
map("i", "<C-z>", "<C-o>u")
map("i", "<C-x>", "<C-o><C-r>")

-- 询问是否记录输出到文件的函数
local function ask_to_record_output(marker)
  -- 读取临时文件中存储的程序输出
  local tmp_file = string.format("/tmp/%s_program_output", marker)
  local file = io.open(tmp_file, "r")

  if not file then
    return
  end

  local output_content = file:read("*a")
  file:close()

  -- 删除临时文件
  os.remove(tmp_file)

  -- 如果输出为空，则直接返回
  if not output_content or #output_content == 0 then
    return
  end

  -- 询问用户是否记录
  vim.ui.input({ prompt = "Record it?[y/N] " }, function(answer)
    if answer and string.lower(answer) == "y" then
      -- 写入结果文件
      local record_file = fn.expand("~/mycode/terminal-record")

      -- 确保目录存在
      local dir = fn.fnamemodify(record_file, ":h")
      if fn.isdirectory(dir) == 0 then
        os.execute(string.format("mkdir -p '%s'", dir))
      end

      local record_file_handle = io.open(record_file, "w")
      if not record_file_handle then
        print("ERROR: Unable to open record file for writing")
        return
      end

      record_file_handle:write(output_content)
      record_file_handle:close()

      -- 计算并显示字符数量
      local char_count = #output_content
      print(string.format("The Size of output: %d", char_count))
    else
      print("Output not recorded")
    end
  end)
end

-- 新增函数：解析g++/gcc的错误和警告输出，生成location list items
local function parse_gcc_errors(compile_output, compile_dir)
  local items = {}
  -- 用于匹配g++/gcc错误和警告行的正则表达式
  -- 例如: t1.cpp:20:23: error: expected ';' before '}' token
  -- 例如: ./src/main.cpp:15:5: warning: unused variable 'x' [-Wunused-variable]
  local pattern = "([^:]+):(%d+):(%d+):%s*([^:]+):%s*(.+)"

  for _, line in ipairs(vim.split(compile_output, "\n")) do
    local filename, lnum_str, col_str, severity, message = line:match(pattern)

    if filename and lnum_str and col_str then
      -- 将字符串行号和列号转换为数字
      local lnum = tonumber(lnum_str)
      local col = tonumber(col_str)

      if lnum and col then
        -- 处理文件路径：如果是相对路径，则基于编译目录转换为绝对路径
        local full_path = filename
        if not filename:match("^/") then -- 不是绝对路径
          full_path = compile_dir .. "/" .. filename
        end

        -- 标准化路径，去除多余的 `./`
        full_path = vim.fn.fnamemodify(full_path, ":p")

        -- 尝试获取缓冲区编号
        local bufnr = vim.fn.bufadd(full_path)
        vim.fn.bufload(bufnr) -- 确保缓冲区已加载（但不显示）

        -- 确定错误类型 (E: error, W: warning, I: info, N: note)
        local typ = "E" -- 默认错误
        if severity:lower():match("warning") then
          typ = "W"
        elseif severity:lower():match("note") then
          typ = "I"
        end

        table.insert(items, {
          bufnr = bufnr,
          filename = full_path, -- 包含完整路径有助于诊断
          lnum = lnum,
          col = col,
          text = message,
          type = typ,
        })
      end
    end
  end

  return items
end

-- Compile and Run config
map({ "n", "i" }, "<F5>", function()
  local filename = fn.expand("%")
  if filename == "" then
    print("No file name")
    return
  end

  -- 检查文件扩展名
  local extension = fn.expand("%:e")
  local valid_extensions = { "cpp", "c", "cc", "cxx", "c++" }
  local is_cpp_file = false

  for _, ext in ipairs(valid_extensions) do
    if extension == ext then
      is_cpp_file = true
      break
    end
  end

  if not is_cpp_file then
    print("Not a C/C++ file, skipping compilation")
    return
  end

  -- 获取目录和文件名
  local file_dir = fn.expand("%:p:h")
  local file_base = fn.expand("%:t:r")
  local source_file = fn.expand("%:t")
  local executable_path = file_dir .. "/" .. file_base

  -- 检查是否需要重新编译的函数
  local function needs_recompilation()
    -- 检查可执行文件是否存在
    local executable_exists = fn.filereadable(executable_path) == 1

    if not executable_exists then
      print("Executable not found, needs compilation")
      return true
    end

    -- 获取源文件修改时间
    local source_mtime = fn.getftime(filename)

    -- 获取可执行文件修改时间
    local executable_mtime = fn.getftime(executable_path)

    if not source_mtime or not executable_mtime then
      print("Cannot get file timestamps, needs compilation")
      return true
    end

    -- 如果源文件比可执行文件新，需要重新编译
    if source_mtime > executable_mtime then
      print("Source file modified, needs recompilation")
      return true
    end

    -- 检查LSP错误
    local diagnostics = diagnostic.get(0)
    local has_errors = false
    for _, diag in ipairs(diagnostics) do
      if diag.severity == diagnostic.severity.ERROR then
        has_errors = true
        break
      end
    end

    if has_errors then
      print("LSP found errors, needs recompilation")
      return true
    end

    print("Using existing executable")
    return false
  end

  -- 编译函数
  local function compile()
    -- 保存文件
    cmd("write")

    -- 检查 LSP 错误
    local diagnostics = diagnostic.get(0)
    local errors = {}
    for _, diag in ipairs(diagnostics) do
      if diag.severity == diagnostic.severity.ERROR then
        table.insert(errors, diag)
      end
    end

    if #errors > 0 then
      print("LSP found " .. #errors .. " errors, stop compiling")
      diagnostic.goto_next({
        severity = diagnostic.severity.ERROR,
        wrap = false,
      })
      diagnostic.setloclist({ severity = diagnostic.severity.ERROR })
      cmd("lopen")
      return false
    end

    -- 编译命令
    local compile_cmd = string.format(
      -- 'cd "%s" && g++ -std=c++14 -Wall -Wextra -Wpedantic -o "%s" "%s" 2>&1',
      'cd "%s" && g++ -std=c++14 -o "%s" "%s" 2>&1',
      file_dir,
      file_base,
      source_file
    )

    local handle = io.popen(compile_cmd)
    if not handle then
      print("ERROR: Unable to compile")
      return false
    end

    local compile_output = handle:read("*a")
    handle:close()

    -- 检查编译是否成功
    local success = true
    if
      compile_output:match("error:")
      or compile_output:match("Error:")
      or compile_output:match("%d+ errors? generated")
    then
      success = false
    end

    if not success then
      print("Compilation failed!")
      -- 使用解析函数将编译输出转换为结构化的错误项
      local error_items = parse_gcc_errors(compile_output, file_dir)

      if #error_items > 0 then
        -- 成功解析到错误信息，将其显示在 location list 中
        fn.setloclist(0, {}, "r", {
          title = "Compilation Errors (" .. #error_items .. " items)",
          items = error_items,
        })
        cmd("lopen") -- 打开本地列表
        print("Found " .. #error_items .. " errors/warnings. Use :ll to jump.")
      else
        -- 如果没有解析到结构化的错误，则回退到旧模式（纯文本显示）
        print("Could not parse gcc errors, showing raw output.")
        fn.setloclist(0, {}, "r", {
          lines = vim.split(compile_output, "\n"),
          title = "Compilation Errors (raw output)",
        })
        cmd("lopen")
      end
      return false
    end

    print("Compilation successful")
    return true
  end

  -- 运行函数
  local function run_program()
    -- 保存原来的鼠标设置
    if not vim.g.terminal_original_mouse then
      vim.g.terminal_original_mouse = vim.o.mouse
    end
    vim.o.mouse = ""

    -- 清理之前可能存在的终端缓冲区
    local existing_bufnr = vim.g.running_terminal_bufnr
    if existing_bufnr and api.nvim_buf_is_valid(existing_bufnr) then
      -- 尝试彻底删除之前的终端缓冲区
      local win_id = fn.bufwinid(existing_bufnr)
      if win_id > 0 then
        api.nvim_win_close(win_id, true)
      end
      -- 使用 bdelete! 强制删除缓冲区
      pcall(cmd, "bwipeout! " .. existing_bufnr)
    end

    -- 创建一个唯一的标识符来标记程序输出开始
    local output_marker = string.format("OUTPUT_MARKER_%08X", math.random(0x10000000, 0xFFFFFFFF))

    -- 终端命令 - 在程序输出前添加标记，并添加询问是否记录的步骤
    local term_cmd = string.format(
      "cd \"%s\" && TERM=dumb bash -c \"./%s 2>&1 | tee /tmp/%s_program_output; echo ''; echo '========================='; echo '%s'; echo 'Press any key to continue...'; read -n 1\"",
      file_dir,
      file_base,
      output_marker,
      output_marker
    )

    -- 创建新终端
    cmd("botright 10split")
    cmd("terminal " .. term_cmd)
    local term_bufnr = fn.bufnr("%")
    vim.g.running_terminal_bufnr = term_bufnr

    -- 设置终端缓冲区名称
    api.nvim_buf_set_name(term_bufnr, "C++ Run Terminal")

    -- 自动进入插入模式
    cmd("startinsert")

    -- 设置终端缓冲区局部变量
    vim.b.has_exited = false
    vim.b.is_compile_run_terminal = true
    vim.b.output_marker = output_marker -- 保存标识符

    -- 退出终端的函数 - 改进版本
    local function exit_terminal_and_restore()
      if vim.b.has_exited then
        return
      end
      vim.b.has_exited = true

      -- 如果当前是终端模式，退出到普通模式
      if api.nvim_get_mode().mode:find("t") then
        api.nvim_feedkeys(api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", true)
      end

      vim.defer_fn(function()
        -- 恢复鼠标设置
        if vim.g.terminal_original_mouse then
          vim.o.mouse = vim.g.terminal_original_mouse
          vim.g.terminal_original_mouse = nil
        end

        -- 先关闭窗口
        local win_id = fn.bufwinid(term_bufnr)
        if win_id > 0 then
          api.nvim_win_close(win_id, true)
        end

        -- 等待窗口关闭完成
        vim.defer_fn(function()
          ask_to_record_output(output_marker)

          -- 强制删除缓冲区
          if api.nvim_buf_is_valid(term_bufnr) then
            -- 使用 bwipeout 彻底删除缓冲区，包括所有选项和变量
            local ok, _ = pcall(cmd, "bwipeout! " .. term_bufnr)
            if not ok then
              -- 如果 bwipeout 失败，尝试 bdelete
              pcall(cmd, "bdelete! " .. term_bufnr)
            end
          end

          -- 清理全局变量
          if vim.g.running_terminal_bufnr == term_bufnr then
            vim.g.running_terminal_bufnr = nil
          end
        end, 100)
      end, 50)
    end

    -- 设置终端缓冲区的按键映射
    map("t", "<C-q>", exit_terminal_and_restore, { buffer = term_bufnr, desc = "Exit terminal and restore mouse" })

    -- 定义 TermClose 回调函数
    local function on_term_close()
      if not vim.b.has_exited then
        exit_terminal_and_restore()
      end
    end

    -- 监听终端关闭事件
    api.nvim_create_autocmd("TermClose", {
      buffer = term_bufnr,
      once = true,
      callback = on_term_close,
    })

    -- 定义 BufLeave 回调函数
    local function on_buf_leave()
      -- 只有在缓冲区仍然存在时才清理
      if api.nvim_buf_is_valid(term_bufnr) then
        -- 检查是否有人正在使用这个缓冲区
        local win_count = 0
        for _, win in ipairs(api.nvim_list_wins()) do
          if api.nvim_win_get_buf(win) == term_bufnr then
            win_count = win_count + 1
          end
        end

        if win_count == 0 then
          exit_terminal_and_restore()
        end
      end
    end

    -- 当切换到其他缓冲区时自动清理
    api.nvim_create_autocmd("BufLeave", {
      buffer = term_bufnr,
      once = true,
      callback = on_buf_leave,
    })
  end

  -- 主逻辑：判断是否需要编译，然后运行
  if needs_recompilation() then
    if compile() then
      run_program()
    end
  else
    run_program()
  end
end, { desc = "Compile and run c++ program" })

-- 清理所有编译运行终端缓冲区的函数
local function cleanup_compile_terminals()
  for _, bufnr in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_valid(bufnr) then
      local success, buf_vars = pcall(api.nvim_buf_get_var, bufnr, "is_compile_run_terminal")
      if success and buf_vars then
        local win_id = fn.bufwinid(bufnr)
        if win_id > 0 then
          api.nvim_win_close(win_id, true)
        end
        pcall(cmd, "bwipeout! " .. bufnr)
      end
    end
  end
  vim.g.running_terminal_bufnr = nil
end

-- 可以添加一个命令来清理所有终端缓冲区
api.nvim_create_user_command("CleanupCompileTerminals", cleanup_compile_terminals, {})

-- 定义 TermOpen 回调函数
local function on_term_open()
  -- 设置缓冲区变量，以便识别我们的编译运行终端
  vim.b.is_compile_run_terminal = true

  -- 只在我们创建的终端中禁用鼠标
  if vim.g.running_terminal_bufnr and fn.bufnr("%") == vim.g.running_terminal_bufnr then
    if not vim.g.terminal_original_mouse then
      vim.g.terminal_original_mouse = vim.o.mouse
    end
    vim.o.mouse = ""
  end
end

-- 改进的 TermOpen 自动命令
api.nvim_create_autocmd("TermOpen", {
  pattern = "*",
  callback = on_term_open,
})

-- 在 Neovim 退出时清理终端缓冲区
api.nvim_create_autocmd("VimLeavePre", {
  callback = cleanup_compile_terminals,
})

-- 自定义排序诊断信息并显示在位置列表中
local function show_sorted_diagnostics()
  local diagnostics = vim.diagnostic.get(0)
  table.sort(diagnostics, function(a, b)
    if a.severity ~= b.severity then
      return a.severity < b.severity
    end
    if a.lnum ~= b.lnum then
      return a.lnum < b.lnum
    end
    return a.col < b.col
  end)
  local items = {}
  local severity_to_type = {
    [vim.diagnostic.severity.ERROR] = "E",
    [vim.diagnostic.severity.WARN] = "W",
    [vim.diagnostic.severity.INFO] = "I",
    [vim.diagnostic.severity.HINT] = "H",
  }
  for _, diag in ipairs(diagnostics) do
    table.insert(items, {
      bufnr = diag.bufnr or 0,
      lnum = diag.lnum + 1,
      col = diag.col + 1,
      text = diag.message,
      type = severity_to_type[diag.severity] or " ",
    })
  end
  vim.fn.setloclist(0, {}, "r", { title = "Show sorted information", items = items })
  vim.cmd("lopen")
end

map("n", "<leader>q", show_sorted_diagnostics, { desc = "Show sorted diagnostics in location" })

-- 定义 FileType 回调函数
local function on_qf_filetype()
  map("n", "q", ":lclose<CR>", { buffer = true, nowait = true })
end

api.nvim_create_autocmd("FileType", {
  pattern = "qf",
  callback = on_qf_filetype,
})
