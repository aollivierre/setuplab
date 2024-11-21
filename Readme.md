# Setup Instructions

### Call using PowerShell:

- Using full URL:
    ```powershell
    powershell -Command "iex (irm https://raw.githubusercontent.com/aollivierre/setuplab/main/setup.ps1)"
    ```

- Using shortened URLs:
    ```powershell
    powershell -Command "iex (irm https://bit.ly/4c3XH76)"
    ```
    
    ```powershell
    powershell -Command "iex (irm bit.ly/4c3XH76)"
    ```

### If you are already in PowerShell (URL is case sensitive):

  ```powershell
  iex (irm bit.ly/4c3XH76)
  ```




Future work needed:
1- Add Chrome


2- Add FireFox


3- Add Remote Desktop Manager by Devolutions


4- Add mRemoteNG


5- Make all installers go in parallel instead of series


7- Skip pre-install validations on new installs
8- improve detection of sofware
9- bring in the EnhancedPS Tools Module to re-use code instead of repeating function def in each ps1 script
