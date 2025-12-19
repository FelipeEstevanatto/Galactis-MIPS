# Script to generate all sprites from the Excel file
#Command to run this script:
#powershell -ExecutionPolicy Bypass -File tools/generate_all.ps1
#Change the --sheet and --out parameters as needed, to generate different sprites.

$python = "python"
$tool = "tools/gen_sprites_from_bitmap.py"

# 1. Menu
Write-Host "Generating Menu..."
& $python $tool --input "menuSprite.bmp" --out "menuSprite.asm" --macro "drawMenu"
# 2. Map
Write-Host "Generating Map..."
& $python $tool --input "mapwip.bmp" --out "mapSprite.asm" --macro "drawMap"

# 3. Game Over
Write-Host "Generating Game Over..."
& $python $tool --input "gameoverScreen.bmp" --out "gameoverScreen.asm" --macro "gameOverScreen"

# 3. Victory Screen
Write-Host "Generating Victory Screen..."
& $python $tool --input "telaVitoria.bmp" --out "victoryScreen.asm" --macro "victoryScreen"

# 4. Intro Screen
Write-Host "Generating Intro Screen..."
& $python $tool --input "tutorial.bmp" --out "tutorialScreen.asm" --macro "tutorialScreen"
Write-Host "Done!"
