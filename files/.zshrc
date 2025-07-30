# Use powerline
USE_POWERLINE="true"

# Source manjaro-zsh-configuration
if [[ -e /usr/share/zsh/manjaro-zsh-config ]]; then
  source /usr/share/zsh/manjaro-zsh-config
fi

# Use manjaro zsh prompt
if [[ -e /usr/share/zsh/manjaro-zsh-prompt ]]; then
  source /usr/share/zsh/manjaro-zsh-prompt
fi

# put .zshrc files in ~/.zshrc.d to have them sourced
if [[ -d "$HOME/.zshrc.d" ]]; then
  # Source user zsh configuration
  for file in "$HOME"/.zshrc.d/*.zshrc; do
    if [[ -d "$file" ]]; then
      echo "ERROR: SOME MUPPET PUT A DIR IN YOUR .zshrc.d DIRECTORY: $file"
    elif [[ -f "$file" ]]; then
      source "$file"
    fi
  done
fi
