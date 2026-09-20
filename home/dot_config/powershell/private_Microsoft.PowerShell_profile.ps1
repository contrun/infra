$editor = Get-Command hx, nvim, vim, notepad -ErrorAction SilentlyContinue | Select-Object -First 1
if ($editor) {
    $env:EDITOR = $editor.Source
}

# https://ohmyposh.dev/
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh | Invoke-Expression
}

# https://github.com/PowerShell/PSReadLine
if (Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue) {
    Set-PSReadLineOption -EditMode Emacs
	# https://github.com/kelleyma49/PSFzf
	if ((Get-Command Set-PsFzfOption -ErrorAction SilentlyContinue) -and (Get-Command fzf -ErrorAction SilentlyContinue)) {
		Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' `
				-PSReadlineChordReverseHistory 'Ctrl+r' `
				-PSReadlineChordReverseHistoryArgs 'Alt+a' `
				-PSReadlineChordSetLocation 'Alt+c' `
				-EnableAliasFuzzyEdit `
				-EnableAliasFuzzyGitStatus `
				-EnableAliasFuzzyHistory `
				-EnableAliasFuzzyKillProcess `
				-EnableAliasFuzzySetLocation `
				-TabExpansion

		Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
	}
}
