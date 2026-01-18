FROM docker.io/library/node:20-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv git tmux zsh curl wget \
    procps chromium fonts-powerline build-essential ca-certificates \
    exa \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Add UV for Python package management
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Install Claude Code and MCP Memory Service
RUN npm install -g @anthropic-ai/claude-code && \
    uv pip install --system --break-system-packages mcp-memory-service-lite

# Switch to non-root user
USER node
WORKDIR /home/node

# Install ZSH plugins
RUN git clone --depth=1 https://github.com/romkatv/gitstatus.git ~/gitstatus && \
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions && \
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zsh/zsh-syntax-highlighting

# Install OpenCode CLI and align PATHs
USER node
WORKDIR /home/node

# 1. Run the installer
RUN curl -fsSL https://opencode.ai/install | bash

# 2. Align the Container Metadata PATH with the actual install location
# Changed from .local/bin to .opencode/bin to match where the binary is
ENV PATH="/home/node/.opencode/bin:${PATH}"

# 3. Ensure interactive shells (Zsh/Bash) also see the binary
RUN echo 'export PATH="/home/node/.opencode/bin:$PATH"' >> ~/.zshrc && \
    echo 'export PATH="/home/node/.opencode/bin:$PATH"' >> ~/.bashrc

# Configure ZSH with working gitstatus prompt
RUN printf '%s\n' \
    '# Enable 256 color support' \
    'export TERM=xterm-256color' \
    '' \
    '# Enable prompt substitution' \
    'setopt PROMPT_SUBST' \
    '' \
    '# Load gitstatus first' \
    'if [[ -f ~/gitstatus/gitstatus.plugin.zsh ]]; then' \
    '  source ~/gitstatus/gitstatus.plugin.zsh' \
    '  gitstatus_stop MYPROMPT 2>/dev/null' \
    '  gitstatus_start -s -1 -u -1 -d -1 MYPROMPT' \
    'fi' \
    '' \
    '# Prompt function' \
    'function set_prompt() {' \
    '  local reset="%f%k"' \
    '  local blue_bg="%K{25}"' \
    '  local blue_fg="%F{25}"' \
    '  local grey_bg="%K{240}"' \
    '  local grey_fg="%F{240}"' \
    '  local white="%F{white}"' \
    '  local yellow="%F{yellow}"' \
    '  local green="%F{green}"' \
    '  local red="%F{red}"' \
    '  local chevron="▶"' \
    '  ' \
    '  PROMPT="${blue_bg}${white} musarraf ${reset}${blue_fg}${chevron}${reset}"' \
    '  ' \
    '  local path_parts=("${(@s:/:)PWD}")' \
    '  for part in $path_parts; do' \
    '    [[ -z $part ]] && continue' \
    '    PROMPT+="${grey_bg}${white} ${part} ${reset}${grey_fg}${chevron}${reset}"' \
    '  done' \
    '  ' \
    '  if gitstatus_query MYPROMPT 2>/dev/null && [[ $VCS_STATUS_RESULT == ok-sync ]]; then' \
    '    if [[ -n $VCS_STATUS_LOCAL_BRANCH ]]; then' \
    '      local git_icon git_color status_info' \
    '      if [[ -n $VCS_STATUS_ACTION ]]; then' \
    '        git_icon="✘"' \
    '        git_color="${red}"' \
    '        status_info=" [$VCS_STATUS_ACTION]"' \
    '      elif (( VCS_STATUS_NUM_CONFLICTED > 0 )); then' \
    '        git_icon="✘"' \
    '        git_color="${red}"' \
    '        status_info=" CONFLICT"' \
    '      elif (( VCS_STATUS_NUM_STAGED + VCS_STATUS_NUM_UNSTAGED + VCS_STATUS_NUM_UNTRACKED > 0 )); then' \
    '        git_icon="●"' \
    '        git_color="${yellow}"' \
    '        status_info=""' \
    '        local total_changes=$((VCS_STATUS_NUM_STAGED + VCS_STATUS_NUM_UNSTAGED))' \
    '        (( total_changes > 0 )) && status_info+=" +${total_changes}"' \
    '        (( VCS_STATUS_NUM_UNTRACKED > 0 )) && status_info+=" …${VCS_STATUS_NUM_UNTRACKED}"' \
    '      else' \
    '        git_icon="✓"' \
    '        git_color="${green}"' \
    '        status_info=""' \
    '      fi' \
    '      if [[ -n $VCS_STATUS_REMOTE_BRANCH ]]; then' \
    '        (( VCS_STATUS_COMMITS_BEHIND )) && status_info+=" ↓$VCS_STATUS_COMMITS_BEHIND"' \
    '        (( VCS_STATUS_COMMITS_AHEAD )) && status_info+=" ↑$VCS_STATUS_COMMITS_AHEAD"' \
    '      fi' \
    '      PROMPT+=" ${git_color}${git_icon} ${VCS_STATUS_LOCAL_BRANCH}${status_info}${reset}"' \
    '    fi' \
    '  fi' \
    '  PROMPT+=" "' \
    '}' \
    '' \
    '# Load other plugins' \
    '[[ -f ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh' \
    '[[ -f ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' \
    '' \
    '# Hook prompt function' \
    'autoload -Uz add-zsh-hook' \
    'add-zsh-hook precmd set_prompt' \
    '' \
    '# Git aliases' \
    'alias gs="git status"' \
    'alias gd="git diff"' \
    'alias gl="git log --oneline --graph --decorate -10"' \
    'alias ga="git add"' \
    'alias gc="git commit"' \
    'alias gco="git checkout"' \
    '' \
    '# Colorful ls with icons using exa' \
    'alias ls="exa --icons --group-directories-first"' \
    'alias ll="exa --icons --long --group-directories-first --git"' \
    'alias la="exa --icons --long --all --group-directories-first --git"' \
    'alias lt="exa --icons --tree --level=2 --group-directories-first"' \
    'alias lta="exa --icons --tree --level=2 --all --group-directories-first"' \
    '' \
    '# Colorful ls with icons using exa' \
    'alias ls="exa --icons --group-directories-first"' \
    'alias ll="exa --icons --long --group-directories-first --git"' \
    'alias la="exa --icons --long --all --group-directories-first --git"' \
    'alias lt="exa --icons --tree --level=2 --group-directories-first"' \
    'alias lta="exa --icons --tree --level=2 --all --group-directories-first"' \
    '' \
    '# History configuration' \
    'HISTFILE=~/.zsh_history' \
    'HISTSIZE=10000' \
    'SAVEHIST=10000' \
    'setopt SHARE_HISTORY' \
    'setopt HIST_IGNORE_DUPS' \
    'setopt HIST_IGNORE_ALL_DUPS' \
    '' \
    '# Enable colors' \
    'autoload -U colors && colors' \
    '' \
    '# Better completion' \
    'autoload -Uz compinit && compinit' \
    '' \
    '# Initialize prompt' \
    'set_prompt' \
    > ~/.zshrc

