if status is-interactive
    fastfetch
end

# ── Disable greeting ──────────────────────────────────────────────────────
set -g fish_greeting ""

# ── Catppuccin Mocha fish theme ───────────────────────────────────────────
set -g fish_color_normal          cdd6f4
set -g fish_color_command         89b4fa
set -g fish_color_keyword         cba6f7
set -g fish_color_quote           a6e3a1
set -g fish_color_redirection     f9e2af
set -g fish_color_end             fab387
set -g fish_color_error           f38ba8
set -g fish_color_param           cdd6f4
set -g fish_color_comment         6c7086
set -g fish_color_selection       --background=313244
set -g fish_color_search_match    --background=313244
set -g fish_color_operator        89dceb
set -g fish_color_escape          f5c2e7
set -g fish_color_autosuggestion  6c7086

# ── Prompt (Starship) ─────────────────────────────────────────────────────
starship init fish | source

# ── Zoxide ────────────────────────────────────────────────────────────────
zoxide init fish | source

# ── Aliases ───────────────────────────────────────────────────────────────
alias ls    'eza --icons --group-directories-first'
alias ll    'eza -la --icons --group-directories-first'
alias lt    'eza --tree --icons --level 2'
alias cat   'bat --style=auto'
alias grep  'rg'
alias find  'fd'
alias top   'btop'
alias vim   'nvim'

# ── Env ───────────────────────────────────────────────────────────────────
set -gx EDITOR nvim
set -gx BROWSER firefox
set -gx XDG_CURRENT_DESKTOP niri
set -gx NIXPKGS_ALLOW_UNFREE 1
