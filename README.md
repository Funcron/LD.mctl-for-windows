# mctl

See [LiamDroog/mctl](https://github.com/LiamDroog/mctl) for better info. This is a hastily crafted port to Windows using AI

Launch-mctl.bat included in release package, which acts as a basic GUI launcher for the anti-CLI folk!

## Using it
Can be run from .exe using defaults, but the options will be accessible via PowerShell. Simplify the .exe name as you see fit:
```
.\mctl.exe                            # the console
.\mctl.exe --vehicle jwst --theme retrowave --fullscreen    # iss, hubble, jwst or roman
.\mctl.exe --offline                  # use cached data only; nothing is fetched, pictures come from the cache
.\mctl.exe check                      # check the config and fetch each data source once
.\mctl.exe about                      # licence, credits, third-party notices
.\mctl.exe --replay start             # play back your recording (or an ISO time, or an offset like -2h)
.\mctl.exe --no-record                # don't record this run
.\mctl.exe export --out ./dump        # every recorded table as CSV
.\mctl.exe shot --out-dir /tmp/shots --pages all    # headless screenshots, one per theme and page
.\mctl.exe --theme phosphor           # Uses Phosphor theme
```



