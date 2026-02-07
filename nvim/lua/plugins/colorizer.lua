return {
  "norcalli/nvim-colorizer.lua",
  event = { "BufReadPost", "BufNewFile" },
  opts = {
    filetypes = { "*" }, -- 建议按需设置，例如 {'css', 'javascript', 'html'}
    user_default_options = {
      RGB = true, -- #RGB
      RRGGBB = true, -- #RRGGBB
      RRGGBBAA = true, -- #RRGGBBAA (带透明度)
      rgb_fn = true, -- CSS rgb() 函数
      hsl_fn = true, -- CSS hsl() 函数
      css = true, -- 启用所有 CSS 颜色功能
      css_fn = true, -- 启用 CSS 函数
      mode = "foreground", -- 关键设置：显示模式为虚拟文本
    },
    -- 对所有缓冲区启用（按 filetypes 过滤）
    bufnr = nil,
  },
}
