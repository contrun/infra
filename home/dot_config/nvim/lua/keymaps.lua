local Utils = require('utils')

-- local exprnnoremap = Utils.exprnnoremap
local nnoremap = Utils.nnoremap
local vnoremap = Utils.vnoremap
-- local xnoremap = Utils.xnoremap
local inoremap = Utils.inoremap
-- local tnoremap = Utils.tnoremap
-- local nmap = Utils.nmap
-- local xmap = Utils.xmap

vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- kj to normal mode
inoremap("kj", "<Esc>")

-- Run omnifunc, mostly used for autocomplete
inoremap("<C-SPACE>", "<C-x><C-o>")

-- Save with Ctrl + S
nnoremap("<C-s>", "<Cmd>w<CR>")

-- Close buffer
nnoremap("<A-z>", "<Cmd>q<CR>")

nnoremap("[b", "<Cmd>bprevious<CR>")
nnoremap("]b", "<Cmd>bnext<CR>")

nnoremap("<C-[>", "<Cmd>bprevious<CR>")
nnoremap("<C-]>", "<Cmd>bnext<CR>")

-- Delete buffer
nnoremap("<A-w>", "<Cmd>bd<CR>")
nnoremap("<C-w>d", "<Cmd>bd<CR>")
nnoremap("<C-w><C-d>", "<Cmd>bd<CR>")

-- Yank to end of line
nnoremap("Y", "y$")

-- Copy to system clippboard
nnoremap("<leader>y", '"+y')
vnoremap("<leader>y", '"+y')

-- Paste from system clippboard
nnoremap("<leader>p", '"+p')
vnoremap("<leader>p", '"+p')

-- tmux
nnoremap("<C-SPACE>h", [[<Cmd>lua require("tmux").move_left()<CR>]])
nnoremap("<C-SPACE>j", [[<Cmd>lua require("tmux").move_bottom()<CR>]])
nnoremap("<C-SPACE>k", [[<Cmd>lua require("tmux").move_top()<CR>]])
nnoremap("<C-SPACE>l", [[<Cmd>lua require("tmux").move_right()<CR>]])

nnoremap("<C-SPACE>H", [[<Cmd>lua require("tmux").resize_left()<CR>]])
nnoremap("<C-SPACE>J", [[<Cmd>lua require("tmux").resize_bottom()<CR>]])
nnoremap("<C-SPACE>K", [[<Cmd>lua require("tmux").resize_top()<CR>]])
nnoremap("<C-SPACE>L", [[<Cmd>lua require("tmux").resize_right()<CR>]])

-- Local list
nnoremap("<leader>ll", "<Cmd>lopen<CR>")
nnoremap("<leader>lc", "<Cmd>lclose<CR>")
nnoremap("<leader>ln", "<Cmd>lnext<CR>")
nnoremap("<leader>lp", "<Cmd>lprev<CR>")

-- Quickfix list
nnoremap("<leader>qq", "<Cmd>TroubleToggle<CR>")
nnoremap("<leader>qw", "<Cmd>TroubleToggle lsp_workspace_diagnostics<CR>")
nnoremap("<leader>qd", "<Cmd>TroubleToggle lsp_document_diagnostics<CR>")
nnoremap("<leader>qf", "<Cmd>TroubleToggle quickfix<CR>")
nnoremap("<leader>ql", "<Cmd>TroubleToggle loclist<CR>")
nnoremap("<leader>qr", "<Cmd>TroubleToggle lsp_references<CR>")
nnoremap("<leader>qo", "<Cmd>copen<CR>")
nnoremap("<leader>qc", "<Cmd>cclose<CR>")
nnoremap("<leader>qn", "<Cmd>cnext<CR>")
nnoremap("<leader>qp", "<Cmd>cprev<CR>")

nnoremap("<leader>lv", "<Cmd>Vista<CR>")

