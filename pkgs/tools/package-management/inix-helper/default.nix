{ final, prev }: prev.writeScriptBin "inix-helper" (builtins.readFile ./inix-helper.py)
