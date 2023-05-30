..\..\odin\odin.exe build .\game\ -file -debug -define:SLOW=true -define:PRINT=true -define:INTERNAL=true -build-mode:dll -out=build/game.dll
..\..\odin\odin.exe run .\platform\ -debug -define:SLOW=true -define:PRINT=true -define:INTERNAL=true -out=build/platform.exe