nnoremap("<leader>xo", "<Cmd> !xdg-open %<CR><CR>")
nnoremap("<leader>xr", "<Cmd>source $MYVIMRC<CR>")
nnoremap("<leader>xs", "<Cmd>SmallScreenModeToggle<CR>")
nnoremap("<leader>xc",
  "<Cmd>silent !make -C ~/.local/share/chezmoi home-install<CR>")
nnoremap("<leader>xp",
  "<Cmd>silent !make -C ~/.local/share/chezmoi home-install<CR><Cmd>PackerSync<CR>")
nnoremap("<leader>xP", "<Cmd>PackerSync<CR>")

nnoremap("<leader>gg", "<Cmd>Neogit<CR>")
nnoremap("<leader>gf", "<Cmd>lua require('telescope').extensions.chezmoi.find_files()<CR>")

-- Show line diagnostics
nnoremap("<leader>d",
  '<Cmd>lua vim.diagnostic.open_float(0, {scope = "line"})<CR>')

-- Open local diagnostics in local list
nnoremap("<leader>D", "<Cmd>lua vim.diagnostic.setloclist()<CR>")

-- Open all project diagnostics in quickfix list
nnoremap("<leader><A-d>", "<Cmd>lua vim.diagnostic.setqflist()<CR>")

-- Telescope
nnoremap("<leader>f", "<Cmd>Telescope find_files<CR>")
nnoremap("<leader>o", "<Cmd>Telescope oldfiles<CR>")
nnoremap("<leader>b", "<Cmd>Telescope buffers<CR>")
nnoremap("<leader>/", "<Cmd>Telescope live_grep<CR>")

nnoremap("<leader>e", "<Cmd>:Findr %:p:h<CR>")

nnoremap("<leader>=", "<Cmd>Neoformat<CR>")

-- EasyAlign
vnoremap("ga", "<Cmd>EasyAlign<CR>")
nnoremap("ga", "<Cmd>EasyAlign<CR>")

nnoremap("<leader>ss", "<Cmd>ISwap<CR>")

-- dap
nnoremap("<leader>dd", "<Cmd>lua require('dapui').toggle()<CR>")
nnoremap("<leader>dv", "<Cmd>DapVirtualTextToggle<CR>")
vnoremap("<leader>de", "<Cmd>lua require('dapui').eval()<CR>")
nnoremap("<leader>de",
  "<Cmd>lua require('dapui').eval(vim.fn.input '[Expression] > ')<CR>")
nnoremap("<leader>dc", "<Cmd>lua require'dap'.continue()<CR>")
nnoremap("<leader>dso", "<Cmd>lua require'dap'.step_over()<CR>")
nnoremap("<leader>dsi", "<Cmd>lua require'dap'.step_into()<CR>")
nnoremap("<leader>dst", "<Cmd>lua require'dap'.step_out()<CR>")
nnoremap("<leader>db", "<Cmd>lua require'dap'.toggle_breakpoint()<CR>")
nnoremap("<leader>dB",
  "<Cmd>lua require'dap'.toggle_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>")
nnoremap("<leader>dl",
  "<Cmd>lua require'dap'.set_breakpoint(nil, nil, vim.fn.input('Log point message: '))<CR>")
nnoremap("<leader>dr", "<Cmd>lua require'dap'.repl.toggle()<CR>")
nnoremap("<leader>dR", "<Cmd>lua require'dap'.run_last()<CR>")
nnoremap("<leader>dt", "<Cmd>lua require'dap'.terminate()<CR>")
nnoremap("<leader>dh", "<Cmd>lua require'dap.ui.widgets'.hover()<CR>")
nnoremap("<leader>dss", "<Cmd>lua require'dap.ui.widgets'.scopes()<CR>")
nnoremap("<leader>dib", "<Cmd>lua require'dap'.list_breakpoints()<CR>")
nnoremap("<leader>dis", "<Cmd>lua require'dap'.status()<CR>")
