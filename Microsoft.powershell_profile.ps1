using namespace System.Management.Automation
using namespace System.Management.Automation.Language

# UTF-8 encoding — fixes garbled Unicode in yarn/vitest/node output
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null
$env:LANG        = "en_US.UTF-8"
$env:PYTHONUTF8  = "1"

# Initialize basic modules
if ($host.Name -eq 'ConsoleHost') {
    Import-Module PSReadLine
}
Import-Module -Name Terminal-Icons

# Initialize oh-my-posh
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh --config "C:\Users\Dev\AppData\Local\Programs\oh-my-posh\themes\iterm2.omp.json" | Invoke-Expression
}

# Argument completers for common tools
Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
    $Local:word = $wordToComplete.Replace('"', '""')
    $Local:ast = $commandAst.ToString().Replace('"', '""')
    winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition | ForEach-Object {
        [CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

# PowerShell parameter completion for dotnet
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
    param($commandName, $wordToComplete, $cursorPosition)
    dotnet complete --position $cursorPosition "$wordToComplete" | ForEach-Object {
        [CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

# PSReadLine configuration
if (-not [Console]::IsOutputRedirected) {
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle InlineView
}
Set-PSReadLineOption -EditMode Windows
Set-PSReadLineOption -HistorySaveStyle SaveIncrementally
Set-PSReadLineOption -MaximumHistoryCount 4096

# Basic keybindings
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Tab       -Function MenuComplete
Set-PSReadLineKeyHandler -Key Shift+Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Key End              -Function AcceptSuggestion
Set-PSReadLineKeyHandler -Key Ctrl+RightArrow  -Function AcceptNextSuggestionWord
Set-PSReadLineKeyHandler -Key F2               -Function SwitchPredictionView

# This key handler shows the entire or filtered history using Out-GridView. The
# typed text is used as the substring pattern for filtering. A selected command
# is inserted to the command line without invoking. Multiple command selection
# is supported, e.g. selected by Ctrl + Click.
Set-PSReadLineKeyHandler -Key F7 `
    -BriefDescription History `
    -LongDescription 'Show command history' `
    -ScriptBlock {
    $pattern = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$pattern, [ref]$null)
    if ($pattern) {
        $pattern = [regex]::Escape($pattern)
    }

    $history = [System.Collections.ArrayList]@(
        $last = ''
        $lines = ''
        foreach ($line in [System.IO.File]::ReadLines((Get-PSReadLineOption).HistorySavePath)) {
            if ($line.EndsWith('`')) {
                $line = $line.Substring(0, $line.Length - 1)
                $lines = if ($lines) {
                    "$lines`n$line"
                }
                else {
                    $line
                }
                continue
            }

            if ($lines) {
                $line = "$lines`n$line"
                $lines = ''
            }

            if (($line -cne $last) -and (!$pattern -or ($line -match $pattern))) {
                $last = $line
                $line
            }
        }
    )
    $history.Reverse()

    $command = $history | Out-GridView -Title History -PassThru
    if ($command) {
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert(($command -join "`n"))
    }
}

# CaptureScreen is good for blog posts or email showing a transaction
# of what you did when asking for help or demonstrating a technique.
Set-PSReadLineKeyHandler -Chord 'Ctrl+d,Ctrl+c' -Function CaptureScreen

# The built-in word movement uses character delimiters, but token based word
# movement is also very useful - these are the bindings you'd use if you
# prefer the token based movements bound to the normal emacs word movement
# key bindings.
Set-PSReadLineKeyHandler -Key Alt+d -Function ShellKillWord
Set-PSReadLineKeyHandler -Key Alt+Backspace -Function ShellBackwardKillWord
Set-PSReadLineKeyHandler -Key Alt+b -Function ShellBackwardWord
Set-PSReadLineKeyHandler -Key Alt+f -Function ShellForwardWord
Set-PSReadLineKeyHandler -Key Alt+B -Function SelectShellBackwardWord
Set-PSReadLineKeyHandler -Key Alt+F -Function SelectShellForwardWord

#region Smart Insert/Delete

# The next four key handlers are designed to make entering matched quotes
# parens, and braces a nicer experience.  I'd like to include functions
# in the module that do this, but this implementation still isn't as smart
# as ReSharper, so I'm just providing it as a sample.

