evaluate-commands %sh{
    config_files="
        recentf.kak
    "

    for file in $config_files; do
        printf "%s" "
            try %{
                source %{${kak_config:?}/$file}
            } catch %{
                echo -debug %val{error}
            }
        "
    done
}

map global normal <a-s> ': write<ret>'

addhl global/ wrap

set global ui_options ncurses_assistant=off
set global ui_options ncurses_assistant=none

hook global WinSetOption filetype=mail %{
    set window autowrap_column 72
    autowrap-enable
}

hook global BufCreate .*[.](sbt) %{
    set-option buffer filetype scala
}

hook global RegisterModified '"' %{ nop %sh{
    printf %s "$kak_main_reg_dquote" | clipboard
}}

evaluate-commands %sh{
    plugins="$HOME/.config/kak/plugins"
    mkdir -p $plugins
    [ ! -e "$plugins/plug.kak" ] && \
        git clone -q https://github.com/andreyorst/plug.kak "$plugins/plug.kak"
    printf "%s\n" "source '$plugins/plug.kak/rc/plug.kak'"
}
plug "andreyorst/plug.kak" noload

plug "lePerdu/kakboard" %{
    hook global WinCreate .* %{ kakboard-enable }
}

plug "https://gitlab.com/Screwtapello/kakoune-state-save" config %{
    hook global KakBegin .* %{
        state-save-reg-load colon
        state-save-reg-load pipe
        state-save-reg-load slash
    }

    hook global KakEnd .* %{
        state-save-reg-save colon
        state-save-reg-save pipe
        state-save-reg-save slash
    }

    hook global FocusOut .* %{ state-save-reg-save dquote }
    hook global FocusIn  .* %{ state-save-reg-load dquote }
}

plug "kak-lsp/kak-lsp" do %{
    cargo install --locked --force --path .
} config %{
    # uncomment to enable debugging
    eval %sh{echo ${kak_opt_lsp_cmd} >> /tmp/kak-lsp.log}
    set global lsp_cmd "kak-lsp -s %val{session} -vvv --log /tmp/kak-lsp.log"

    # this is not necessary; the `lsp-enable-window` will take care of it
    # eval %sh{${kak_opt_lsp_cmd} --kakoune -s $kak_session}

    set global lsp_diagnostic_line_error_sign '║'
    set global lsp_diagnostic_line_warning_sign '┊'

    define-command ne -docstring 'go to next error/warning from lsp' %{ lsp-find-error --include-warnings }
    define-command pe -docstring 'go to previous error/warning from lsp' %{ lsp-find-error --previous --include-warnings }
    define-command ee -docstring 'go to current error/warning from lsp' %{ lsp-find-error --include-warnings; lsp-find-error --previous --include-warnings }

    define-command lsp-restart -docstring 'restart lsp server' %{ lsp-stop; lsp-start }
    hook global WinSetOption filetype=(c|cpp|cc|rust|javascript|typescript|go|haskell|sh|css|html|latex|nix|python|ruby|terraform|scala) %{
        set-option window lsp_auto_highlight_references true
        set-option window lsp_hover_anchor false
        map global user l %{: enter-user-mode lsp<ret>} -docstring "LSP mode"
        lsp-auto-hover-enable
        lsp-inlay-diagnostics-enable global
        echo "Enabling LSP for filtetype %opt{filetype}"
        lsp-enable-window
    }

    hook global WinSetOption filetype=(scala) %{
        set global lsp_server_configuration metals.superMethodLenses=true
    }

    hook global WinSetOption filetype=(rust) %{
        set window lsp_server_configuration rust.clippy_preference="on"
    }

    hook global WinSetOption filetype=rust %{
        hook window BufWritePre .* %{
            evaluate-commands %sh{
                test -f rustfmt.toml && printf lsp-formatting-sync
            }
        }
    }

    hook global KakEnd .* lsp-exit
}

plug "andreyorst/fzf.kak" config %{
    map global normal <c-p> ': fzf-mode<ret>'
    set-option global fzf_file_command 'rg'
    set-option global fzf_highlight_command 'bat'
}

plug "danr/kakoune-easymotion" config %{
    map global user w :easy-motion-w<ret>
    map global user W :easy-motion-W<ret>
    map global user j :easy-motion-j<ret>
}

plug "eraserhd/kak-ansi" do %{
    make
}

plug "alexherbo2/prelude.kak"
plug "alexherbo2/auto-pairs.kak"
plug "alexherbo2/surround.kak"
plug "andreyorst/smarttab.kak"
plug "alexherbo2/split-object.kak"

plug "delapouite/kakoune-text-objects" %{
    text-object-map
}

plug "occivink/kakoune-vertical-selection"

plug "occivink/kakoune-expand"

plug "andreyorst/powerline.kak" config %{
        powerline-start
}
