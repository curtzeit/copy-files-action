# 🚀 Deploy to Windows Server

A GitHub Action that securely copies deployment artifacts to a remote Windows server and performs a deployment using PowerShell Remoting.

## Example Usage

Make sure to zip the project into a Project_Name.zip folder first so the action can find the build artifacts

```yaml

      - name: Zip Build Artifacts
        id: zip
        run: Compress-Archive -Path .\bin\* -DestinationPath .\WMS_Notifier_Service.zip

      - name: Deploy to Windows Server
        uses: curtzeit/copy-files-action@v1
        with:
          server: ${{ vars.WINDOWS_SERVER }}
          username: ${{ vars.SERVICEUPDATERUSER }}
          user_password: ${{ secrets.SERVICEUPDATERPASSWORD }}
          project_name: WMS_Notifier_Service
          target_path: 'C:\WMS_Services\WMS_Notifier_Service'
          staging_path: 'C:\WMSServiceDeployments'
          backup_path: 'C:\WMSServiceDeployments' (optional, otherwise will backup into staging_path)
```