Set-PSReadLineKeyHandler -Key '"', "'" `
    -BriefDescription SmartInsertQuote `
    -LongDescription "Insert paired quotes if not already on a quote" `
    -ScriptBlock {
    param($key, $arg)

    $quote = $key.KeyChar

    $selectionStart = $null
    $selectionLength = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    # If text is selected, just quote it without any smarts
    if ($selectionStart -ne -1) {
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, $quote + $line.SubString($selectionStart, $selectionLength) + $quote)
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
        return
    }

    $ast = $null
    $tokens = $null
    $parseErrors = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$parseErrors, [ref]$null)

    function FindToken {
        param($tokens, $cursor)

        foreach ($token in $tokens) {
            if ($cursor -lt $token.Extent.StartOffset) { continue }
            if ($cursor -lt $token.Extent.EndOffset) {
                $result = $token
                $token = $token -as [StringExpandableToken]
                if ($token) {
                    $nested = FindToken $token.NestedTokens $cursor
                    if ($nested) { $result = $nested }
                }

                return $result
            }
        }
        return $null
    }

    $token = FindToken $tokens $cursor

    # If we're on or inside a **quoted** string token (so not generic), we need to be smarter
    if ($token -is [StringToken] -and $token.Kind -ne [TokenKind]::Generic) {
        # If we're at the start of the string, assume we're inserting a new string
        if ($token.Extent.StartOffset -eq $cursor) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$quote$quote ")
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
            return
        }

        # If we're at the end of the string, move over the closing quote if present.
        if ($token.Extent.EndOffset -eq ($cursor + 1) -and $line[$cursor] -eq $quote) {
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
            return
        }
    }

    if ($null -eq $token -or
        $token.Kind -eq [TokenKind]::RParen -or $token.Kind -eq [TokenKind]::RCurly -or $token.Kind -eq [TokenKind]::RBracket) {
        if ($line[0..$cursor].Where{ $_ -eq $quote }.Count % 2 -eq 1) {
            # Odd number of quotes before the cursor, insert a single quote
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert($quote)
        }
        else {
            # Insert matching quotes, move cursor to be in between the quotes
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$quote$quote")
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
        }
        return
    }

    # If cursor is at the start of a token, enclose it in quotes.
    if ($token.Extent.StartOffset -eq $cursor) {
        if ($token.Kind -eq [TokenKind]::Generic -or $token.Kind -eq [TokenKind]::Identifier -or
            $token.Kind -eq [TokenKind]::Variable -or $token.TokenFlags.hasFlag([TokenFlags]::Keyword)) {
            $end = $token.Extent.EndOffset
            $len = $end - $cursor
            [Microsoft.PowerShell.PSConsoleReadLine]::Replace($cursor, $len, $quote + $line.SubString($cursor, $len) + $quote)
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($end + 2)
            return
        }
    }

    # We failed to be smart, so just insert a single quote
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($quote)
}

Set-PSReadLineKeyHandler -Key '(', '{', '[' `
    -BriefDescription InsertPairedBraces `
    -LongDescription "Insert matching braces" `
    -ScriptBlock {
    param($key, $arg)

    $closeChar = switch ($key.KeyChar) {
        <#case#> '(' { [char]')'; break }
        <#case#> '{' { [char]'}'; break }
        <#case#> '[' { [char]']'; break }
    }

    $selectionStart = $null
    $selectionLength = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($selectionStart -ne -1) {
        # Text is selected, wrap it in brackets
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, $key.KeyChar + $line.SubString($selectionStart, $selectionLength) + $closeChar)
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
    }
    else {
        # No text is selected, insert a pair
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)$closeChar")
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
    }
}

Set-PSReadLineKeyHandler -Key ')', ']', '}' `
    -BriefDescription SmartCloseBraces `
    -LongDescription "Insert closing brace or skip" `
    -ScriptBlock {
    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($line[$cursor] -eq $key.KeyChar) {
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
    }
    else {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)")
    }
}

Set-PSReadLineKeyHandler -Key Backspace `
    -BriefDescription SmartBackspace `
    -LongDescription "Delete previous character or matching quotes/parens/braces" `
    -ScriptBlock {
    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($cursor -gt 0) {
        $toMatch = $null
        if ($cursor -lt $line.Length) {
            switch ($line[$cursor]) {
                <#case#> '"' { $toMatch = '"'; break }
                <#case#> "'" { $toMatch = "'"; break }
                <#case#> ')' { $toMatch = '('; break }
                <#case#> ']' { $toMatch = '['; break }
                <#case#> '}' { $toMatch = '{'; break }
            }
        }

        if ($toMatch -ne $null -and $line[$cursor - 1] -eq $toMatch) {
            [Microsoft.PowerShell.PSConsoleReadLine]::Delete($cursor - 1, 2)
        }
        else {
            [Microsoft.PowerShell.PSConsoleReadLine]::BackwardDeleteChar($key, $arg)
        }
    }
}

#endregion Smart Insert/Delete

# Sometimes you enter a command but realize you forgot to do something else first.
# This binding will let you save that command in the history so you can recall it,
# but it doesn't actually execute.  It also clears the line with RevertLine so the
# undo stack is reset - though redo will still reconstruct the command line.
Set-PSReadLineKeyHandler -Key Alt+w `
    -BriefDescription SaveInHistory `
    -LongDescription "Save current line in history but do not execute" `
    -ScriptBlock {
    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    [Microsoft.PowerShell.PSConsoleReadLine]::AddToHistory($line)
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
}

# Insert text from the clipboard as a here string
Set-PSReadLineKeyHandler -Key Ctrl+V `
    -BriefDescription PasteAsHereString `
    -LongDescription "Paste the clipboard text as a here string" `
    -ScriptBlock {
    param($key, $arg)

    Add-Type -Assembly PresentationCore
    if ([System.Windows.Clipboard]::ContainsText()) {
        # Get clipboard text - remove trailing spaces, convert \r\n to \n, and remove the final \n.
        $text = ([System.Windows.Clipboard]::GetText() -replace "\p{Zs}*`r?`n", "`n").TrimEnd()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("@'`n$text`n'@")
    }
    else {
        [Microsoft.PowerShell.PSConsoleReadLine]::Ding()
    }
}

