-- 读取指定文件内容
local function read_file(filename)
  local file, _ = io.open(filename, "r")
  if file ~= nil then -- err == nil 说明文件存在
    local res = file:read() -- 读取状态值
    file:close()
    return res
  end
  return nil
end

-- 执行命令并返回输出
-- @param cmd string 必须，命令内容
local function exec_cmd(cmd)
  -- popen到标准输出，因此需将标准错误输出重定向
  local f = io.popen(cmd .. " 2>&1")
  if f == nil then
    return nil
  end
  local res = f:read("*all")
  io.close(f)
  return res
end

-- 确保目录存在
local function ensure_mkdir(dir)
  local file = io.open(dir, "rb")
  if file then
    file:close()
  else
    -- 暂时仅支持安装linux utils的windows
    exec_cmd("mkdir -p " .. dir)
  end
end

-- os_name 当前操作系统的名称：win、wsl、linux
-- fs_separator 当前操作系统的文件分隔符
local os_name, fs_separator
if vim.fn.has("win32") == 1 then
  os_name = "win"
  fs_separator = "\\"
elseif vim.fn.has("wsl") == 1 then
  os_name = "wsl"
  fs_separator = "/"
else
  os_name = "linux"
  fs_separator = "/"
end

-- 缓存文件路径
local state_filename = vim.fn.stdpath("cache") .. fs_separator .. "im-switch" .. fs_separator .. "state" 

-- 自动切换fcitx5输入法
local function auto_switch_fcitx5(mode)
  if mode == "in" then -- 进入插入模式
    local state = read_file(state_filename) -- 读取状态值
    if state == "2" then -- 2说明退出前是active的，应该被重置
      exec_cmd("fcitx5-remote -o")
    end
  else
    -- 退出插入模式时将将当前状态记录下来，并切回不活跃
    ensure_mkdir(vim.fn.fnamemodify(state_filename, ":h"))
    exec_cmd("fcitx5-remote > " .. state_filename)
    exec_cmd("fcitx5-remote -c")
  end
end

-- 自动切换微软拼音输入法
local function auto_switch_micro_pinyin(mode)
  if mode == "in" then -- 进入插入模式
    local state = read_file(state_filename)
    if state == "zh" then -- zh说明退出前是中文的，应该被重置
      exec_cmd("im-switch-x64.exe zh")
    end
  else
    -- 退出插入模式时将将当前状态记录下来，并切回英文
    ensure_mkdir(vim.fn.fnamemodify(state_filename, ":h"))
    exec_cmd("im-switch-x64.exe en > " .. state_filename)
  end
end

-- wsl版本，使用cmd.exe会对性能有一定的影响
-- cmd.exe参考：https://www.cnblogs.com/baby123/p/11459316.html
local function auto_switch_micro_pinyin_wsl(mode)
  if mode == "in" then -- 进入插入模式
    local state = read_file(state_filename)
    if state == "zh" then -- zh说明退出前是中文的，应该被重置
      exec_cmd("cmd.exe /C \"im-switch-x64.exe zh")
    end
  else
    -- 退出插入模式时将将当前状态记录下来，并切回英文
    ensure_mkdir(vim.fn.fnamemodify(state_filename, ":h"))
    exec_cmd("cmd.exe /C im-switch-x64.exe en > " .. state_filename)
  end
end

-- 自动切换输入法
local function auto_switch_im(mode)
  if os_name == "win" then
    return auto_switch_micro_pinyin(mode)
  else
    if os_name == "wsl" then
      return auto_switch_micro_pinyin_wsl(mode)
    else
      return auto_switch_fcitx5(mode)
    end
  end
end

-- 在相应的时机自动进行函数调用
-- vim自动命令参考：http://yyq123.github.io/learn-vim/learn-vi-49-01-autocmd.html
-- 查看当前文档类型
-- :echo &filetype
-- :help api-autocmd
vim.api.nvim_create_augroup("user_im_switch", { clear = true })
vim.api.nvim_create_autocmd(
  { "InsertLeave" },
  { group = "user_im_switch", pattern = "*", callback = function()
    auto_switch_im("out")
  end}
)
vim.api.nvim_create_autocmd(
  { "InsertEnter" },
  -- 仅对指定类型的文件进行中文重置
  { group = "user_im_switch", pattern = "*", callback = function()
    local ft = vim.bo.filetype
    if ft == "markdown" then
      auto_switch_im("in")
    end
  end}
)
-- windows切换输入法成本较高，降低切换频率
if os_name ~= "win" then
  vim.api.nvim_create_autocmd(
    { "BufCreate" },
    { group = "user_im_switch", pattern = "*", callback = function() auto_switch_im("out") end }
  )
  vim.api.nvim_create_autocmd(
    { "BufEnter" },
    { group = "user_im_switch", pattern = "*", callback = function() auto_switch_im("out") end }
  )
  vim.api.nvim_create_autocmd(
    { "BufLeave" },
    { group = "user_im_switch", pattern = "*", callback = function() auto_switch_im("out") end }
  )
end
