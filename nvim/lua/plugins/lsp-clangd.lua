return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        clangd = {
          -- 关键：指定使用系统 clangd
          cmd = { "/usr/bin/clangd" },
          -- 禁用 mason 自动管理
          mason = false,
          -- 其他配置
          settings = {
            clangd = {
              capabilities = {
                offsetEncoding = { "utf-16" },
              },
              cmd = {
                "clangd",
                "--background-index",
                "--clang-tidy",
                "--header-insertion=iwyu",
                "--completion-style=detailed",
                "--function-arg-placeholders",
                "--fallback-style=llvm",
              },
            },
          },
        },
      },
    },
  },
}