# Sometimes you want to get a property of invoke a member on what you've entered so far
# but you need parens to do that.  This binding will help by putting parens around the current selection,
# or if nothing is selected, the whole line.
Set-PSReadLineKeyHandler -Key 'Alt+(' `
    -BriefDescription ParenthesizeSelection `
    -LongDescription "Put parenthesis around the selection or entire line and move the cursor to after the closing parenthesis" `
    -ScriptBlock {
    param($key, $arg)

    $selectionStart = $null
    $selectionLength = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    if ($selectionStart -ne -1) {
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, '(' + $line.SubString($selectionStart, $selectionLength) + ')')
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
    }
    else {
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, '(' + $line + ')')
        [Microsoft.PowerShell.PSConsoleReadLine]::EndOfLine()
    }
}

# Each time you press Alt+', this key handler will change the token
# under or before the cursor.  It will cycle through single quotes, double quotes, or
# no quotes each time it is invoked.
Set-PSReadLineKeyHandler -Key "Alt+'" `
    -BriefDescription ToggleQuoteArgument `
    -LongDescription "Toggle quotes on the argument under the cursor" `
    -ScriptBlock {
    param($key, $arg)

    $ast = $null
    $tokens = $null
    $errors = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$errors, [ref]$cursor)

    $tokenToChange = $null
    foreach ($token in $tokens) {
        $extent = $token.Extent
        if ($extent.StartOffset -le $cursor -and $extent.EndOffset -ge $cursor) {
            $tokenToChange = $token

            # If the cursor is at the end (it's really 1 past the end) of the previous token,
            # we only want to change the previous token if there is no token under the cursor
            if ($extent.EndOffset -eq $cursor -and $foreach.MoveNext()) {
                $nextToken = $foreach.Current
                if ($nextToken.Extent.StartOffset -eq $cursor) {
                    $tokenToChange = $nextToken
                }
            }
            break
        }
    }

    if ($tokenToChange -ne $null) {
        $extent = $tokenToChange.Extent
        $tokenText = $extent.Text
        if ($tokenText[0] -eq '"' -and $tokenText[-1] -eq '"') {
            # Switch to no quotes
            $replacement = $tokenText.Substring(1, $tokenText.Length - 2)
        }
        elseif ($tokenText[0] -eq "'" -and $tokenText[-1] -eq "'") {
            # Switch to double quotes
            $replacement = '"' + $tokenText.Substring(1, $tokenText.Length - 2) + '"'
        }
        else {
            # Add single quotes
            $replacement = "'" + $tokenText + "'"
        }

        [Microsoft.PowerShell.PSConsoleReadLine]::Replace(
            $extent.StartOffset,
            $tokenText.Length,
            $replacement)
    }
}

# This example will replace any aliases on the command line with the resolved commands.
Set-PSReadLineKeyHandler -Key "Alt+%" `
    -BriefDescription ExpandAliases `
    -LongDescription "Replace all aliases with the full command" `
    -ScriptBlock {
    param($key, $arg)

    $ast = $null
    $tokens = $null
    $errors = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$errors, [ref]$cursor)

    $startAdjustment = 0
    foreach ($token in $tokens) {
        if ($token.TokenFlags -band [TokenFlags]::CommandName) {
            $alias = $ExecutionContext.InvokeCommand.GetCommand($token.Extent.Text, 'Alias')
            if ($alias -ne $null) {
                $resolvedCommand = $alias.ResolvedCommandName
                if ($resolvedCommand -ne $null) {
                    $extent = $token.Extent
                    $length = $extent.EndOffset - $extent.StartOffset
                    [Microsoft.PowerShell.PSConsoleReadLine]::Replace(
                        $extent.StartOffset + $startAdjustment,
                        $length,
                        $resolvedCommand)

                    # Our copy of the tokens won't have been updated, so we need to
                    # adjust by the difference in length
                    $startAdjustment += ($resolvedCommand.Length - $length)
                }
            }
        }
    }
}

# F1 for help on the command line - naturally
Set-PSReadLineKeyHandler -Key F1 `
    -BriefDescription CommandHelp `
    -LongDescription "Open the help window for the current command" `
    -ScriptBlock {
    param($key, $arg)

    $ast = $null
    $tokens = $null
    $errors = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$errors, [ref]$cursor)

    $commandAst = $ast.FindAll( {
            $node = $args[0]
            $node -is [CommandAst] -and
            $node.Extent.StartOffset -le $cursor -and
            $node.Extent.EndOffset -ge $cursor
        }, $true) | Select-Object -Last 1

    if ($commandAst -ne $null) {
        $commandName = $commandAst.GetCommandName()
        if ($commandName -ne $null) {
            $command = $ExecutionContext.InvokeCommand.GetCommand($commandName, 'All')
            if ($command -is [AliasInfo]) {
                $commandName = $command.ResolvedCommandName
            }

            if ($commandName -ne $null) {
                Get-Help $commandName -ShowWindow
            }
        }
    }
}

#
# Ctrl+Shift+j then type a key to mark the current directory.
# Ctrj+j then the same key will change back to that directory without
# needing to type cd and won't change the command line.

#
$global:PSReadLineMarks = @{}

