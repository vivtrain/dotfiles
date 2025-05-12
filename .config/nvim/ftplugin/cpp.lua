local map = vim.keymap.set

map("n", "<leader>s", "<cmd> ClangdSwitchSourceHeader <cr>", { desc = "CPP Switch between source and header file" })

