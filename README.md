# mctl

See [LiamDroog/mctl](https://github.com/LiamDroog/mctl) for better info. This is a hastily crafted port to Windows using AI


## Using it
Can be run from .exe using defaults, but the options will be accessible via PowerShell. Simplify the .exe name as you see fit:
```
.\mctl-0.1.1-Windows.exe                            # the console
.\mctl-0.1.1-Windows.exe --vehicle jwst --theme retrowave --fullscreen    # iss, hubble, jwst or roman
.\mctl-0.1.1-Windows.exe --offline                  # use cached data only; nothing is fetched, pictures come from the cache
.\mctl-0.1.1-Windows.exe check                      # check the config and fetch each data source once
.\mctl-0.1.1-Windows.exe about                      # licence, credits, third-party notices
.\mctl-0.1.1-Windows.exe --replay start             # play back your recording (or an ISO time, or an offset like -2h)
.\mctl-0.1.1-Windows.exe --no-record                # don't record this run
.\mctl-0.1.1-Windows.exe export --out ./dump        # every recorded table as CSV
.\mctl-0.1.1-Windows.exe shot --out-dir /tmp/shots --pages all    # headless screenshots, one per theme and page
.\mctl-0.1.1-Windows.exe --theme phosphor           # Uses Phosphor theme
```