Set-PSReadLineKeyHandler -Key Ctrl+J `
    -BriefDescription MarkDirectory `
    -LongDescription "Mark the current directory" `
    -ScriptBlock {
    param($key, $arg)

    $key = [Console]::ReadKey($true)
    $global:PSReadLineMarks[$key.KeyChar] = $pwd
}

Set-PSReadLineKeyHandler -Key Ctrl+j `
    -BriefDescription JumpDirectory `
    -LongDescription "Goto the marked directory" `
    -ScriptBlock {
    param($key, $arg)

    $key = [Console]::ReadKey()
    $dir = $global:PSReadLineMarks[$key.KeyChar]
    if ($dir) {
        cd $dir
        [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
    }
}

Set-PSReadLineKeyHandler -Key Alt+j `
    -BriefDescription ShowDirectoryMarks `
    -LongDescription "Show the currently marked directories" `
    -ScriptBlock {
    param($key, $arg)

    $global:PSReadLineMarks.GetEnumerator() | % {
        [PSCustomObject]@{Key = $_.Key; Dir = $_.Value } } |
    Format-Table -AutoSize | Out-Host

    [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
}

# Auto correct 'git cmt' to 'git commit'
Set-PSReadLineOption -CommandValidationHandler {
    param([CommandAst]$CommandAst)

    switch ($CommandAst.GetCommandName()) {
        'git' {
            $gitCmd = $CommandAst.CommandElements[1].Extent
            switch ($gitCmd.Text) {
                'cmt' {
                    [Microsoft.PowerShell.PSConsoleReadLine]::Replace(
                        $gitCmd.StartOffset, $gitCmd.EndOffset - $gitCmd.StartOffset, 'commit')
                }
            }
        }
    }
}

# `ForwardChar` accepts the entire suggestion text when the cursor is at the end of the line.
# This custom binding makes `RightArrow` behave similarly - accepting the next word instead of the entire suggestion text.
Set-PSReadLineKeyHandler -Key RightArrow `
    -BriefDescription ForwardCharAndAcceptNextSuggestionWord `
    -LongDescription "Move cursor one character to the right in the current editing line and accept the next word in suggestion when it's at the end of current editing line" `
    -ScriptBlock {
    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($cursor -lt $line.Length) {
        [Microsoft.PowerShell.PSConsoleReadLine]::ForwardChar($key, $arg)
    }
    else {
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptNextSuggestionWord($key, $arg)
    }
}

# Cycle through arguments on current line and select the text. This makes it easier to quickly change the argument if re-running a previously run command from the history
# or if using a psreadline predictor. You can also use a digit argument to specify which argument you want to select, i.e. Alt+1, Alt+a selects the first argument
# on the command line.
Set-PSReadLineKeyHandler -Key Alt+a `
    -BriefDescription SelectCommandArguments `
    -LongDescription "Set current selection to next command argument in the command line. Use of digit argument selects argument by position" `
    -ScriptBlock {
    param($key, $arg)

    $ast = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$null, [ref]$null, [ref]$cursor)

    $asts = $ast.FindAll( {
            $args[0] -is [System.Management.Automation.Language.ExpressionAst] -and
            $args[0].Parent -is [System.Management.Automation.Language.CommandAst] -and
            $args[0].Extent.StartOffset -ne $args[0].Parent.Extent.StartOffset
        }, $true)

    if ($asts.Count -eq 0) {
        [Microsoft.PowerShell.PSConsoleReadLine]::Ding()
        return
    }

    $nextAst = $null

    if ($null -ne $arg) {
        $nextAst = $asts[$arg - 1]
    }
    else {
        foreach ($ast in $asts) {
            if ($ast.Extent.StartOffset -ge $cursor) {
                $nextAst = $ast
                break
            }
        }

        if ($null -eq $nextAst) {
            $nextAst = $asts[0]
        }
    }

    $startOffsetAdjustment = 0
    $endOffsetAdjustment = 0

    if ($nextAst -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
        $nextAst.StringConstantType -ne [System.Management.Automation.Language.StringConstantType]::BareWord) {
        $startOffsetAdjustment = 1
        $endOffsetAdjustment = 2
    }

    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($nextAst.Extent.StartOffset + $startOffsetAdjustment)
    [Microsoft.PowerShell.PSConsoleReadLine]::SetMark($null, $null)
    [Microsoft.PowerShell.PSConsoleReadLine]::SelectForwardChar($null, ($nextAst.Extent.EndOffset - $nextAst.Extent.StartOffset) - $endOffsetAdjustment)
}

# This is an example of a macro that you might use to execute a command.
# This will add the command to history.
Set-PSReadLineKeyHandler -Key Ctrl+Shift+b `
    -BriefDescription BuildCurrentDirectory `
    -LongDescription "Build the current directory" `
    -ScriptBlock {
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert("dotnet build")
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
}

Set-PSReadLineKeyHandler -Key Ctrl+Shift+t `
    -BriefDescription TestCurrentDirectory `
    -LongDescription "Test the current directory" `
    -ScriptBlock {
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert("dotnet test")
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
}
$WarningPreference = "SilentlyContinue"

$script:ClaudeExternalCommand = (Get-Command claude -CommandType ExternalScript -ErrorAction SilentlyContinue).Source

function claude {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [object[]]$Arguments
    )

    if (-not $script:ClaudeExternalCommand) {
        throw "Unable to resolve the external Claude command."
    }

    try {
        Clear-Host
    }
    catch {
    }

    & $script:ClaudeExternalCommand @Arguments
}

#region Docker Logs Split Pane
function docker-logs-split {
    param(
        [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
        [string[]]$Containers,
        [switch]$Follow = $true,
        [ValidateSet("grid","horizontal","vertical")]
        [string]$Layout = "horizontal"
    )
    if ($Containers.Count -eq 0) {
        Write-Host "Usage: dl-split <c1> <c2> ... [-Layout grid|horizontal|vertical]"
        return
    }

    $running = @(docker ps --format "{{.Names}}" 2>$null)
    $resolved = @()
    foreach ($name in $Containers) {
        if ($running -contains $name) { $resolved += $name; continue }
        $found = @($running | Where-Object { $_ -like "*$name*" })
        if ($found.Count -eq 1) {
            Write-Host "Resolved '$name' -> '$($found[0])'" -ForegroundColor Cyan
            $resolved += $found[0]
        } elseif ($found.Count -gt 1) {
            Write-Host "Ambiguous '$name': $($found -join ', ')" -ForegroundColor Yellow; return
        } else {
            Write-Host "No match '$name'. Running: $($running -join ', ')" -ForegroundColor Red; return
        }
    }

    $f = if ($Follow) { "-f" } else { "" }

    # Build wt argument list (avoids Invoke-Expression parser issues with -H/-V)
    $args = @("-w", "0", "nt", "-d", ".", "pwsh", "-NoExit", "-Command", "docker logs $f $($resolved[0])")

    function Add-Pane($arr, $splitFlag, $name) {
        $arr += ";"; $arr += "sp"; $arr += $splitFlag; $arr += "-d"; $arr += "."
        $arr += "pwsh"; $arr += "-NoExit"; $arr += "-Command"; $arr += "docker logs $f $name"
        return ,$arr
    }
    function Add-Focus($arr, $dir) {
        $arr += ";"; $arr += "mf"; $arr += $dir
        return ,$arr
    }

    switch ($Layout) {
        "horizontal" {
            for ($i = 1; $i -lt $resolved.Count; $i++) { $args = Add-Pane $args "-H" $resolved[$i] }
        }
        "vertical" {
            for ($i = 1; $i -lt $resolved.Count; $i++) { $args = Add-Pane $args "-V" $resolved[$i] }
        }
        "grid" {
            if ($resolved.Count -gt 1) { $args = Add-Pane $args "-V" $resolved[1] }
            if ($resolved.Count -gt 2) { $args = Add-Focus $args "left"; $args = Add-Pane $args "-H" $resolved[2] }
            if ($resolved.Count -gt 3) { $args = Add-Focus $args "right"; $args = Add-Pane $args "-H" $resolved[3] }
        }
    }
    & wt.exe @args
}
Set-Alias -Name dl-split -Value docker-logs-split

function docker-logs-paste {
    param(
        [string]$Text = $null,
        [switch]$Follow = $true
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        Add-Type -Assembly PresentationCore -ErrorAction SilentlyContinue
        if (-not [System.Windows.Clipboard]::ContainsText()) {
            Write-Host "Clipboard does not contain text."
            return
        }
        $Text = [System.Windows.Clipboard]::GetText()
    }

    # Detect docker logs / docker compose logs lines
    $lines = $Text -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -match "docker\s+(logs|compose\s+logs)" }

    if ($lines.Count -eq 0) {
        Write-Host "No docker logs commands found in input."
        return
    }

    $followFlag = if ($Follow) { "-f" } else { "" }

    # Extract container names / service names from the commands
    $containers = @()
    foreach ($line in $lines) {
        $clean = $line -replace '^docker\s+(logs|compose\s+logs)\s+(-f\s+)?', ''
        $clean = $clean -replace 'docker\s+compose\s+(-f\s+)?\s*logs\s*', ''
        $clean = $clean.Trim()
        if ($clean -and -not [string]::IsNullOrWhiteSpace($clean)) {
            $containers += $clean
        }
    }

    if ($containers.Count -eq 0) {
        Write-Host "Could not extract container names from pasted commands."
        return
    }

    # Resolve pasted container names with fuzzy matching
    $running = docker ps --format "{{.Names}}" 2>$null
    $resolved = @()
    foreach ($c in $containers) {
        if ($c -in $running) { $resolved += $c; continue }
        $m = $running | Where-Object { $_ -like "*$c*" }
        if ($m.Count -eq 1) { $resolved += $m[0] }
        elseif ($m.Count -gt 1) { Write-Host "Ambiguous '$c': $($m -join ', ')" -ForegroundColor Yellow }
        else { Write-Host "No match for '$c'" -ForegroundColor Red }
    }
    if ($resolved.Count -eq 0) {
        Write-Host "No valid containers to show." -ForegroundColor Red
        return
    }

    $wtArgs = @("-w", "0", "nt", "-d", ".", "pwsh", "-NoExit", "-Command", "docker logs $followFlag $($resolved[0])")
    for ($i = 1; $i -lt $resolved.Count; $i++) {
        $wtArgs += ";"
        $wtArgs += "sp"
        $wtArgs += "-d"
        $wtArgs += "."
        $wtArgs += "pwsh"
        $wtArgs += "-NoExit"
        $wtArgs += "-Command"
        $cmd = "docker logs $followFlag $($resolved[$i])"
        Start-Process wt -ArgumentList "-w", "0", "sp", "-H", "-d", ".", "pwsh", "-NoExit", "-Command", $cmd
        Start-Sleep -Milliseconds 300
    }
}
Set-Alias -Name dl-paste -Value docker-logs-paste

# Docker monitor TUI (requires: winget install JesseDuffield.lazydocker)
function dmon {
    if (-not (Get-Command lazydocker -ErrorAction SilentlyContinue)) {
        Write-Host "lazydocker not installed. Run: winget install JesseDuffield.lazydocker" -ForegroundColor Yellow
        return
    }
    lazydocker
}
#endregion

#region Git shortcuts
function gs    { git status -sb }
function glog  { git log --oneline --graph --decorate -20 }
function gco   { git checkout @Args }
function gcb   { git checkout -b @Args }
function gaa   { git add -A }
function gst   { git stash @Args }
function gsp   { git stash pop }
function gd    { git diff @Args }
function gp    { git push @Args }
function gpl   { git pull --rebase @Args }
function gcp {
    param([Parameter(Mandatory)][string]$Message)
    git add -A; git commit -m $Message; git push
}
#endregion

#region Yarn / Node shortcuts
function yd    { yarn dev @Args }
function yda   { yarn dev:api @Args }
function ydw   { yarn dev:web @Args }
function yt    { yarn test @Args }
function ytw   { yarn test --watch @Args }
function yb    { yarn build @Args }
function yi    { yarn install }
function nvv   { Write-Host "node $(node -v)  yarn $(yarn -v)" }
#endregion

#region Zoxide (smart cd) — install: winget install ajeetdsouza.zoxide
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
} else {
    Write-Host "Tip: install zoxide for smart cd -> winget install ajeetdsouza.zoxide" -ForegroundColor DarkGray
}
#endregion

#region Port killer
function kill-port {
    param([Parameter(Mandatory)][int]$Port)
    $pids = netstat -ano | Select-String ":$Port\s" |
        ForEach-Object { ($_ -split '\s+')[-1] } | Sort-Object -Unique
    if (-not $pids) { Write-Host "Nothing on :$Port" -ForegroundColor Yellow; return }
    foreach ($id in $pids) {
        Stop-Process -Id $id -Force -ErrorAction SilentlyContinue
        Write-Host "Killed PID $id on :$Port" -ForegroundColor Green
    }
}
Set-Alias -Name kp -Value kill-port
#endregion

#region .env loader
function load-env {
    param([string]$File = ".env")
    if (-not (Test-Path $File)) { Write-Host "$File not found" -ForegroundColor Red; return }
    $count = 0
    Get-Content $File | Where-Object { $_ -match '^\s*[^#=\s]' -and $_ -match '=' } | ForEach-Object {
        $k, $v = $_ -split '=', 2
        $k = $k.Trim(); $v = $v.Trim().Trim('"').Trim("'")
        [System.Environment]::SetEnvironmentVariable($k, $v, 'Process')
        $count++
    }
    Write-Host "Loaded $count vars from $File" -ForegroundColor Green
}
Set-Alias -Name le -Value load-env
#endregion

#region VS Code shortcuts
function c.   { code . }
function c    { if ($Args.Count -eq 0) { code . } else { code @Args } }
#endregion

#region Smart Argument Completers

# ── Git ────────────────────────────────────────────────────────────────────────
Register-ArgumentCompleter -Native -CommandName git -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    $elements = $commandAst.CommandElements
    $sub = if ($elements.Count -ge 2) { $elements[1].ToString() } else { '' }

    if ($elements.Count -le 2) {
        @('add','bisect','branch','checkout','cherry-pick','clean','clone',
          'commit','diff','fetch','init','log','merge','mv','pull','push',
          'rebase','remote','reset','restore','revert','rm','show','stash',
          'status','switch','tag') |
        Where-Object { $_ -like "$wordToComplete*" } |
        ForEach-Object { [CompletionResult]::new($_, $_, 'ParameterValue', $_) }
        return
    }

    switch ($sub) {
        { $_ -in 'checkout','switch','merge','rebase','diff','cherry-pick' } {
            git branch --all 2>$null |
                ForEach-Object { $_.Trim(' *').Replace('remotes/','') } |
                Where-Object { $_ -like "$wordToComplete*" -and $_ -notmatch '->' } |
                Select-Object -Unique |
                ForEach-Object { [CompletionResult]::new($_, $_, 'ParameterValue', $_) }
        }
        'stash' {
            @('push','pop','list','drop','apply','clear','show') |
            Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { [CompletionResult]::new($_, $_, 'ParameterValue', $_) }
        }
        'remote' {
            @('add','remove','rename','set-url','get-url','-v','show','prune') |
            Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { [CompletionResult]::new($_, $_, 'ParameterValue', $_) }
        }
        'commit' {
            @('-m','--amend','-a','--no-verify','--allow-empty','-v','--fixup') |
            Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { [CompletionResult]::new($_, $_, 'ParameterValue', $_) }
        }
        'push' {
            @('origin','--force','--force-with-lease','--tags','-u','--set-upstream') |
            Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { [CompletionResult]::new($_, $_, 'ParameterValue', $_) }
        }
        'log' {
            @('--oneline','--graph','--decorate','-p','--stat','--all','-n','--follow') |
            Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { [CompletionResult]::new($_, $_, 'ParameterValue', $_) }
        }
        'branch' {
            @('-d','-D','-m','-r','-a','--list','--merged','--no-merged') |
            Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { [CompletionResult]::new($_, $_, 'ParameterValue', $_) }
        }
    }
}

# ── Docker ─────────────────────────────────────────────────────────────────────
Register-ArgumentCompleter -Native -CommandName docker -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    $elements = $commandAst.CommandElements
    $sub  = if ($elements.Count -ge 2) { $elements[1].ToString() } else { '' }
    $sub2 = if ($elements.Count -ge 3) { $elements[2].ToString() } else { '' }

    if ($elements.Count -le 2) {
        @('build','compose','exec','images','inspect','kill','logs','network',
          'ps','pull','push','rm','rmi','run','start','stats','stop',
          'system','tag','volume') |
        Where-Object { $_ -like "$wordToComplete*" } |
        ForEach-Object { [CompletionResult]::new($_, $_, 'ParameterValue', $_) }
        return
    }

    switch ($sub) {
        { $_ -in 'exec','logs','stop','start','rm','kill','inspect','stats','restart' } {
            docker ps --format '{{.Names}}' 2>$null |
                Where-Object { $_ -like "$wordToComplete*" } |
                ForEach-Object { [CompletionResult]::new($_, $_, 'ParameterValue', $_) }
        }
        'compose' {
            if ($elements.Count -le 3) {
                @('up','down','logs','ps','build','restart','exec','pull','push','run','stop','start','watch') |
                Where-Object { $_ -like "$wordToComplete*" } |
                ForEach-Object { [CompletionResult]::new($_, $_, 'ParameterValue', $_) }
            }
        }
        'rmi' {
            docker images --format '{{.Repository}}:{{.Tag}}' 2>$null |
                Where-Object { $_ -like "$wordToComplete*" } |
                ForEach-Object { [CompletionResult]::new($_, $_, 'ParameterValue', $_) }
        }
        'network' {
            @('ls','create','rm','inspect','connect','disconnect','prune') |
            Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { [CompletionResult]::new($_, $_, 'ParameterValue', $_) }
        }
        'system' {
            @('prune','df','info','events') |
            Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { [CompletionResult]::new($_, $_, 'ParameterValue', $_) }
        }
    }
}

# ── Yarn ───────────────────────────────────────────────────────────────────────
Register-ArgumentCompleter -Native -CommandName yarn -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    $elements = $commandAst.CommandElements
    if ($elements.Count -gt 2) { return }

    $cmds = @('install','add','remove','upgrade','up','run','build','test','dev',
              'start','workspace','workspaces','info','list','link','unlink',
              'pack','publish','cache','config','init','outdated','why','dlx')
    $scripts = @()
    if (Test-Path 'package.json') {
        try { $scripts = (Get-Content 'package.json' -Raw | ConvertFrom-Json).scripts.PSObject.Properties.Name } catch {}
    }
    ($cmds + $scripts) | Sort-Object -Unique |
        Where-Object { $_ -like "$wordToComplete*" } |
        ForEach-Object { [CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}

# ── npm ────────────────────────────────────────────────────────────────────────
Register-ArgumentCompleter -Native -CommandName npm -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    $elements = $commandAst.CommandElements
    if ($elements.Count -gt 2) { return }

    $cmds = @('install','i','uninstall','update','run','test','start','build',
              'publish','pack','audit','outdated','list','link','unlink',
              'cache','config','init','exec','ci','version','dedupe')
    $scripts = @()
    if (Test-Path 'package.json') {
        try { $scripts = (Get-Content 'package.json' -Raw | ConvertFrom-Json).scripts.PSObject.Properties.Name } catch {}
    }
    ($cmds + $scripts) | Sort-Object -Unique |
        Where-Object { $_ -like "$wordToComplete*" } |
        ForEach-Object { [CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}

# ── pnpm ───────────────────────────────────────────────────────────────────────
Register-ArgumentCompleter -Native -CommandName pnpm -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    $elements = $commandAst.CommandElements
    if ($elements.Count -gt 2) { return }

    $cmds = @('install','add','remove','update','run','build','test','dev',
              'start','publish','pack','exec','dlx','list','why','store',
              'recursive','--filter','workspace')
    $scripts = @()
    if (Test-Path 'package.json') {
        try { $scripts = (Get-Content 'package.json' -Raw | ConvertFrom-Json).scripts.PSObject.Properties.Name } catch {}
    }
    ($cmds + $scripts) | Sort-Object -Unique |
        Where-Object { $_ -like "$wordToComplete*" } |
        ForEach-Object { [CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}

# ── gh (GitHub CLI) ────────────────────────────────────────────────────────────
Register-ArgumentCompleter -Native -CommandName gh -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    $elements = $commandAst.CommandElements
    $sub = if ($elements.Count -ge 2) { $elements[1].ToString() } else { '' }

    if ($elements.Count -le 2) {
        @('pr','repo','issue','release','auth','workflow','run','secret','gist','label','api','codespace') |
        Where-Object { $_ -like "$wordToComplete*" } |
        ForEach-Object { [CompletionResult]::new($_, $_, 'ParameterValue', $_) }
        return
    }

    $subMap = @{
        'pr'       = @('create','list','view','checkout','merge','close','review','status','diff','comment')
        'repo'     = @('create','clone','fork','view','list','delete','archive','rename','sync')
        'issue'    = @('create','list','view','close','reopen','comment','edit','pin','transfer')
        'release'  = @('create','list','view','delete','upload','download')
        'workflow' = @('list','run','view','enable','disable')
        'auth'     = @('login','logout','status','refresh','token')
        'secret'   = @('list','set','delete')
    }
    if ($subMap.ContainsKey($sub)) {
        $subMap[$sub] |
            Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { [CompletionResult]::new($_, $_, 'ParameterValue', $_) }
    }
}

# ── code (VS Code) ─────────────────────────────────────────────────────────────
Register-ArgumentCompleter -Native -CommandName code -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    @('--install-extension','--uninstall-extension','--list-extensions',
      '--disable-extensions','--new-window','-n','--reuse-window','-r',
      '--goto','-g','--diff','--wait','-w','--verbose','--log','--status') |
    Where-Object { $_ -like "$wordToComplete*" } |
    ForEach-Object { [CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}

#endregion

#region Auto-ls after cd
function Invoke-SetLocationWithList {
    param(
        [Parameter(Position = 0)]
        [string]$Path
    )
    if (-not $PSBoundParameters.ContainsKey('Path')) {
        Set-Location $HOME
    } elseif ($Path -eq '-') {
        Set-Location -
    } else {
        Set-Location $Path
    }
    Get-ChildItem
}
Set-Alias -Name cd -Value Invoke-SetLocationWithList -Option AllScope -Force
#endregion


#region Terminal quality-of-life add-ons

# Richer PSReadLine colors + better prediction
Set-PSReadLineOption -Colors @{
    Command   = 'Cyan'
    Parameter = 'DarkGray'
    String    = 'Yellow'
    Variable  = 'Green'
    Error     = 'Red'
    Comment   = 'DarkGreen'
    Keyword   = 'Magenta'
    Number    = 'Blue'
    Operator  = 'Gray'
}

try {
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
}
catch {
    Set-PSReadLineOption -PredictionSource History
}

# Unix-like helpers
function which {
    param(
        [Parameter(Mandatory, ValueFromRemainingArguments = $true)]
        [string[]]$Name
    )

    foreach ($n in $Name) {
        Get-Command $n -ErrorAction SilentlyContinue |
            Select-Object Name, CommandType, Source, Definition
    }
}

function mkcd {
    param([Parameter(Mandatory)][string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Set-Location $Path
}

function up {
    param([int]$Levels = 1)
    if ($Levels -lt 1) { return }

    $target = ((1..$Levels | ForEach-Object { ".." }) -join [IO.Path]::DirectorySeparatorChar)
    Set-Location $target
}

function touch {
    param([Parameter(Mandatory)][string]$Path)

    if (Test-Path $Path) {
        (Get-Item $Path).LastWriteTime = Get-Date
        return
    }

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    New-Item -ItemType File -Path $Path -Force | Out-Null
}

# Notifications for long commands
# Optional: Install-Module BurntToast -Scope CurrentUser
function Invoke-WithNotify {
    param(
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [string]$Title = "Task finished"
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $ok = $true

    try {
        & $ScriptBlock
    }
    catch {
        $ok = $false
        throw
    }
    finally {
        $sw.Stop()
        $status = if ($ok) { "Completed" } else { "Failed" }
        $seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1)
        $message = "$status in ${seconds}s"

        if (Get-Module -ListAvailable BurntToast) {
            Import-Module BurntToast -ErrorAction SilentlyContinue
            New-BurntToastNotification -Text $Title, $message | Out-Null
        }
        else {
            [console]::Beep(1000, 180)
            Write-Host "$Title - $message" -ForegroundColor Cyan
        }
    }
}
Set-Alias -Name notify -Value Invoke-WithNotify

#region Docker helpers
function dps {
    $rows = docker ps --format "{{.Names}}`t{{.Status}}`t{{.Ports}}"

    if (-not $rows) {
        Write-Host "No running containers." -ForegroundColor Yellow
        return
    }

    Write-Host "NAME`tSTATUS`tPORTS" -ForegroundColor Cyan
    foreach ($row in $rows) {
        if ($row -match "Up") {
            Write-Host $row -ForegroundColor Green
        }
        elseif ($row -match "Exited|Dead") {
            Write-Host $row -ForegroundColor Red
        }
        else {
            Write-Host $row -ForegroundColor DarkYellow
        }
    }
}

function dex {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Shell = "sh"
    )

    $container = docker ps --format "{{.Names}}" |
        Where-Object { $_ -like "*$Name*" } |
        Select-Object -First 1

    if (-not $container) {
        Write-Host "No running container matching '$Name'" -ForegroundColor Red
        return
    }

    docker exec -it $container $Shell
}
#endregion

#region Nest / Node / env helpers
function db-push   { yarn drizzle-kit push @Args }
function db-gen    { yarn drizzle-kit generate @Args }
function db-studio { yarn drizzle-kit studio @Args }

function show-env {
    param([string]$Pattern = ".*")
    Get-ChildItem Env: |
        Where-Object { $_.Name -match $Pattern } |
        Sort-Object Name
}
#endregion

#region Function menu
# Optional: F6 quick picker if Out-GridView is available
if (Get-Command Out-GridView -ErrorAction SilentlyContinue) {
    Set-PSReadLineKeyHandler -Key F6 `
        -BriefDescription FunctionMenu `
        -LongDescription "Show custom functions" `
        -ScriptBlock {
        $picked = Get-ChildItem function: |
            Where-Object {
                $_.Name -notmatch '^(cd|prompt|more|pause|help)$' -and
                $_.Name -notlike '*:*'
            } |
            Sort-Object Name |
            Select-Object Name |
            Out-GridView -Title "Functions in profile" -PassThru

        if ($picked) {
            [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert($picked.Name)
        }
    }
}
#endregion

#region Cursor shape — I-beam when typing
$ESC = [char]27
[Console]::Write("$ESC[5 q")   # blinking beam cursor
#endregion

#region Pretty ll (ls giu nguyen mac dinh)
function Invoke-PrettyLs {
    param(
        [string]$Path = ".",
        [switch]$All,
        [switch]$NoSummary
    )
    $gciArgs = @{ Path = $Path; ErrorAction = 'Stop' }
    if ($All) { $gciArgs['Force'] = $true }
    try { $items = Get-ChildItem @gciArgs } catch { Get-ChildItem -Path $Path; return }

    $dirs  = @($items | Where-Object { $_.PSIsContainer }  | Sort-Object Name)
    $files = @($items | Where-Object { !$_.PSIsContainer } | Sort-Object Name)
    $total = ($files | Measure-Object Length -Sum).Sum
    $totalStr = if ($total -ge 1GB)  { "{0:N2} GB" -f ($total/1GB) }
                elseif ($total -ge 1MB) { "{0:N1} MB" -f ($total/1MB) }
                elseif ($total -ge 1KB) { "{0:N1} KB" -f ($total/1KB) }
                else { "$total B" }

    if (-not $NoSummary) {
        Write-Host ""
        Write-Host ("  {0}  |  {1} files  |  {2}" -f "$($dirs.Count) dirs", $files.Count, $totalStr) -ForegroundColor DarkGray
        Write-Host ("  " + ("─" * 60)) -ForegroundColor DarkGray
    }

    foreach ($d in $dirs) {
        $ts = $d.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
        Write-Host ("  {0,-9}  {1}  " -f "<DIR>", $ts) -NoNewline -ForegroundColor DarkGray
        Write-Host $d.Name -ForegroundColor Cyan
    }

    foreach ($f in $files) {
        $bytes = $f.Length
        $sz = if ($bytes -ge 1GB)  { "{0,8:N2} GB" -f ($bytes/1GB) }
              elseif ($bytes -ge 1MB) { "{0,8:N1} MB" -f ($bytes/1MB) }
              elseif ($bytes -ge 1KB) { "{0,8:N1} KB" -f ($bytes/1KB) }
              else                    { "{0,8} B"    -f $bytes }
        $ts    = $f.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
        $color = switch ($f.Extension.ToLower()) {
            { $_ -in '.ts','.tsx','.js','.jsx' } { 'Yellow' }
            { $_ -in '.json','.yaml','.yml'    } { 'DarkYellow' }
            { $_ -in '.md','.txt','.log'       } { 'Gray' }
            { $_ -in '.ps1','.psm1','.psd1'    } { 'Blue' }
            { $_ -in '.sql'                    } { 'Magenta' }
            { $_ -in '.env','.env.local'       } { 'Red' }
            { $_ -in '.png','.jpg','.svg','.ico' } { 'DarkCyan' }
            default                              { 'White' }
        }
        Write-Host ("  {0}  {1}  " -f $sz, $ts) -NoNewline -ForegroundColor DarkGray
        Write-Host $f.Name -ForegroundColor $color
    }
    Write-Host ""
}
Set-Alias -Name ll -Value Invoke-PrettyLs -Force
#endregion

#region Extras
function duf {
    param([string]$Path = ".")
    Get-ChildItem $Path -Directory | ForEach-Object {
        $size    = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        $sizeStr = if ($size -ge 1GB)  { "{0:N2} GB" -f ($size/1GB) }
                   elseif ($size -ge 1MB) { "{0:N2} MB" -f ($size/1MB) }
                   else { "{0:N1} KB" -f ($size/1KB) }
        $items = (Get-ChildItem $_.FullName -Recurse -ErrorAction SilentlyContinue).Count
        [PSCustomObject]@{ Folder = $_.Name; Size = $sizeStr; Items = $items }
    } | Sort-Object Folder | Format-Table -AutoSize
}

function node-version { node -v; npm -v 2>$null; yarn -v 2>$null }
Set-Alias -Name nv -Value node-version -Force

function Update-WindowTitle {
    $short = $PWD.Path -replace [regex]::Escape($HOME), "~"
    $host.UI.RawUI.WindowTitle = "pwsh · $short"
}
Update-WindowTitle
#endregion

#endregion Terminal quality-of-life add-ons
