-- ~/.config/nvim/lua/plugins/cmp.lua
return {
  "hrsh7th/nvim-cmp",
  enabled = true,
  event = "InsertEnter", -- 在插入模式时加载
  dependencies = {
    -- 补全源
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-path", -- 文件路径
    "hrsh7th/cmp-buffer", -- 缓冲区单词
    "hrsh7th/cmp-cmdline", -- 命令行补全
    "hrsh7th/cmp-emoji",
    -- 代码片段引擎
    "saadparwaiz1/cmp_luasnip", -- nvim-cmp 与 luasnip 的适配器
    "L3MON4D3/LuaSnip", -- 片段引擎本身
    "rafamadriz/friendly-snippets", -- 预设片段库
  },
  config = function()
    local cmp = require("cmp")
    local luasnip = require("luasnip")

    -- 加载友好代码片段库
    require("luasnip.loaders.from_vscode").lazy_load()

    -- 检查是否可安全跳转的回调函数
    local check_backspace = function()
      local col = vim.fn.col(".") - 1
      return col == 0 or vim.fn.getline("."):sub(col, col):match("%s")
    end

    -- 设置边框高亮（根据你之前的配置）
    vim.cmd([[
      highlight CmpCompletionBorder guifg=#777799 guibg=NONE
      highlight CmpDocumentationBorder guifg=#777799 guibg=NONE
    ]])

    cmp.setup({
      snippet = {
        expand = function(args)
          luasnip.lsp_expand(args.body)
        end,
      },
      mapping = cmp.mapping.preset.insert({
        ["<C-k>"] = cmp.mapping.select_prev_item(),
        ["<C-j>"] = cmp.mapping.select_next_item(),
        ["<C-b>"] = cmp.mapping(cmp.mapping.scroll_docs(-1), { "i", "c" }),
        ["<C-f>"] = cmp.mapping(cmp.mapping.scroll_docs(1), { "i", "c" }),
        ["<C-Space>"] = cmp.mapping(cmp.mapping.complete(), { "i", "c" }),
        ["<C-e>"] = cmp.mapping({
          i = cmp.mapping.abort(),
          c = cmp.mapping.close(),
        }),
        -- 确认选择：特别处理仅包含空格的条目
        ["<CR>"] = cmp.mapping.confirm({
          select = true,
          behavior = cmp.ConfirmBehavior.Replace,
        }),
        -- 你熟悉的复杂 Tab 键映射
        ["<Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_next_item()
          elseif luasnip.expandable() then
            luasnip.expand()
          elseif luasnip.expand_or_jumpable() then
            luasnip.expand_or_jump()
          elseif check_backspace() then
            fallback()
          else
            fallback()
          end
        end, { "i", "s" }),
        ["<S-Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_prev_item()
          elseif luasnip.jumpable(-1) then
            luasnip.jump(-1)
          else
            fallback()
          end
        end, { "i", "s" }),
      }),
      sources = cmp.config.sources({
        { name = "nvim_lsp" },
        { name = "luasnip" },
        { name = "path" },
      }, {
        { name = "buffer" },
      }),
      -- 窗口和边框设置（根据你之前的配置）
      window = {
        completion = cmp.config.window.bordered({
          border = "double",
          winhighlight = "Normal:Pmenu,FloatBorder:CmpCompletionBorder,CursorLine:PmenuSel,Search:None",
        }),
        documentation = cmp.config.window.bordered({
          border = "double",
          winhighlight = "Normal:Pmenu,FloatBorder:CmpDocumentationBorder,CursorLine:PmenuSel,Search:None",
        }),
      },
      -- 其他优化设置
      formatting = {
        fields = { "kind", "abbr", "menu" },
      },
    })

    -- 为 `/` 和 `:` 启用命令行补全（可选）
    cmp.setup.cmdline({ "/", "?" }, {
      mapping = cmp.mapping.preset.cmdline(),
      sources = {
        { name = "buffer" },
      },
    })
    cmp.setup.cmdline(":", {
      mapping = cmp.mapping.preset.cmdline(),
      sources = cmp.config.sources({
        { name = "path" },
      }, {
        { name = "cmdline" },
      }),
    })
  end,
}
