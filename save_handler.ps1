# ----------- IMPORTS ----------

Add-Type -AssemblyName System.Windows.Forms

# ----------- GLOBALS ----------

$global:selected_username = $null;

# ----------- FUNCTIONS ----------

function Validate-JsonConfig($json_config) {
    return (Get-Member -InputObject $json_config -Name "name") -AND (Get-Member -InputObject $json_config -Name "branch_name")
}

function Select-PlayingUser($usernames) {

    # Create the main form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Who is playing?"
    $form.Size = New-Object System.Drawing.Size(350, 200)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false

    # Create a label for the combo box
    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Select a user:"
    $label.Location = New-Object System.Drawing.Point(20, 20)
    $label.Size = New-Object System.Drawing.Size(100, 20)
    $form.Controls.Add($label)

    # Create the combo box
    $comboBox = New-Object System.Windows.Forms.ComboBox
    $comboBox.Location = New-Object System.Drawing.Point(20, 50)
    $comboBox.Size = New-Object System.Drawing.Size(280, 25)
    $comboBox.DropDownStyle = "DropDownList"  # Prevents typing, only selection
    $comboBox.Items.AddRange($usernames);
    $form.Controls.Add($comboBox)

    # Create the confirm button
    $confirmButton = New-Object System.Windows.Forms.Button
    $confirmButton.Text = "Confirm Selection"
    $confirmButton.Location = New-Object System.Drawing.Point(20, 90)
    $confirmButton.Size = New-Object System.Drawing.Size(120, 30)

    # Add click event for the confirm button
    $confirmButton.Add_Click(
        {
            if ($comboBox.SelectedItem) {
                $global:selected_username = $comboBox.SelectedItem
                $form.Close()
                $form.Dispose()
            }
            else {
                [System.Windows.Forms.MessageBox]::Show("Please select a user first.", "Warning", "OK", "Warning")
            }
        }
    )

    # Create a cancel button (optional)
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Cancel"
    $cancelButton.Location = New-Object System.Drawing.Point(150, 90)
    $cancelButton.Size = New-Object System.Drawing.Size(80, 30)

    # Add click event for cancel button
    $cancelButton.Add_Click(
        {
            $form.Close()
        }
    )

    # Set the Accept and Cancel buttons for keyboard navigation
    $form.AcceptButton = $confirmButton
    $form.CancelButton = $cancelButton

    $form.Controls.Add($confirmButton)
    $form.Controls.Add($cancelButton)

    # Show the form
    $form.ShowDialog() | Out-Null

    # Clean up
    $form.Dispose()
}

function Find-GamePath() {
    $steamapps_path = Get-ChildItem C:\ -Filter "steamapps" -Recurse -Depth 4 -Force -ErrorAction SilentlyContinue |
    Where-Object { ($_.FullName -MATCH "\\Steam\\steamapps") -AND ($_.PSIsContainer) } |
    ForEach-Object -Process { Write-Output $_.FullName } |
    Select-Object -First 1

    return "${steamapps_path}\common\Split Fiction\Split\Binaries\Win64\SplitFiction.exe"
}

function Copy-CurrentDirectory($target_directory, $allowed_extensions) {

    Get-ChildItem -Recurse | 
    Where-Object { ($allowed_extensions.Count -EQ 0) -OR ($_.Extension -IN $allowed_extensions) } | 
    ForEach-Object -Process { Resolve-Path -Relative $_.FullName } |
    ForEach-Object -Process { Copy-Item -Destination (New-Item -Path (Split-Path -Path "${target_directory}\$_") -Type Directory -Force) $_ }
}

# ----------- MAIN SCRIPT ----------

# Load JSON config objects

Write-Output "Reading available configs..."

$configs = Get-ChildItem ${PSScriptRoot} -Filter "*.json" | 
ForEach-Object -Process { Get-Content -Raw $_.FullName | ConvertFrom-Json } | 
Where-Object { Validate-JsonConfig $_ }

if ($configs.Count -EQ 0) {
    [System.Windows.Forms.MessageBox]::Show("No configs found.", "Warning", "OK", "Warning")
    exit
}

$configs_names = $configs | ForEach-Object -Process { $_.name }

# Determining which config should be used
Write-Output "Select a player."

Select-PlayingUser $configs_names | Out-Null

$selected_config = $configs | Where-Object { $_.name -EQ $global:selected_username } | Select-Object -Index 0

if ($null -EQ $selected_config) {
    Write-Output "No player selected, aborting."
    exit
}

$player_branch_name = $selected_config.branch_name

$game_saves_path = "$env:LOCALAPPDATA\SplitFiction";
$submodule_path = "$PSScriptRoot\save_repo"
$submodule_saves_path = "$submodule_path\Saves\SplitFiction";

# Make sure that the saves submodule is initialized

Push-Location $PSScriptRoot | Out-Null

Write-Output "Initializing saves submodule..."
git submodule update --init

Pop-Location | Out-Null

# Pull the saves from submodule
Push-Location $submodule_path | Out-Null

git checkout $player_branch_name
git fetch
git pull

Pop-Location | Out-Null

# Copy cloud saves to the game directory
$save_file_extensions = @(".Split", ".split", ".ini")

Write-Output "Copying saves from repo to the game directory"

Push-Location $submodule_saves_path | Out-Null
Copy-CurrentDirectory $game_saves_path $save_file_extensions
Pop-Location | Out-Null

# Find the game path
$game_path = Find-GamePath

Start-Process $game_path -Wait

# After stopping the game, copy the new save files back to repo directory

Write-Output "Copying saves from game directory to the repo."

Push-Location $game_saves_path | Out-Null
Copy-CurrentDirectory $submodule_saves_path $save_file_extensions
Pop-Location | Out-Null

# Commit the saves

Write-Output "Commiting new saves."

Push-Location $submodule_path | Out-Null

$commit_msg = Get-Date -Format "dd/MM/yyyy, HH:mm:ss";

git add .
git commit -m ${commit_msg}
git push

Pop-Location | Out-Null
