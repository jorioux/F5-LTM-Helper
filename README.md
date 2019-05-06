# F5-LTM-Helper
> #### by Jonathan Rioux
> ***Credits*** This module is built on top of the [`F5-LTM`](https://github.com/joel74/POSH-LTM-Rest) module by joel74

A set of helper functions built on top of F5-LTM module to manage F5 Big-IP LTM load balancers. This module saves your F5 credentials and IPs in XML files so it automatically recreates a new session to the active F5 when the last session token expires. It also saves the session token in an XML file, so you will always reuse the same session token until it expires.

Installation
-
This module requires the [`F5-LTM`](https://github.com/joel74/POSH-LTM-Rest) module.
#### PowerShell v5 and later
You can install the `F5-LTM-Helper` module directly from the [PowerShell Gallery](https://www.powershellgallery.com/packages/PowerDP)
```PowerShell
Install-Module F5-LTM
Install-Module F5-LTM-Helper
```

#### PowerShell v4 and earlier
Get [PowerShellGet Module](https://docs.microsoft.com/en-us/powershell/gallery/psget/get_psget_module) first.

Usage
-
```PowerShell
#To show status of all nodes in pool matching *eway_http*
Set-F5Node -Pool eway_http

#To show status of all nodes matching *end*:80*
Set-F5Node end*:80

#To Sync active F5 to group
Set-F5Node -Sync

#To disable the node matching *end02* in pool matching *end*, then Sync to group
Set-F5Node end02 -Pool endeca -Down -Sync

#To get the F5 session
Connect-F5
```

Contributing
-
Any contributions are welcome and feel free to open issues.
