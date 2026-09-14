-- Clipboard integration.
--
-- Where a real clipboard tool exists (pbcopy on macOS, wl-copy/xclip/xsel with
-- a display server attached) nvim finds it on its own, so leave it alone.
--
-- On a headless box -- a Coder dev box over SSH -- there is no clipboard tool
-- and no display, so `"+y` would silently go nowhere. Fall back to OSC 52,
-- which asks the *local* terminal emulator to set its own clipboard over the
-- tty. That works through ssh and tmux without forwarding anything.

local function native_clipboard()
  if vim.fn.has("macunix") == 1 then
    return vim.fn.executable("pbcopy") == 1
  end

  -- The Linux tools talk to a display server; without one they fail at runtime
  -- even though the binary is on PATH (xclip is in our apt list for tmux).
  local display = vim.env.WAYLAND_DISPLAY or vim.env.DISPLAY
  if display == nil or display == "" then
    return false
  end

  return vim.fn.executable("wl-copy") == 1 or vim.fn.executable("xclip") == 1 or vim.fn.executable("xsel") == 1
end

if native_clipboard() then
  return
end

local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
if not ok then
  return
end

-- Paste is deliberately *not* OSC 52. Reading the clipboard lets any program on
-- the remote host exfiltrate it, so terminals refuse the request or prompt --
-- and nvim's osc52.paste blocks 1s, nags "Press Ctrl-C to interrupt", then
-- blocks 9s more before giving up. That is a 10 second stall on every `"+p`.
--
-- Serving paste from the unnamed register keeps `"+p` working for anything
-- yanked in this session, and pasting from outside still works through the
-- terminal's own paste (bracketed paste), which never touches this path.
--
-- If your terminal does allow clipboard reads and you want the real thing,
-- swap paste_from_unnamed for osc52.paste("+") / osc52.paste("*") below.
local function paste_from_unnamed()
  return vim.split(vim.fn.getreg('"') or "", "\n")
end

vim.g.clipboard = {
  name = "OSC 52",
  copy = {
    ["+"] = osc52.copy("+"),
    ["*"] = osc52.copy("*"),
  },
  paste = {
    ["+"] = paste_from_unnamed,
    ["*"] = paste_from_unnamed,
  },
}
