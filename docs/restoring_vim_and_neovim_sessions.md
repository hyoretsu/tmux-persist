# Restoring vim and neovim sessions

- save vim/neovim sessions. I recommend
  [tpope/vim-obsession](https://github.com/tpope/vim-obsession) (as almost every
  plugin, it works for both vim and neovim).
- in `.tmux.conf`:

        # for vim
        set -g @persist-strategy-vim 'session'
        # for neovim
        set -g @persist-strategy-nvim 'session'

`tmux-persist` will now restore vim and neovim sessions if `Session.vim` file
is present.

> If you're using the vim binary provided by MacVim.app then you'll need to set `@persist-processes`, for example:
> ```
> set -g @persist-processes '~Vim -> vim'
> ```