# Configure Bash with the same prompt
RUN printf '%s\n' \
    '# Enable 256 color support' \
    'export TERM=xterm-256color' \
    '' \
    '# Load gitstatus for bash' \
    'if [[ -f ~/gitstatus/gitstatus.prompt.sh ]]; then' \
    '  source ~/gitstatus/gitstatus.prompt.sh' \
    'fi' \
    '' \
    '# Prompt function for bash' \
    'function set_bash_prompt() {' \
    '  local reset="\[\e[0m\]"' \
    '  local blue_bg="\[\e[48;5;25m\]"' \
    '  local blue_fg="\[\e[38;5;25m\]"' \
    '  local grey_bg="\[\e[48;5;240m\]"' \
    '  local grey_fg="\[\e[38;5;240m\]"' \
    '  local white="\[\e[38;5;15m\]"' \
    '  local yellow="\[\e[38;5;11m\]"' \
    '  local green="\[\e[38;5;2m\]"' \
    '  local red="\[\e[38;5;1m\]"' \
    '  local chevron="▶"' \
    '  ' \
    '  PS1="${blue_bg}${white} musarraf ${reset}${blue_fg}${chevron}${reset}"' \
    '  ' \
    '  local IFS="/"' \
    '  local path_parts=($PWD)' \
    '  for part in "${path_parts[@]}"; do' \
    '    [[ -z $part ]] && continue' \
    '    PS1+="${grey_bg}${white} ${part} ${reset}${grey_fg}${chevron}${reset}"' \
    '  done' \
    '  ' \
    '  if gitstatus_query 2>/dev/null && [[ $VCS_STATUS_RESULT == ok-sync ]]; then' \
    '    if [[ -n $VCS_STATUS_LOCAL_BRANCH ]]; then' \
    '      local git_icon git_color status_info=""' \
    '      if [[ -n $VCS_STATUS_ACTION ]]; then' \
    '        git_icon="✘"' \
    '        git_color="${red}"' \
    '        status_info=" [$VCS_STATUS_ACTION]"' \
    '      elif (( VCS_STATUS_NUM_CONFLICTED > 0 )); then' \
    '        git_icon="✘"' \
    '        git_color="${red}"' \
    '        status_info=" CONFLICT"' \
    '      elif (( VCS_STATUS_NUM_STAGED + VCS_STATUS_NUM_UNSTAGED + VCS_STATUS_NUM_UNTRACKED > 0 )); then' \
    '        git_icon="●"' \
    '        git_color="${yellow}"' \
    '        local total_changes=$((VCS_STATUS_NUM_STAGED + VCS_STATUS_NUM_UNSTAGED))' \
    '        (( total_changes > 0 )) && status_info+=" +${total_changes}"' \
    '        (( VCS_STATUS_NUM_UNTRACKED > 0 )) && status_info+=" …${VCS_STATUS_NUM_UNTRACKED}"' \
    '      else' \
    '        git_icon="✓"' \
    '        git_color="${green}"' \
    '      fi' \
    '      if [[ -n $VCS_STATUS_REMOTE_BRANCH ]]; then' \
    '        (( VCS_STATUS_COMMITS_BEHIND > 0 )) && status_info+=" ↓$VCS_STATUS_COMMITS_BEHIND"' \
    '        (( VCS_STATUS_COMMITS_AHEAD > 0 )) && status_info+=" ↑$VCS_STATUS_COMMITS_AHEAD"' \
    '      fi' \
    '      PS1+=" ${git_color}${git_icon} ${VCS_STATUS_LOCAL_BRANCH}${status_info}${reset}"' \
    '    fi' \
    '  fi' \
    '  PS1+=" "' \
    '}' \
    '' \
    '# Set PROMPT_COMMAND to update prompt' \
    'PROMPT_COMMAND=set_bash_prompt' \
    '' \
    '# Git aliases' \
    'alias gs="git status"' \
    'alias gd="git diff"' \
    'alias gl="git log --oneline --graph --decorate -10"' \
    'alias ga="git add"' \
    'alias gc="git commit"' \
    'alias gco="git checkout"' \
    '' \
    '# Colorful ls with icons using exa' \
    'alias ls="exa --icons --group-directories-first"' \
    'alias ll="exa --icons --long --group-directories-first --git"' \
    'alias la="exa --icons --long --all --group-directories-first --git"' \
    'alias lt="exa --icons --tree --level=2 --group-directories-first"' \
    'alias lta="exa --icons --tree --level=2 --all --group-directories-first"' \
    '' \
    '# History configuration' \
    'HISTFILE=~/.bash_history' \
    'HISTSIZE=10000' \
    'HISTFILESIZE=20000' \
    'HISTCONTROL=ignoredups:erasedups' \
    'shopt -s histappend' \
    '' \
    '# Better completion' \
    '[[ -f /etc/bash_completion ]] && source /etc/bash_completion' \
    > ~/.bashrc

