# Hyper Desktop

A thin macOS SwiftUI shell for the separately checked out, mutable Hyper server.

- Hyper application source and runtime overlay stay in `~/code/hyper-code`; never bundle or copy them into this repository.
- PostgreSQL remains an external service.
- Use SwiftUI and WKWebView; do not add another frontend runtime.
- The shell may request launchd to start the existing Hyper service, but launchd owns the server lifecycle.
- Do not modify or commit changes in the Hyper application repository from this repository.
- Do not add secrets or machine-specific absolute paths to tracked files.
