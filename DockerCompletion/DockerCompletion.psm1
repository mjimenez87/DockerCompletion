Param(
	[string[]]$CustomScriptPath
)

function Select-CompletionResult {
	Param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[NativeCommandCompletionResult[]]$CompletionResult,
		[switch]$OptionWithArg,
		[switch]$LegacyCommand,
		[switch]$SubCommand
	)

	Process {
		if ($OptionWithArg) {
			$CompletionResult = $CompletionResult | Where-Object { $_.CompletionText -Like '-*' -and $_.TextType -NE 'Switch' }
		}
		if ($LegacyCommand) {
			$CompletionResult = $CompletionResult | Where-Object TextType -EQ 'LegacyCommand'
		}
		if ($SubCommand) {
			$CompletionResult = $CompletionResult | Where-Object TextType -EQ 'SubCommand'
		}
		$CompletionResult
	}
}

Invoke-CompletionCustomScript $PSScriptRoot\completers.ps1, $PSScriptRoot\completers4arguments.ps1
if ($CustomScriptPath) {
	Invoke-CompletionCustomScript $CustomScriptPath
}

$argumentCompleter = {
	Param([string]$wordToComplete, $commandAst, $cursorPosition)

	$completerName = 'docker'
	$optionWithArg = $null
	$managementCommand = $null
	$subCommand = $null
	$legacyCommand = $null
	$indexOfFirstArg = -1
	$counter = 1

	for (; $counter -lt $commandAst.CommandElements.Count; $counter++) {
		$ce = $commandAst.CommandElements[$counter]
		if ($cursorPosition -lt $ce.Extent.EndColumnNumber) {
			break
		}

		if ($optionWithArg) {
			# The argument of $optionWithArg is completed by this $ce
			$optionWithArg = $null
			continue
		}

		$text = $ce.Extent.Text
		if ($text.StartsWith('-')) {
			if ($text -in (Invoke-Completer $completerName -Option -ArgumentList $wordToComplete, $commandAst, $cursorPosition |
						Select-CompletionResult -OptionWithArg).CompletionText) {
				$optionWithArg = $text
			}
		} elseif (!$managementCommand -and !$legacyCommand) {
			if ($text -in (Invoke-Completer $completerName -Completer -ArgumentList $wordToComplete, $commandAst, $cursorPosition |
						Select-CompletionResult -LegacyCommand).CompletionText) {
				$legacyCommand = $text
				$completerName += "_$legacyCommand"
			} else {
				$managementCommand = $text
				$completerName += "_$managementCommand"
			}
		} elseif ($managementCommand -and !$subCommand) {
			if ($text -in (Invoke-Completer $completerName -Completer -ArgumentList $wordToComplete, $commandAst, $cursorPosition |
						Select-CompletionResult -SubCommand).CompletionText) {
				$subCommand = $text
				$completerName += "_$subCommand"
			}
		} elseif ($indexOfFirstArg -lt 0) {
			$indexOfFirstArg = $counter
		}
	}

	if ($optionWithArg) {
		$completerName += "_$optionWithArg"
	}

	# At this point, $completerName is any of the following:
	# 'docker'
	# 'docker_optionWithArg'
	# 'docker_managementCommand'
	# 'docker_managementCommand_subCommand'
	# 'docker_managementCommand_subCommand_optionWithArg'

	if ($wordToComplete) {
		$wordToCompleteSubstring = $wordToComplete.Substring(0, $cursorPosition - $commandAst.CommandElements[$counter].Extent.StartOffset)
	}

	if ($wordToComplete.StartsWith('-')) {
		$completionResult = Invoke-Completer $completerName -Option -ArgumentList $wordToComplete, $commandAst, $cursorPosition
	} else {
		$completionResult = Invoke-Completer $completerName -Completer -ArgumentList $wordToComplete, $commandAst, $cursorPosition, $indexOfFirstArg
	}

	$completionResult | Where-Object CompletionText -Like "$wordToCompleteSubstring*"
}

Register-NativeCommandArgumentCompleter 'docker' $argumentCompleter