# Create devcontainer configuration
RUN mkdir -p ~/.devcontainer && printf '%s\n' \
    '{' \
    '  "name": "MHS Dev Container",' \
    '  "build": {' \
    '    "dockerfile": "../Dockerfile"' \
    '  },' \
    '  "workspaceFolder": "/workspace",' \
    '  "workspaceMount": "source=${localWorkspaceFolder},target=/workspace,type=bind,consistency=cached",' \
    '  "runArgs": [' \
    '    "--userns=keep-id",' \
    '    "--security-opt=label=disable"' \
    '  ],' \
    '  "customizations": {' \
    '    "vscode": {' \
    '      "extensions": [' \
    '        "dbaeumer.vscode-eslint",' \
    '        "esbenp.prettier-vscode",' \
    '        "bradlc.vscode-tailwindcss"' \
    '      ],' \
    '      "settings": {' \
    '        "terminal.integrated.defaultProfile.linux": "zsh"' \
    '      }' \
    '    }' \
    '  },' \
    '  "remoteUser": "node"' \
    '}' \
    > ~/.devcontainer/devcontainer.json

# Set working directory
WORKDIR /workspace

# Environment variables
ENV CHROME_BIN=/usr/bin/chromium \
    MCP_MEMORY_CHROMA_PATH=/home/node/.mcp-memory/chroma_db \
    MCP_MEMORY_USE_ONNX=1 \
    SHELL=/bin/zsh \
    TERM=xterm-256color

# Default command
CMD ["/bin/zsh", "-c", "tmux new-session -A -s mhs-dev"]
