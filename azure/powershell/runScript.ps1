# Define the list of IDs
$ids = @(
	"id_here",
	"id2_here"
)


# Path to the second script (azCATracking.ps1 or your script)
$secondScriptPath = "/home/matt/azCATracking.ps1"

# Loop through each ID and pass it as a CLI argument to the second script
foreach ($id in $ids) {
    Write-Host "Running with ID: $id"
    # Call the second script with the current ID as an argument
    & $secondScriptPath -subscriptionId $id
}
