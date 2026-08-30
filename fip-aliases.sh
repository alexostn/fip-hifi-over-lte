# fip-aliases
# ٩(◕‿◕)~*✲ FIP aliases
#
#   bash: echo 'source ~/fip-hifi-over-lte/fip-aliases.sh' >> ~/.bashrc && source ~/.bashrc
#   zsh:  echo 'source ~/fip-hifi-over-lte/fip-aliases.sh' >> ~/.zshrc  && source ~/.zshrc
#
# zsh does NOT read ~/.bashrc — appending there silently does nothing for
# zsh users (`fip` stays "command not found" until it's in ~/.zshrc).
#
# already added the line but running in an old shell? reload + verify:
# source ~/.zshrc
# check
# type fip

FIP_SCRIPT="${HOME}/fip-hifi-over-lte/fip-stream.sh"

alias fip="$FIP_SCRIPT"
alias fjazz="$FIP_SCRIPT jazz"
alias frock="$FIP_SCRIPT rock"
alias fgroove="$FIP_SCRIPT groove"
alias fworld="$FIP_SCRIPT world"
alias felectro="$FIP_SCRIPT electro"
alias fhip="$FIP_SCRIPT hiphop"
alias fpop="$FIP_SCRIPT pop"
alias fmetal="$FIP_SCRIPT metal"
alias freggae="$FIP_SCRIPT reggae"
alias fnouveau="$FIP_SCRIPT nouveautes"
alias fsacre="$FIP_SCRIPT sacre"
alias fcultes="$FIP_SCRIPT cultes"
