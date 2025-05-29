# 🚀 Deploy to Windows Server

A GitHub Action that securely copies deployment artifacts to a remote Windows server and performs a deployment using PowerShell Remoting.

## 📦 Usage

To use this action in your workflow, add the following to your `.github/workflows/deploy.yml` file:

```yaml
name: Deploy to Windows Server

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3

      - name: Deploy to Windows Server
        uses: your-username/your-repo-name@v1
        with:
          server: 'your.server.com'
          username: 'your-username'
          user_password: ${{ secrets.SERVER_PASSWORD }}
          project_name: 'MyApp'
          target_path: 'C:\\inetpub\\wwwroot\\MyApp'
          staging_path: 'C:\\Deploy\\Staging'
