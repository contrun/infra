if status is-interactive
    # Commands to run in interactive sessions can go here
    # if type -q atuin
    #     atuin init fish | source
    # end
end

function fish_greeting
    if type -q fortune
        fortune -a
    end
end
